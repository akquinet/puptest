# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

#$:.unshift File.join(File.dirname(__FILE__),'..','lib')
$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
$:.unshift File.join(File.dirname(__FILE__),'..')
puts File.join(File.dirname(__FILE__))

require 'test/unit'
require 'analysis/change_detector'
require 'util/item'
require 'util/change_simulator'
require 'git'

class ChangeDetectorTest < Test::Unit::TestCase
  include ChangeSimulator
  
  def test_generate_affection_tree
    change_detector = ChangeDetector.new()
    
    module_tree = Hash.new
    modules = Array.new
    10.times do |i|
      nr=i
      modules[nr] = Item.new(Item::MODULE, :plain_name, 'm'+nr.to_s)
      module_tree[modules[nr].name] = modules[nr]
    end
    
    #    m1 = Item.new(Item::MODULE, :plain_name, 'm1')
    #    m2 = Item.new(Item::MODULE, :plain_name, 'm2')
    #    m3 = Item.new(Item::MODULE, :plain_name, 'm3')
    #    m4 = Item.new(Item::MODULE, :plain_name, 'm4')
    #    m5 = Item.new(Item::MODULE, :plain_name, 'm5')
    #    module_tree[m1.name] = m1
    #    module_tree[m2.name] = m2
    #    module_tree[m3.name] = m3
    #    module_tree[m4.name] = m4
    #    module_tree[m5.name] = m5
    
    # dependencies
    # m1 depends on
    # ---- m2
    # ---- m3
    # m3 depends on
    # ---- m4
    # ---- m5    
    modules[1][modules[2].name] = modules[2]
    modules[1][modules[3].name] = modules[3]
    modules[3][modules[4].name] = modules[4]
    modules[3][modules[5].name] = modules[5]
    modules[5][modules[3].name] = modules[3]
    ####################
    # generates affection map:
    # m2 -> m1
    # m3 -> m1, m5
    # m4 -> m3, m1, m5
    # m5 -> m3, m1
    expected_affections = Hash.new
    expected_affections[modules[2].name] = Set.new [modules[1].name]
    expected_affections[modules[3].name] = Set.new [modules[1].name, modules[5].name]
    expected_affections[modules[4].name] = Set.new [modules[3].name, modules[1].name, modules[5].name]
    expected_affections[modules[5].name] = Set.new [modules[3].name, modules[1].name]
    
    affections = change_detector.generate_affection_tree(module_tree)
#    ensure that all modules are part of the affections hash.
#    modules which do not affect other modules are included with an empty
#    set in the affections hash.
    assert_equal(modules.size(),affections.size())
    puts affections.to_s
    
    affections.each do |affector,affected_items|
      exp_affected_items = expected_affections[affector]
      if (exp_affected_items)
        duplicate_set = exp_affected_items.clone
        affected_items.each do |affected_item_name|
          result= duplicate_set.delete?(affected_item_name)
          assert_not_nil(result,'affector '+affector+' > affectedItem not found: '+affected_item_name)
        end
        assert_equal(0,duplicate_set.size())
      end
    end
 
  end
  #  
  #  def test_flatten_affection_map
  #    modules = Array.new
  #    6.times do |i|
  #      nr=i+1
  #      modules[nr] = Item.new(Item::MODULE, :plain_name, 'm'+nr.to_s)
  #    end
  #    
  #    expected_affections = Hash.new
  #    expected_affections[modules[2].name] = Set.new [modules[1].name]
  #    expected_affections[modules[3].name] = Set.new [modules[1].name, modules[5].name]
  #    expected_affections[modules[4].name] = Set.new [modules[3].name, modules[1].name, modules[5].name]
  #    expected_affections[modules[5].name] = Set.new [modules[3].name, modules[1].name]
  #    expected_affections[modules[6].name] = Set.new
  #    
  #    change_detector = ChangeDetector.new()
  #    flattened = change_detector.flatten_affection_map(expected_affections)
  #    6.times do |i|
  #      assert(flattened.include?('m'+(i+1).to_s),'missing module m'+(i+1).to_s+' in flattened map')
  #    end
  #  end
  
    def test_detect_changes
      # white box test with mocks that cover already tested parts:
      #      # tested by GitChangeInspectorTest.test_clone_repo
      #      scm_repo=@scm_change_inspector.clone_repo(repo_url, opts[:destination_dir])
      #      # tested by GitChangeInspectorTest.test_investigate_repository
      #      change_set = @scm_change_inspector.investigate_repo(scm_repo, opts)
      #      module_initializer = ModuleInitializer.new(scm_repo.scm_repo.dir.to_s)
      #      # tested by ModuleInitializerTest.test_install_modules
      #      module_initializer.install_modules()
      # =>  this means we only have to test cases, in which nodes are indirectly affected by module changes
      testopts = {
        :destination_dir => '/tmp',        
        :dev_branch => 'master',
        :repo_name_in_destination => "test_detect_changes"
      }
        
      ## dependencies inside the test repo:
      ## node1.pp --- puppetlabs/passenger -> puppetlabs/apache
      ##          \
      ##           \
      ##            puppetlabs/nodejs -> puppetlabs/stdlib
      ##           /
      ##          /
      ## node2.pp
      ##
      ## no dependencies:
      ##            saheba/netrc
      ##
      ## changes performed during test execution
      ## A: puppetlabs/vcsrepo 1.0.1 -> 1.0.0
      ## B: puppetlabs/stdlib 2.4.0 -> 3.0.0
      ## C: +saheba/netrc
      inspector = GitChangeInspector.new    
      src_repo_dir=File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + testopts[:repo_name_in_destination]     
      src_repo = inspector.clone_repo(src_repo_dir, File::SEPARATOR+'tmp', testopts[:repo_name_in_destination]+'_src') 
      src_repo.checkout('master')
      base_repo = inspector.clone_repo(src_repo_dir, File::SEPARATOR+'tmp', testopts[:repo_name_in_destination]+'_base',true)    
  #    base_repo.checkout('master')
  #    base_repo.checkout(testopts[:dev_branch])
  
      expected_manifests_dir=testopts[:destination_dir]+File::SEPARATOR+
        testopts[:repo_name_in_destination]+File::SEPARATOR+'manifests'+File::SEPARATOR+'nodes'+File::SEPARATOR      
        
      change_detector = ChangeDetectorMock.new()
      change_set = change_detector.detect_changes(base_repo.repo.to_s, testopts)
      
      assert_equal(2, change_set.nodes.size)
      assert_not_nil(change_set.nodes[expected_manifests_dir+'node1.pp'])
      assert_not_nil(change_set.nodes[expected_manifests_dir+'node2.pp'])
        
      ## change A: puppetlabs/vcsrepo 1.0.1 -> 1.0.0
      scm_repo=Git.open(testopts[:destination_dir]+File::SEPARATOR+testopts[:repo_name_in_destination])
      apply_prepared_changes(change_detector.scm_change_inspector,change_set,
        scm_repo,base_repo,src_repo,'74869af36aeab5bd6ab4fea6d1405d9524aa9da4',testopts,true,true)
      
      change_set = change_detector.detect_changes(base_repo.repo.to_s, testopts)
      assert_equal(1, change_set.nodes.size)
      assert_not_nil(change_set.nodes[expected_manifests_dir+'node1.pp'])
      assert_nil(change_set.nodes[expected_manifests_dir+'node2.pp'])
        
      ## change B: puppetlabs/stdlib 2.4.0 -> 3.0.0
      scm_repo=Git.open(testopts[:destination_dir]+File::SEPARATOR+testopts[:repo_name_in_destination])
      apply_prepared_changes(change_detector.scm_change_inspector,change_set,
        scm_repo,base_repo,src_repo,'bff9e79229176da901669c1e3fc450081cf2db12',testopts,true,true)
        
      change_set = change_detector.detect_changes(base_repo.repo.to_s, testopts)
      assert_equal(2, change_set.nodes.size)
      assert_not_nil(change_set.nodes[expected_manifests_dir+'node1.pp'])
      assert_not_nil(change_set.nodes[expected_manifests_dir+'node2.pp'])
        
      ## change C: +saheba/netrc
      scm_repo=Git.open(testopts[:destination_dir]+File::SEPARATOR+testopts[:repo_name_in_destination])
      apply_prepared_changes(change_detector.scm_change_inspector,change_set,
        scm_repo,base_repo,src_repo,'43d02a2260a32a635f6795bf555277586c2972e2',testopts,true,true)
        
      change_set = change_detector.detect_changes(base_repo.repo.to_s, testopts)
      assert_equal(0, change_set.nodes.size)
      
      FileUtils.rm_rf([base_repo.repo.to_s,scm_repo.dir.to_s,src_repo.dir.to_s])
      assert_equal(false,File.exists?(base_repo.repo.to_s))
      assert_equal(false,File.exists?(scm_repo.dir.to_s))
      assert_equal(false,File.exists?(src_repo.dir.to_s))
    end
   
end

class ChangeDetectorMock < ChangeDetector
  attr_reader :scm_change_inspector
    
  def initialize
    super
  end
end
