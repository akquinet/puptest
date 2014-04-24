# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
puts File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'set'
require 'vmpool/script_runner'
require 'vmpool/script'

class ScriptRunnerMock < ScriptRunner
  def get_next_id_expl
    get_next_id
  end
end

class DummyPoolManager
  
  attr_reader :pool, :index, :free_count, :run_command_count, :thread_ids
  
  def initialize(script_array)
    @index = 0
    @free_count = 0
    @run_command_count = 0
    @script_array = script_array
    @pool = [1,2]
    @thread_ids = Set.new
  end
  
  def occupy
    vm_name = 'VM for ' + @script_array[@index].name
    @index += 1
    return vm_name
  end
  
  def free(vm)
    @free_count += 1
    return nil, vm
  end
  
  def run_command_in_pool_vm(command, vm)
    @run_command_count += 1
    statuscode = 0
    @thread_ids.add(Thread.current.to_s)
    #puts "running command "+command+" in vm "+vm+" in thread "+Thread.current.to_s
    
    if ((Integer(command.gsub('command ', ''))+1) % 3 == 0)
        #puts "command "+command+" >> "+((Integer(command.gsub('command ', ''))+1) % 3).to_s
        statuscode = 1
    end
    
    return 'result: '+command, statuscode
  end
end

class ScriptRunnerDummyPMTest < Test::Unit::TestCase
  def test_get_next_id
    test_scripts = ['a','b','c','d']
    script_runner = ScriptRunnerMock.new(test_scripts,nil)
    id = script_runner.get_next_id_expl
    assert_equal(0,id)
    id = script_runner.get_next_id_expl
    assert_equal(1,id)
    id = script_runner.get_next_id_expl
    assert_equal(2,id)
    id = script_runner.get_next_id_expl
    assert_equal(3,id)
    id = script_runner.get_next_id_expl
    assert_nil(id)    
  end
  
  def test_run
    test_scripts = []
    10.times do |i|
      commands = []
      3.times do |j|
        commands[j] = 'command '+j.to_s
      end
      test_scripts[i] = Script.new('script '+i.to_s, commands)
    end
    
    pool_manager = DummyPoolManager.new(test_scripts)
    script_runner = ScriptRunnerMock.new(test_scripts,pool_manager)
    script_runner.run
    assert_equal(30,pool_manager.run_command_count)
    assert_equal(2,pool_manager.index)
    assert_equal(9,script_runner.exec_counter)
    assert_equal(10,pool_manager.thread_ids.size)
    
    10.times do |i|      
      
      3.times do |j|
        expected = 0
        if (j == 2)
          expected = 1
        end
        puts "i = "+i.to_s+", j = "+j.to_s
        assert_equal(expected, test_scripts[i].statuscodes[j])
        assert_equal('result: '+test_scripts[i].commands[j], test_scripts[i].results[j])
      end
    end
  end
end
