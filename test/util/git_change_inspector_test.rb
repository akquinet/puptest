# To change this template, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
$:.unshift File.join(File.dirname(__FILE__))
puts $:

require 'test/unit'
require 'util/git_change_inspector'
require 'set'
require 'test_helper'

class GitChangeInspectorTest < Test::Unit::TestCase
  FSEP = File::SEPARATOR
  
  include TestHelper
  
  def test_ensure_all_required_options_are_set
    inspector = GitChangeInspector.new
    opts = inspector.ensure_all_required_options_are_set({})
    assert_equal(GitChangeInspector::DEFAULT_CHANGESETS_BRANCH,opts[:change_set_branch])
    assert_equal(GitChangeInspector::DEFAULT_CHANGESET_FILENAME,opts[:change_set_filename])
    assert_equal(GitChangeInspector::DEFAULT_DESTINATION_DIR,opts[:destination_dir])
    assert_equal(GitChangeInspector::DEFAULT_DEV_BRANCH,opts[:dev_branch])
    assert_equal(GitChangeInspector::DEFAULT_FILE_SUFFIX,opts[:file_suffix])
    assert_equal(GitChangeInspector::DEFAULT_MODULES_DIR,opts[:modules_dir])
    assert_equal(GitChangeInspector::DEFAULT_PROMOTED_REF,opts[:promoted_ref])
    
    v1 = 'v1', v2 = 'v2', v3 = 'v3', v4 = 'v4', v5 = 'v5', v6 = 'v6', v7 = 'v7'
    opts = inspector.ensure_all_required_options_are_set({
        :change_set_branch => v1,
        :change_set_filename => v2,
        :destination_dir => v3,
        :dev_branch => v4,
        :file_suffix => v5,
        :modules_dir => v6,
        :promoted_ref => v7
      })
    assert_equal(v1,opts[:change_set_branch])
    assert_equal(v2,opts[:change_set_filename])
    assert_equal(v3,opts[:destination_dir])
    assert_equal(v4,opts[:dev_branch])
    assert_equal(v5,opts[:file_suffix])
    assert_equal(v6,opts[:modules_dir])
    assert_equal(v7,opts[:promoted_ref])        
  end
  
  def test_cleanup
    inspector = GitChangeInspector.new
    assert(inspector.cleanup(FSEP + 'tmpsqetwrgdsvwe')) 
    tmp_dir = FSEP + 'tmp' + FSEP + 'test_cleanup_' + Time.now.to_i.to_s
    Dir.mkdir(tmp_dir)
    assert(inspector.cleanup(tmp_dir))
  end
  
  def test_clone_repo
    base_repo = File.dirname(__FILE__) + FSEP + 'change_inspector_repo'
    inspector = GitChangeInspector.new
    scm_repo = inspector.clone_repo(base_repo, FSEP+'tmp', 'test_clone_repo')
    assert_not_nil(scm_repo)
    assert_equal(FSEP+'tmp'+FSEP+'test_clone_repo',scm_repo.dir.to_s)
    scm_repo.checkout(scm_repo.branch('master'))
    assert(File.exist?(scm_repo.dir.to_s+FSEP+'.orphan_init'))
    assert(File.exist?(scm_repo.dir.to_s+FSEP+'example.txt'))
    assert(inspector.cleanup(scm_repo.dir.to_s))
  end
  
  def test_promote_changes
    base_repo = File.dirname(__FILE__) + FSEP + 'change_inspector_repo'
    inspector = GitChangeInspector.new
    remote_repo = inspector.clone_repo(base_repo, FSEP+'tmp', 'test_promote_changes_remote',true)
    scm_repo = inspector.clone_repo(remote_repo.dir.to_s, FSEP+'tmp', 'test_promote_changes')
    
    ## switching to the master branch initially ensures that origin/master is locally accessible 
    ## for lib.checkout_file_from_branch command used during orphaninit
    scm_repo.checkout(scm_repo.branch('master'))
    
    inspector.switch_to_orphan_branch(scm_repo, GitChangeInspector::DEFAULT_CHANGESETS_BRANCH)
    change_set = ChangeSet.new(scm_repo.dir.to_s)
    change_set.promoted_commit='0dbac7256c8071edc914747571bc033e06be0d8c'
    change_set.promoted_ref = GitChangeInspector::DEFAULT_PROMOTED_REF
    change_set.dev_ref= GitChangeInspector::DEFAULT_DEV_BRANCH
    inspector.promote_changes(scm_repo, change_set)
    puts scm_repo.branches
    assert_not_nil(scm_repo.branches[change_set.dev_ref])
    assert_not_nil(scm_repo.branches[GitChangeInspector::DEFAULT_CHANGESETS_BRANCH])
    assert_not_nil(remote_repo.branches[change_set.dev_ref])
    assert_not_nil(remote_repo.branches[GitChangeInspector::DEFAULT_CHANGESETS_BRANCH])
    assert_equal(1,scm_repo.tags.size)
    assert_equal(1,remote_repo.tags.size)
    assert_equal(GitChangeInspector::DEFAULT_PROMOTED_REF,scm_repo.tags[0].name)
    assert_equal(GitChangeInspector::DEFAULT_PROMOTED_REF,remote_repo.tags[0].name)
    assert_equal(change_set.promoted_commit,scm_repo.tags[0].objectish)
    assert_equal(change_set.promoted_commit,remote_repo.tags[0].objectish)
    scm_repo.checkout(scm_repo.branch(GitChangeInspector::DEFAULT_CHANGESETS_BRANCH))    
    assert(File.exist?(scm_repo.dir.to_s+FSEP+ GitChangeInspector::DEFAULT_CHANGESET_FILENAME))
    remote_repo.checkout(scm_repo.branch(GitChangeInspector::DEFAULT_CHANGESETS_BRANCH))    
    assert(File.exist?(remote_repo.dir.to_s+FSEP+ GitChangeInspector::DEFAULT_CHANGESET_FILENAME))
    assert(inspector.cleanup(scm_repo.dir.to_s))
    assert(inspector.cleanup(remote_repo.dir.to_s))
  end
  
  def test_analyse_files_for_node_class_and_definition_changes
    opts = {
      :dev_branch => 'test_analyse_files_for_node_class_and_definition_changes', 
      :file_suffix => GitChangeInspector::DEFAULT_FILE_SUFFIX
    }
    base_repo = File.dirname(__FILE__) + FSEP + 'change_inspector_repo'    
    inspector = GitChangeInspector.new    
    scm_repo = inspector.clone_repo(base_repo, FSEP+'tmp', 'test_analyse_files_for_node_class_and_definition_changes')
    ## diff_files is a set of arrays
    diff_files = Set.new
    f1 = 'nodes'+FSEP+'node1.pp'
    f2 = 'nodes'+FSEP+'node2.pp'
    f4 = 'nodes'+FSEP+'node4.pp'
    diff_files.add([f1])
    diff_files.add([f2])
    diff_files.add([f4])    
    change_set = inspector.analyse_files_for_node_class_and_definition_changes(scm_repo, diff_files, opts)
    puts change_set.nodes
    pre = scm_repo.dir.to_s + FSEP
    assert_not_nil(change_set.nodes[pre+f1])
    assert_not_nil(change_set.nodes[pre+f2])
    assert_not_nil(change_set.nodes[pre+f4])
    assert_nil(change_set.nodes[pre+'node5.pp'])
    assert_equal('node1, node1.local.com',change_set.nodes[pre+f1].name)
    assert_equal('node2',change_set.nodes[pre+f2].name)
    assert_equal('node4',change_set.nodes[pre+f4].name)
    assert_equal(Item::NODE,change_set.nodes[pre+f1].item_type)
    assert_equal(Item::NODE,change_set.nodes[pre+f2].item_type)
    assert_equal(Item::NODE,change_set.nodes[pre+f4].item_type)
    assert(inspector.cleanup(scm_repo.dir.to_s))
  end
  
  def test_analyse_files_for_module_changes
    opts = {
      :dev_branch => 'test_analyse_files_for_node_class_and_definition_changes', 
      :file_suffix => GitChangeInspector::DEFAULT_FILE_SUFFIX
    }
    base_repo = File.dirname(__FILE__) + FSEP + 'change_inspector_repo'
    inspector = GitChangeInspector.new    
    scm_repo = inspector.clone_repo(base_repo, FSEP+'tmp', 'test_analyse_files_for_module_changes')  
        
    ## initial usage of framework
    changed_modules_hash = inspector.analyse_files_for_module_changes(
      scm_repo, 
      nil,
      {:dev_branch => 'test_analyse_files_for_module_changes_initial'}
    )
    expected_module_changes = ['puppetlabs/stdlib', 'maestrodev/wget', 'akquinet/unzip',
      'akquinet/archmngt', 'puppetlabs/java', 'saheba/openjdk_6_jre',
      'akquinet/maven', 'akquinet/jboss', 'akquinet/postgresql',
      'saheba/phantomjs', 'example42/apache', 'example42/puppi', 'akquinet/apache_addfiles',
      'akquinet/apache_crowd', 'akquinet/jpackage_repo', 'maestrodev/jetty'
    ]
#    puts changed_modules_hash.keys.to_s
    
    run_investigate_module_changes(changed_modules_hash,expected_module_changes)
    assert_equal(expected_module_changes.size,changed_modules_hash.size)
    
    ## non-initial usage of framework
    changed_modules_hash = inspector.analyse_files_for_module_changes(
      scm_repo, 
      'test_analyse_files_for_module_changes_initial',
      {:dev_branch => 'test_analyse_files_for_module_changes_non_initial'}
    )
    ## added: 'saheba/netrc'
    ## changed: 'puppetlabs/java', 'akquinet/maven'
    ## updated (changed): 'maestrodev/wget'
    ## removed: 'akquinet/apache_addfiles', 'akquinet/apache_crowd',
    ##          'example42/apache', 'saheba/phantomjs'
    ## indirectly removed: 'example42/puppi'
    ## (removed modules are not relevant for determining node definitions which need to be tested)
    puts "non-initial --------"
    expected_module_changes = ['saheba/netrc', 'puppetlabs/java', 
      'akquinet/maven', 'maestrodev/wget'
    ]
    expected_modules_stable = ['puppetlabs/stdlib', 'akquinet/unzip',
      'akquinet/archmngt', 'saheba/openjdk_6_jre', 'akquinet/jboss', 'akquinet/postgresql']
    run_investigate_module_changes(changed_modules_hash,expected_module_changes,expected_modules_stable)
    assert_equal(expected_module_changes.size,changed_modules_hash.size)
    
    assert(inspector.cleanup(scm_repo.dir.to_s))
  end
  
  def test_investigate_repository
# this test case uses a test repo and will create the following commit history
# inside a clone of the test repo:
#       node recipes      modules           tag position of promoted tag
# (10)  !                  != postgresql          >>promoted5
#                            (!branch)
#     
# (9)  -subnode3                            >>promoted4
# 
# (8)   +site.pp          -netrc
#       +resources.pp     -sonar (forge)
#       
# (7)   +node4            +jetty            >> promoted3
#       +node5            +jpackage_repo
#                         != netrc (!noforge)
#                         +sonar (forge)
#                         
#       
# (6)   +subnode1         +apache
#       +subnode2         +apache_addfiles
#       +subnode3         +apache_crowd
#       
# (5)   +subsubnode1                        >> promoted2
# 
# (4)   +sub2node1        +netrc (forge)          
# 
# (3)   +node2            !=postgresql        
#       
# (2)                     +phantomjs
#                         !=archmngt
# 
# (1)   +node1            +unzip            >> promoted
#                         +openjdk_6_jre
#                         +maven
#                         +jboss
#                         +postgresql
#                         + archmngt (transitive)
#                         + stdlib (transitive)
#                         + wget (transitive)
#                         + java (transitive)
    inspector = GitChangeInspector.new    
    opts = { :dev_branch => 'dev_branch', :promoted_ref => 'test_investigate_repository_promoted'}    
    src_repo_dir = File.dirname(__FILE__) + FSEP + 'test_investigate_repository'
    
    src_repo = inspector.clone_repo(src_repo_dir, FSEP+'tmp', 'test_investigate_repository_src') 
    src_repo.checkout('master')
    base_repo = inspector.clone_repo(src_repo_dir, FSEP+'tmp', 'test_investigate_repository_base')    
    # ensure all required branches are present in cloned base repo
#    base_repo.fetch
    base_repo.checkout('master')
    base_repo.checkout(opts[:dev_branch])

    scm_repo = inspector.clone_repo(base_repo.dir.to_s, FSEP+'tmp', 'test_investigate_repository')  
    # ensure all branches are in sync with base_repo
    scm_repo.checkout('master')
    scm_repo.checkout(opts[:dev_branch])
    
    ## initial investigation
    change_set = inspector.investigate_repo(scm_repo, opts)
    assert_equal(1,change_set.nodes.size)
    nkey = scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'node1.pp'
    assert_not_nil(change_set.nodes[nkey])
    assert_equal('node1, node1.local.com', change_set.nodes[nkey].name)
    puts change_set.modules.to_s    
    expected_module_changes = ['akquinet/unzip','akquinet/maven',
      'akquinet/jboss','akquinet/postgresql','akquinet/archmngt',
      'maestrodev/wget','puppetlabs/java','puppetlabs/stdlib','saheba/openjdk_6_jre'
      ]
    assert_equal(expected_module_changes.size,change_set.modules.size)    
    run_investigate_module_changes(change_set.modules,expected_module_changes)
    ## make some changes and commit them
    apply_prepared_changes(inspector,change_set,scm_repo,base_repo,src_repo,'8c5f70ddf3cd758ff0e2280b979e79fcb1aeaa2d',opts)
    
    ## second investigation
    change_set = inspector.investigate_repo(scm_repo, opts)
    
    ## nodename => file 
    expected_node_changes = {
      'node2' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'node2.pp',
      'sub2node1' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes2'+FSEP+'sub2node1.pp',
      'subsubnode1' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'subfolder'+
            FSEP+'subsubfolder'+FSEP+'subsubnode1.pp'
    }
    assert_equal(expected_node_changes.size,change_set.nodes.size)    
    run_investigate_node_changes(change_set.nodes,expected_node_changes)
    
    expected_module_changes = ['saheba/netrc','akquinet/archmngt',
      'akquinet/postgresql','saheba/phantomjs'
      ]
    assert_equal(expected_module_changes.size,change_set.modules.size)    
    run_investigate_module_changes(change_set.modules,expected_module_changes)
    
    ## make some changes and commit them
    apply_prepared_changes(inspector,change_set,scm_repo,base_repo,src_repo,'53289a2b76c3e06b972a168d36e2ffd229a6ee58',opts)
        
    ## third investigation
    change_set = inspector.investigate_repo(scm_repo, opts)
    
    ## nodename => file 
    expected_node_changes = {
      'node4' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'node4.pp',
      'node5' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'node5.pp',
      'subnode1' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'subfolder'+FSEP+'subnode1.pp',
      'subnode2' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'subfolder'+FSEP+'subnode2.pp',
      'subnode3' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'subfolder'+FSEP+'subnode3.pp',
      
    }
    assert_equal(expected_node_changes.size,change_set.nodes.size)    
    run_investigate_node_changes(change_set.nodes,expected_node_changes)
    
    
    expected_module_changes = ['saheba/netrc','example42/apache',
      'akquinet/apache_addfiles','akquinet/apache_crowd','akquinet/jpackage_repo',
      'maestrodev/jetty','maestrodev/sonar','maestrodev/maven','example42/puppi'
      ]
    assert_equal(expected_module_changes.size,change_set.modules.size)    
    run_investigate_module_changes(change_set.modules,expected_module_changes)
    
    ## make some changes and commit them
    apply_prepared_changes(inspector,change_set,scm_repo,base_repo,src_repo,'ab06cd0d1d92a018d25935ad633a384f1b8448ef',opts)
    
    ## note: now a site.pp is present, that means now node changes are also detected
    ## for nodes whose module dependencies change
    
    ## fourth investigation
    change_set = inspector.investigate_repo(scm_repo, opts)
    
    expected_module_changes = [
      ##'saheba/netrc','maestrodev/sonar',
      ## deleted modules do not affect the node definitions anymore
      ## so far the framework does not test for leftover module usages
      ## which one forgot to remove while removing the module itself
      ## TODO implement a test mechanism for that
      ]
    assert_equal(expected_module_changes.size,change_set.modules.size)    
    run_investigate_module_changes(change_set.modules,expected_module_changes)
    
    ## nodename => file 
    expected_node_changes = {
      ## subnode3 is removed, that means we do not have to test this node anymore
      
    }
    puts change_set.nodes.to_s
    assert_equal(expected_node_changes.size,change_set.nodes.size)    
    run_investigate_node_changes(change_set.nodes,expected_node_changes)
    
    assert(inspector.cleanup(scm_repo.dir.to_s))
    assert(inspector.cleanup(base_repo.dir.to_s))
    assert(inspector.cleanup(src_repo.dir.to_s))
    
#    # make some changes and commit them
#    apply_prepared_changes(inspector,change_set,scm_repo,base_repo,src_repo,'50963ed20759ce9b4dbe604a896d108e0df6e496',opts)
#    # fifth investigation: TODO move this test case to change_detector_test
#    change_set = inspector.investigate_repo(scm_repo, opts)
#    
#    expected_module_changes = [
#      ## pgsql: different git branch, wget: updated forge version
#      'akquinet/postgresql','maestrodev/wget'
#      ## deleted modules do not affect the node definitions anymore
#      ## so far the framework does not test for leftover module usages
#      ## which one forgot to remove while removing the module itself
#      ## TODO implement a test mechanism for that
#      ]
#    assert_equal(expected_module_changes.size,change_set.modules.size)    
#    run_investigate_module_changes(change_set.modules,expected_module_changes)
#    
#    ## nodename => file 
#    expected_node_changes = {
#      ## node[245] do not have direct postgresql or direct wget references
#      'node1, node1.local.com' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'node1.pp',
#      'subnode1' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'subfolder'+FSEP+'subnode1.pp',
#      'subnode2' => scm_repo.dir.to_s+FSEP+'manifests'+FSEP+'nodes'+FSEP+'subfolder'+FSEP+'subnode2.pp'      
#    }
#    puts change_set.nodes.to_s
#    assert_equal(expected_node_changes.size,change_set.nodes.size)    
#    run_investigate_node_changes(change_set.nodes,expected_node_changes)
  end
  
  def apply_prepared_changes(inspector,change_set,scm_repo,base_repo,src_repo,commit_hash,opts)
    ## there is no cherry-pick support in ruby-git yet
    ## so we use this rather complicated 
    ## "checkout master commit"-"copy files to branch"-"commit changes in branch"-workflow
    base_repo.checkout('master')    
    inspector.promote_changes(scm_repo, change_set, opts)
    src_repo.checkout(commit_hash)
    scm_repo.checkout(scm_repo.branch(opts[:dev_branch]))
    scmdir = scm_repo.dir.to_s+FSEP
    srcdir = src_repo.dir.to_s+FSEP
    FileUtils.rm_rf([scmdir+'Puppetfile',scmdir+'Puppetfile.lock',scmdir+'manifests'])
    FileUtils.cp_r([srcdir+'Puppetfile',srcdir+'Puppetfile.lock',srcdir+'manifests'], scmdir)
    scm_repo.add(:all=>true)
    scm_repo.commit_all('squashed master '+commit_hash)
  end
  
  #  def test_investigateRepo    
  #    fsep = File::SEPARATOR
  #    testRootDir='/tmp'
  #    repoName='git_change_inspector_test.git'
  #    repoURL='https://git.spree.de/scm-manager/git/infrastructure/ppt/'+repoName
  #    manifestsPath=testRootDir+fsep+repoName+fsep+'manifests'
  #    inspector = GitChangeInspector.new
  #    
  #    expectedNodeChanges = Set.new ['nodes'+fsep+'node2','nodes2'+fsep+'sub2node1','nodes'+fsep+'subfolder'+fsep+'subsubfolder'+fsep+'subsubnode1','nodes'+fsep+'subfolder'+fsep+'subnode1','nodes'+fsep+'subfolder'+fsep+'subnode2','nodes'+fsep+'node4','nodes'+fsep+'node5' ]
  #    notChangedNodes = Set.new ['nodes'+fsep+'node3','nodes'+fsep+'node1','nodes'+fsep+'subfolder'+fsep+'subnode3']
  #    changeSet = inspector.investigateRepo(repoURL, testRootDir, 'promoted', 'master')
  #    expectedModuleChanges= Set.new ['saheba/phantomjs','akquinet/archmngt','akquinet/postgresql','example42/apache','akquinet/apache_crowd','akquinet/apache_addfiles','maestrodev/jetty','akquinet/jpackage_repo']
  #    notChangedModules = Set.new ['akquinet/unzip','akquinet/jboss','akquinet/maven','saheba/openjdk_6_jre']
  #    run_investigateNodeChanges(changeSet,expectedNodeChanges,notChangedNodes,manifestsPath)
  #    run_investigateModuleChanges(changeSet,expectedModuleChanges,notChangedModules)
  #    
  #    # expectedNodeChanges= Set.new ['node3','subnode1','subnode2','subnode3','node4','node5' ]
  #    # notChangedNodes = Set.new ['node2','sub2node1','node1']
  #    # the change set MUST NOT contain node3 because this node will not be tested anymore, because it was deleted from the configuration, but NOT added to it.
  #    expectedNodeChanges= Set.new ['nodes'+fsep+'subfolder'+fsep+'subnode1','nodes'+fsep+'subfolder'+fsep+'subnode2','nodes'+fsep+'node4','nodes'+fsep+'node5' ]
  #    notChangedNodes = Set.new ['nodes'+fsep+'node2','nodes2'+fsep+'sub2node1','nodes'+fsep+'node1','nodes'+fsep+'node3','nodes'+fsep+'subfolder'+fsep+'subnode3']
  #    expectedModuleChanges= Set.new ['example42/apache','akquinet/apache_crowd','akquinet/apache_addfiles','maestrodev/jetty','akquinet/jpackage_repo']
  #    notChangedModules = Set.new ['akquinet/unzip','akquinet/jboss','akquinet/maven','saheba/openjdk_6_jre','akquinet/archmngt','saheba/phantomjs','akquinet/postgresql']
  #    changeSet = inspector.investigateRepo(repoURL, testRootDir, 'promoted2', 'master')
  #    run_investigateNodeChanges(changeSet,expectedNodeChanges,notChangedNodes,manifestsPath)
  #    run_investigateModuleChanges(changeSet,expectedModuleChanges,notChangedModules)
  #  end
  #  
  #  def run_investigateNodeChanges(changeSet,expectedNodeChanges,notChangedNodes,manifestsPath)
  #    expectedNodeChanges.each do |change| 
  #      puts "expected not to be nil: "+change
  #      assert_not_nil(changeSet.nodes[manifestsPath+File::SEPARATOR+change+'.pp'])
  #    end
  #    notChangedNodes.each do |nochange| 
  #      puts "expected to be nil: "+nochange
  #      assert_nil(changeSet.nodes[manifestsPath+File::SEPARATOR+nochange+'.pp'])
  #    end
  #  end
  # 
  def run_investigate_node_changes(nodes_hash,expected_node_changes)
    expected_node_changes.each do |key, val|
      assert_not_nil(nodes_hash[val])
      assert_equal(key, nodes_hash[val].name)      
    end
    
  end
  
  def run_investigate_module_changes(modules_hash,expected_module_changes,not_changed_modules=nil)
    expected_module_changes.each do |change| 
      puts "expected not to be nil: "+change
      assert_not_nil(modules_hash[change])
      assert_equal(Item::MODULE,modules_hash[change].item_type)
    end
    if not_changed_modules
      not_changed_modules.each do |nochange| 
        puts "expected to be nil: "+nochange
        assert_nil(modules_hash[nochange])
      end
    end
  end
end
