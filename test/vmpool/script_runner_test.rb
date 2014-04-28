$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
puts File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'fileutils'
require 'vmpool/script'
require 'vmpool/script_runner'
require 'vmpool/pool_manager'

class ScriptRunnerTest < Test::Unit::TestCase
  def test_run
    scripts = []
    10.times do |i|      
      scripts[i] = Script.new('echo '+i.to_s, ['echo '+i.to_s])
    end
    test_opts = {
      :vm_host_url => 'localhost',
      :vm_host_login => 'root',
      :pool_size => 3,
      :vol_pool_path => '/opt/kvm',
      :pool_vm_identity_file => File.dirname(__FILE__)+File::SEPARATOR+'puptest-base_rsa'
    }
    FileUtils.chmod(0600,test_opts[:pool_vm_identity_file])
    pool_manager = PoolManager.new(test_opts)
    pool_manager.start_pool()
    script_runner = ScriptRunner.new(scripts, pool_manager)
    script_runner.run()
    
    assert_equal(3, pool_manager.delete_pool().size)
    assert_nil(pool_manager.pool)
  end
end
