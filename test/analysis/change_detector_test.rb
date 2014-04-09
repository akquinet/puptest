# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

#$:.unshift File.join(File.dirname(__FILE__),'..','lib')
$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
puts File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'analysis/change_detector'
require 'util/item'

class ChangeDetectorTest < Test::Unit::TestCase
  def test_detect_changes
    change_detector = ChangeDetector.new()
    
    module_tree = Hash.new
    modules = Array.new
    10.times do |i|
      nr=i+1
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
    puts affections.to_s
    
    affections.each do |affector,affected_items|
      exp_affected_items = expected_affections[affector]
      duplicate_set = exp_affected_items.clone
      affected_items.each do |affected_item_name|
        result= duplicate_set.delete?(affected_item_name)
        assert_not_nil(result,'affector '+affector+' > affectedItem not found: '+affected_item_name)
      end
      assert_equal(0,duplicate_set.size())
    end
 
  end
  
  def test_flatten_affection_map
    modules = Array.new
    5.times do |i|
      nr=i+1
      modules[nr] = Item.new(Item::MODULE, :plain_name, 'm'+nr.to_s)
    end
    
    expected_affections = Hash.new
    expected_affections[modules[2].name] = Set.new [modules[1].name]
    expected_affections[modules[3].name] = Set.new [modules[1].name, modules[5].name]
    expected_affections[modules[4].name] = Set.new [modules[3].name, modules[1].name, modules[5].name]
    expected_affections[modules[5].name] = Set.new [modules[3].name, modules[1].name]
    
    change_detector = ChangeDetector.new()
    flattened = change_detector.flatten_affection_map(expected_affections)
    5.times do |i|
      assert(flattened.include?('m'+(i+1).to_s),'missing module m'+(i+1).to_s+' in flattened map')
    end
  end
  
  #  def test_detectChanges
  #    changeDetector = ChangeDetector.new()
  #    changeDetector.detectChanges(repo_url, destination_dir, 'promoted', 'master', '.pp')
  #  end
end
