# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'util/config_reader'

class ConfigReaderTest < Test::Unit::TestCase
  def test_initialize
    inifile_path = File.join(File.dirname(__FILE__),'inifile.test.conf')
    ppinifile_path = File.join(File.dirname(__FILE__),'ppinifile.test.conf')
    config_reader = ConfigReader.new(inifile_path,ppinifile_path)
    assert_not_nil(config_reader.opts['testprop1'])
    assert_equal('whatever',config_reader.opts['testprop1'])
    assert_not_nil(config_reader.opts[:testprop1])
    assert_equal('whatever',config_reader.opts[:testprop1])
    assert_nil(config_reader.puppetmaster_opts['bla'])
    assert_nil(config_reader.puppetmaster_opts[:bla])
    assert_not_nil(config_reader.puppetmaster_opts['testenv'])
    assert_equal('whatever2',config_reader.puppetmaster_opts['testenv'])
    assert_not_nil(config_reader.puppetmaster_opts[:testenv])
    assert_equal('whatever2',config_reader.puppetmaster_opts[:testenv])
    
  end
end
