# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'util/git_change_inspector'
require 'util/change_set'
require 'util/module_initializer'
require 'util/site_builder'

class ChangeDetector
  def initialize
    @scm_change_inspector = GitChangeInspector.new()
    @site_builder = SiteBuilder.new()    
  end
  
  def ensure_all_required_options_are_set(opts)
    if (opts == nil)
      opts = Hash.new
    end
    
    opts[:path_to_root_pp] = 'manifests' if opts[:path_to_root_pp] == nil
    opts[:root_pp_file_name] = SiteBuilder::SITE_PP if opts[:root_pp_file_name] == nil
    opts[:modules_dir] = SiteBuilder::DEFAULT_MODULES_DIR if opts[:modules_dir] == nil
    return opts
  end
  
  def detect_changes(repo_url, opts)
    #tested by GitChangeInspectorTest.test_clone_repo
    scm_repo=@scm_change_inspector.clone_repo(repo_url, opts[:destination_dir],opts[:repo_name_in_destination])
    #tested by GitChangeInspectorTest.test_investigate_repository
    change_set = @scm_change_inspector.investigate_repo(scm_repo, opts)
    # investigate repo returns a change set containing all directly changed nodes and modules
    
    # because investigate repo returns a change set containing ONLY directly 
    # changed nodes and modules, we still have to find nodes which are indirectly
    # affected by module changes.
    # therefore, we have to examine the dependencies between modules and
    # find the modules which have not been changed, but depend on a changed module.
    # change_set.modules contains all directly changed modules at this point.
    
    # building the module tree
    module_initializer = ModuleInitializer.new(scm_repo.dir.to_s)
    #tested by ModuleInitializerTest.test_install_modules
    #preparation step for "build_effective_site_pp", which parses through the modules directory
    module_initializer.install_modules()
    opts = ensure_all_required_options_are_set(opts)    
    abs_path_to_root_pp = scm_repo.dir.to_s + File::SEPARATOR + opts[:path_to_root_pp]
    dependency_tree, condensed_dependency_tree, module_tree = @site_builder.build_effective_site_pp(abs_path_to_root_pp,scm_repo.dir.to_s+File::SEPARATOR+opts[:modules_dir],opts[:root_pp_file_name])
    
    ## invert the dependency graph "module_tree" [key: module.name, value: dependencies hash map]
    affections = generate_affection_tree(module_tree)
    ## affections [key: module.name, val: affected modules set]
    
    ## walk through list of directly changed modules and collect list
    ## of all modules that are affected by the changed modules.
    all_change_affected_modules = find_all_change_affected_modules(change_set.modules, affections)
    
    ## walk through list of all nodes and figure out which nodes are 
    ## affected using the assembled collection of directly and indirectly changed 
    ## modules
    condensed_dependency_tree.each do |itemKey, item|
      if item.item_type == Item::NODE
        item.each_value do |dependency|
          if (dependency.item_type == Item::MODULE && all_change_affected_modules.include?(dependency.name))
            change_set.nodes[item.name] = item
          end
        end
      end
    end
    return change_set
  end
  
  def find_all_change_affected_modules(directly_changed_modules, affections)
    all_change_affected_modules = Set.new()
    
    directly_changed_modules.each do |key, module_item|
      #puts "directly changed: "+key+", "+module_item.name
      all_change_affected_modules.add(module_item.name)
      if (affections[module_item.name] && affections[module_item.name].size > 0)
        affections[module_item.name].each do |affected|
          all_change_affected_modules.add(affected)
        end
      end
    end
    
    return all_change_affected_modules
  end
  
#  def flatten_affection_map(affections)
#    change_affected_modules = Set.new
#    affections.each do |affector, affected_items|
#      change_affected_modules.add(affector)
#      affected_items.each do |affected_item|
#        change_affected_modules.add(affected_item)
#      end
#    end
#    return change_affected_modules
#  end
  
  def generate_affection_tree(module_tree)
    # affections key is the affector module name, value is a set of module names (directly or indirectly) affected by the affector
    affections = Hash.new
    module_tree.each_value do |module_item| 
      #puts "module ... "+module_item.name
      if (!affections[module_item.name])
        affections[module_item.name] = Set.new
      end
      module_item.each_value do |affector_item|
        #puts "... depends on "+affector_item.name
        affections = recursive_affection_path_parsing(affections, affector_item, module_item)
      end
    end
    
    return affections
  end
  
  def recursive_affection_path_parsing(affections, affector_item, affected_item)
#    puts "affector is: "+affector_item.to_s
    if (affector_item.item_type == Item::MODULE && affected_item.item_type == Item::MODULE)
#      puts "affector inside: "+affector_item.item_type.to_s+(affector_item.item_type == Item::MODULE).to_s
      if (!affections[affector_item.name])
        affections[affector_item.name] = Set.new
      end
      #    puts "module dependency : " +affected_item.name+" depends on: "+affector_item.name
      ## only if dependency path has not been added yet
      if (!(affections[affector_item.name].include?(affected_item.name)))
        affections[affector_item.name].add(affected_item.name)
        affector_item.each_value do |affector_dependency|
          ## only if affectorItem is not affected_item
          if (affector_dependency.name != affected_item.name && affector_dependency.item_type == Item::MODULE)
#            puts "calling affector: "+affector_item.map_id+ "... value "+affector_dependency.map_id
            affections = recursive_affection_path_parsing(affections, affector_dependency, affected_item)
          end
        end
      end
    end
    return affections
  end
end
