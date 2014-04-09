# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

#$:.unshift File.join(File.dirname(__FILE__),'..','lib')
$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
$:.unshift File.join(File.dirname(__FILE__))
puts $:

require 'test/unit'
require 'util/change_set'
require 'util/item'
require 'set'
require 'test_helper'

class ChangeSetTest < Test::Unit::TestCase
  
  include TestHelper
  
  def test_to_json
    change_set = create_simple_change_set
    json = JSON.pretty_generate(change_set)
    puts json
    ## to do: write to / read from file
    replication = ChangeSet.new(nil)
    replication.initialize_json(JSON.parse(json))
    assert_equal(@ref1,replication.dev_ref)
    assert_equal(@ref2,replication.promoted_ref)
    assert_equal(@commit1,replication.promoted_commit)
    assert_equal(@commit2,replication.previous_promoted_commit)    
  end
end
