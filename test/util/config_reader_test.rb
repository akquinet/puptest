# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'util/config_reader'

class ConfigReaderTest < Test::Unit::TestCase
  def test_initialize
    inifile_path = File.join(File.dirname(__FILE__),'inifile.test.conf')
    config_reader = ConfigReader.new(inifile_path)
    configuration = config_reader.configuration
    assert_not_nil(configuration['testprop1'])
    assert_equal('whatever',configuration['testprop1'])
    assert_equal('whatever',configuration[:testprop1])
  end
end
