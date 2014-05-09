# To change this template, choose Tools | Templates
# and open the template in the editor.

require 'git'
require 'json'
require 'librarian/action'
require 'librarian/resolver'
require "librarian/spec_change_set"
require 'librarian/puppet/environment'
require 'util/change_set'
require 'util/item'
require 'util/git_repo_manager'

class GitChangeInspector
  include GitRepoManager
    
  def initialize
    
  end
  
  DEFAULT_DESTINATION_DIR = File::SEPARATOR+'tmp'
  DEFAULT_PROMOTED_REF = 'promoted'
  DEFAULT_CHANGESETS_BRANCH = 'ppt_change_sets'
  DEFAULT_DEV_BRANCH = 'master'
  DEFAULT_FILE_SUFFIX = '.pp'
  DEFAULT_MODULES_DIR = 'modules'
  DEFAULT_CHANGESET_FILENAME = 'changes.json'
  
  ## workflow:
  ## scm_repo = cloneRepo(repo_url, destination_dir)
  ## change_set = investigateRepository(scm_repo,opts)
  ## ## if test execution succeeded:
  ## promotion_result = promoteChanges(scm_repo,change_set,opts)
  
  def ensure_all_required_options_are_set(opts)
    if (opts == nil)
      opts = Hash.new
    end
    
    opts[:promoted_ref] = DEFAULT_PROMOTED_REF if opts[:promoted_ref] == nil
    opts[:change_set_branch] = DEFAULT_CHANGESETS_BRANCH if opts[:change_set_branch] == nil
    opts[:dev_branch] = DEFAULT_DEV_BRANCH if opts[:dev_branch] == nil
    opts[:destination_dir] = DEFAULT_DESTINATION_DIR if opts[:destination_dir] == nil
    opts[:file_suffix] = DEFAULT_FILE_SUFFIX if opts[:file_suffix] == nil
    opts[:modules_dir] = DEFAULT_MODULES_DIR if opts[:modules_dir] == nil
    opts[:change_set_filename] = DEFAULT_CHANGESET_FILENAME if opts[:change_set_filename] == nil
    
    return opts
  end
  
  
  def promote_changes(scm_repo,change_set,opts={})
    opts = ensure_all_required_options_are_set(opts)
    orphan_opts={:orphan=>true,:orphaninit=>'.orphan_init'}
    switch_to_orphan_branch(scm_repo,opts[:change_set_branch],orphan_opts)
    
    abs_repo_dir = scm_repo.dir.to_s
    abs_change_set_file = scm_repo.dir.to_s + File::SEPARATOR + opts[:change_set_filename]
    
    new_name=opts[:change_set_filename]
    if (File.exist?(abs_change_set_file))
      ## move current latest change set file 
      count = 0
      Dir.entries(abs_repo_dir).each do |entry|
        if entry =~ /^#{Regexp.escape(opts[:change_set_filename])}.*/
          count += 1;
        end
      end
      new_name=opts[:change_set_filename]+'.'+count.to_s
      scm_repo.mv(opts[:change_set_filename], new_name)      
    end
    File.open(abs_change_set_file,'w') do |file_handle|
      file_handle.puts(change_set.to_json)
    end
    scm_repo.add(opts[:change_set_filename])
    scm_repo.commit_all('updated puptest history: latest change set moved to '+new_name+', added new change set')
    
    scm_repo.checkout(change_set.promoted_commit)
    begin
    scm_repo.delete_tag(opts[:promoted_ref])
    rescue Git::GitExecuteError
      puts "rescued failed tag deletion"
    end
    scm_repo.add_tag(opts[:promoted_ref])
    puts "pushing ..."
    puts scm_repo.push('origin',opts[:dev_branch],{:tags => true})
    puts scm_repo.push('origin',opts[:change_set_branch],{:tags => true})    
    puts "... pushing"
    return nil
  end
  
  ## ## get the puppetmaster repository with
  ## opts[:destination_dir] = DEFAULT_DESTINATION_DIR if opts[:destination_dir] == nil    
  ## scm_repo = clone_repo(repo_url,opts[:destination_dir])
  # investigate repo returns a change set containing all directly changed nodes and modules
  def investigate_repo(scm_repo,opts={})
    ## TODO: test all (including submethods)
    opts = ensure_all_required_options_are_set(opts)
    ## get the puppetmaster repository
    ## scm_repo = cloneRepo(repo_url,opts[:destination_dir])
    
    ## determine latest commit in dev branch
    scm_repo.checkout(scm_repo.branch(opts[:dev_branch]))
    dev_latest_commit=scm_repo.log.first 
    
    ## tested and promoted commits are tracked in an orphan change_set branch
    ## the framework automatically creates one, if there is no such branch yet
    ## therefore the framework requires to find an empty .orphan_init file 
    ## in the master branch
    orphan_opts={:orphan=>true,:orphaninit=>'.orphan_init'}
    switch_to_orphan_branch(scm_repo,opts[:change_set_branch],orphan_opts)
        
    ## determine last successfully tested and promoted commit (LSTP commit)
    ## and generate list of files to analyse  
    diff_files = nil
    scm_repo.branch(opts[:change_set_branch]).checkout
    ## we are now in the change_set branch
    abs_change_set_file = scm_repo.dir.to_s+File::SEPARATOR+opts[:change_set_filename]
    promoted_latest_commit = nil
    if File.exist?(abs_change_set_file)
      ## if there is a changes.json, it tells us the hash of the LSTP commit    
      latest_change_set = ChangeSet.new(nil)
      latest_change_set.initialize_json(JSON.parse(File.read(abs_change_set_file)))
      promoted_latest_commit = latest_change_set.promoted_commit
      diff_files = scm_repo.diff(dev_latest_commit, promoted_latest_commit).stats[:files]    
    else
      ## if there is no changes.json, it is the initial run of the framework
      ## that means we have to include all files of the repository in our analysis
      diff_files = Set.new
      scm_repo.branch(opts[:dev_branch]).checkout
      # we are now in the dev branch
      scm_repo.status.each do |file|
        diff_files.add([file.path.to_s])
      end
    end
    
    if diff_files == nil
      raise(StandardError,"something went wrong, while determining the list of files to analyse")
    end
    
    change_set = analyse_files_for_node_class_and_definition_changes(scm_repo,diff_files,opts)    
    changed_modules = analyse_files_for_module_changes(scm_repo,promoted_latest_commit,opts)
    change_set.modules = changed_modules
    change_set.previous_promoted_commit = promoted_latest_commit
    change_set.promoted_commit = dev_latest_commit
    change_set.dev_ref=opts[:dev_branch]
    change_set.promoted_ref=opts[:promoted_ref]
    ## todo return repo AND changeset
    return change_set
  end
  
  def switch_to_orphan_branch(scm_repo,branch_name,orphan_opts=nil)
    if (orphan_opts == nil)
      orphan_opts = Hash.new
    end
    orphan_opts[:orphan] = true if orphan_opts[:orphan] == nil
    orphan_opts[:orphaninit] = '.orphan_init' if orphan_opts[:orphaninit] == nil
        
    if (!scm_repo.branches['origin/'+branch_name] && !scm_repo.branches[branch_name])
      #scm_repo.branch(branch_name).checkout(orphan_opts)
      scm_repo.checkout(scm_repo.branch(branch_name),orphan_opts)
    else
      scm_repo.checkout(scm_repo.branch(branch_name))
    end 
    return nil
  end
  
  def analyse_files_for_node_class_and_definition_changes(scm_repo,diff_files,opts)
    ## before we start the analysis, we make sure, that we are in the dev branch
    scm_repo.checkout(scm_repo.branch(opts[:dev_branch]))
    
    change_set = ChangeSet.new(scm_repo.dir.to_s)
     
    diff_files.each do |file|
      abs_file = scm_repo.dir.to_s+File::SEPARATOR+file[0]
      # does_exist = ' does not exist anymore'
      if File.exists?(abs_file) && abs_file[-opts[:file_suffix].size,opts[:file_suffix].size] == opts[:file_suffix]
        # does_exist = ' exists in current dev branch'
        # if file exists and is a .pp file, parse it and find out if it contains a node definition
        # or a class definition/ classes definitions (e.g. in site.pp)
        File.new(abs_file).each_line() do |line|  
          trimmed_line = line.strip        
         
          if trimmed_line =~ /^#/
            # puts "code comment : "+ trimmed_line
          else
            ## duplicated code block from site_builder.parsingLine
            if trimmed_line =~ /^node.*\{.*/ 
              ## parse node name or node name regexp             
              match_reg_exp_rule = Regexp.new(/\/.*\//).match(trimmed_line) 
              match_normal_rule = Regexp.new(/["'].*["']/).match(trimmed_line) 
              if match_reg_exp_rule
                node_name = match_reg_exp_rule[0]
                node_name_type = :regexp_name
              elsif match_normal_rule
                node_name = match_normal_rule[0].gsub('"','').gsub("'","")
                node_name_type = :plain_name
              end
              node_item = Item.new(Item::NODE,node_name_type,node_name)
              #puts "added node to change set: "+abs_file
              change_set.nodes[abs_file] = node_item
            end
          
            ## TODO parse for class and definition changes
          end
        end
      end
      # puts file[0].to_s + does_exist
    end
    
    return change_set
  end
  
  def analyse_files_for_module_changes(scm_repo,promoted_latest,opts={:dev_branch => DEFAULT_DEV_BRANCH})  
    changed_modules = Hash.new
    
    scm_repo.checkout(scm_repo.branch(opts[:dev_branch]))
    env = Librarian::Puppet::Environment.new({ :project_path => scm_repo.dir.to_s})    
    if !env.lockfile_path.exist?
      raise(NotYetSupportedException, "parsing for module changes only implemented for modules managed with librarian-puppet so far. Puppetfile.lock is expected to be present in the #{opts[:dev_branch]}")
    end
    
    lock = env.lockfile.read
    
    modules_in_last_promoted_state = Hash.new
    if (promoted_latest == nil)
      ## initial usage of the framework - all modules are considered as changed
      ## no modules will be added to modules_in_last_promoted_state
    else
      ## there is at least one changes.json in the change set branch
      scm_repo.checkout(scm_repo.branch(promoted_latest))
      lock_promoted = env.lockfile.read
      lock_promoted.manifests.each do |item|
        modules_in_last_promoted_state[item.name] = item
        # shaApp = item.source.is_a?(Librarian::Puppet::Source::Git) ? item.source.sha.to_s+" | " : ''
        # verApp = item.version.to_s+" | "
      end
    end
    
    scm_repo.branch(opts[:dev_branch]).checkout
    lock.manifests.each do |item|
      # shaApp = item.source.is_a?(Librarian::Puppet::Source::Git) ? item.source.sha.to_s+" | " : ''
      # verApp = item.version.to_s+" | "
      # fsource = Librarian::Dependency::Requirement.new
      short_name = item.name
      split = short_name.split('/')
      if split.size > 1
        short_name = split[1]
      end
      last_promoted_item = modules_in_last_promoted_state[item.name]
      ## modules_in_last_promoted_state will be empty if the framework is initially used 
      # (see comments around line 145)
      if last_promoted_item == nil        
        changed_modules[short_name] = Item.new(Item::MODULE,:plain_name,short_name)
      else
        if item.source.is_a?(Librarian::Puppet::Source::Git)
          if last_promoted_item.source.is_a?(Librarian::Puppet::Source::Git)
            if item.source.sha.to_s != last_promoted_item.source.sha.to_s || item.version.to_s != last_promoted_item.version.to_s
              changed_modules[short_name] = Item.new(Item::MODULE,:plain_name,short_name)
            end
          else
            changed_modules[short_name] = Item.new(Item::MODULE,:plain_name,short_name)
          end
        else
          if item.source.is_a?(Librarian::Puppet::Source::Forge)
            if last_promoted_item.source.is_a?(Librarian::Puppet::Source::Forge)
              if item.version.to_s != last_promoted_item.version.to_s
                changed_modules[short_name] = Item.new(Item::MODULE,:plain_name,short_name)
              end
            else
              changed_modules[short_name] = Item.new(Item::MODULE,:plain_name,short_name)
            end
          else
            raise(NotYetSupportedException,"so far only forge and git librarian sources are supported")
          end
        end
      end
    end
    
    return changed_modules
  end
  
  
  
end

class NotYetSupportedException < StandardError
  
end