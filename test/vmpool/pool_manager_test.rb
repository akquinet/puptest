# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
puts File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'vmpool/pool_manager'

class PoolManagerTest < Test::Unit::TestCase
  
  ## requires preparation of machine on which the tests are running
  ## preparation commands:
  ## aptitude install openssh-server libvirt-bin
  ## mkdir /opt/kvm ; virsh pool-define-as puptest dir --target /opt/kvm
  ## mkdir /opt/kvm/base ; cd /opt/kvm/base ; wget [TODO URL]puptest_base.xml 
  ## mkdir /opt/kvm/base ; cd /opt/kvm/base ; wget [TODO URL]puptest_base.qcow2
  ## cp /opt/kvm/base/puptest_base.qcow2 /opt/kvm/puptest_base.qcow2
  ## virsh define /opt/kvm/base/puptest_base.xml
  def test_start_restart_stop_delete_pool
    test_opts = {
        :vm_host_url => 'localhost',
        :vm_host_login => 'root',
        :pool_size => 3,
        :vol_pool_path => '/opt/kvm'
      }
    
    pool_manager = PoolManager.new(test_opts)
    assert_equal(3, pool_manager.pool.size)
    assert_raise_with_message(PoolStartException,'Base VM puptes does not exist on host localhost/system. Please check your configuration.') do
      pool_manager.start_pool({
          :vm_host_url => 'localhost',
          :vm_host_login => 'root',
          :base_vm => 'puptes',
          :vm_level => 'system'
        })
    end
    
    ## extend running pool
    puts "-----------\nEXTENDING POOL\n-----------"
    test_opts[:pool_size] = 4
    pool_manager.restart_pool(test_opts)
    assert_equal(4, pool_manager.pool.size)
    
    ## reduce running pool
    puts "-----------\nREDUCING POOL\n-----------"
    test_opts[:pool_size] = 2
    pool_manager.restart_pool(test_opts)
    assert_equal(2, pool_manager.pool.size)
    
    assert_equal(2, pool_manager.stop_pool().size)
    assert_equal(2, pool_manager.get_all_pool_vms(test_opts).size)
    assert_equal(0, pool_manager.get_running_pool_vms(test_opts).size)
    assert_equal(2, pool_manager.delete_pool().size)
    assert_nil(pool_manager.pool)
  end
end
