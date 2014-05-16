# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..','..','bin')
$:.unshift File.join(File.dirname(__FILE__),'..','..','lib')
puts File.join(File.dirname(__FILE__),'..','..','bin')
puts File.join(File.dirname(__FILE__),'..','..','lib')

require 'puptest_cli'
require 'test/unit'

class DummyExecutor
  attr_reader :did_run, :cf, :pcf
  
  def initialize
    @did_run = false  
    @cf = nil
    @pcf = nil
  end
  
  def run(config_file,pp_config_file)
    @did_run = true    
    @cf = config_file
    @pcf = pp_config_file
  end  
end

class PuptestCliMock < PuptestCli
  attr_reader :executor
  
  private
  
  def get_executor
    @executor = DummyExecutor.new
    return @executor
  end
end

class PuptestCliTest < Test::Unit::TestCase
  def test_audit
    cli = PuptestCliMock.new()
    cli.audit
    assert_not_nil(cli.executor)
    assert_equal(true,cli.executor.did_run)
    assert_equal(Puptest::DEFAULT_CONFIG_FILE,cli.executor.cf)
    assert_equal(Puptest::DEFAULT_PP_CONFIG_FILE,cli.executor.pcf)
  end
end
