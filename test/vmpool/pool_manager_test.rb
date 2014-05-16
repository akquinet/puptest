# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
puts File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'vmpool/pool_manager'
require 'fileutils'

class PoolManagerTest < Test::Unit::TestCase
  def test_mac_ip_mapping
    testfile='daemon.example.log'
    src=File.dirname(__FILE__)+File::SEPARATOR+testfile
    tempdest='/tmp'+File::SEPARATOR+testfile
    FileUtils.cp(src,tempdest)
    FileUtils.chmod(0777,tempdest, {:verbose => true})
    test_opts = {
      :vm_host_url => 'localhost',
      :vm_host_login => 'root',
      :vm_host_interface => 'virbr0',
      :vm_host_mac_ip_map_file => tempdest,
      :vol_pool_path => '/opt/kvm'
    }
    pool_manager = PoolManager.new(test_opts)
    mac_ip_map = pool_manager.get_ip_mac_map_of_host_interface(test_opts)      
    FileUtils.rm_f(tempdest)
      
    expected_pairs = {
      ## several occurrences of the same entry
      '52:54:00:45:8c:af' => '192.168.122.251',
      ## single occurrence
      '52:54:00:45:8c:ae' => '192.168.122.25',
      ## double occurrence with change (first occurrence '192.168.122.21')
      'ab:54:00:45:8c:ae' => '192.168.122.22',
      ## triple occurrence with double change 
      ## (first two occurrences '192.168.122.10','192.168.122.11')
      '53:54:00:45:8c:af' => '10.16.2.253',
    }
    expected_pairs.each do |mac,ip|
      assert_not_nil(mac_ip_map[mac])
      assert_equal(ip,mac_ip_map[mac])
    end
      
  end
  
  ## requires preparation of machine on which the tests are running
  ## preparation commands:
  ## sudo aptitude install openssh-server libvirt-bin virtinst
  ## mkdir /opt/kvm ; virsh pool-define-as puptest dir --target /opt/kvm
  ## mkdir /opt/kvm/base ; cd /opt/kvm/base ; wget [TODO URL]puptest_base.xml 
  ## mkdir /opt/kvm/base ; cd /opt/kvm/base ; wget [TODO URL]puptest_base.qcow2
  ## cp /opt/kvm/base/puptest_base.qcow2 /opt/kvm/puptest_base.qcow2
  ## virsh define /opt/kvm/base/puptest_base.xml
  ### you have to define a pool otherwise you will get:
  ### ERROR    Could not determine original disk information: Disk '..' does not exist.
  ## virsh pool-define-as puptest dir --target /opt/kvm
  ## virsh pool-start puptest
  ## virsh pool-autostart puptest
  ## 
  ## do not forget to copy your ssh-pub-key into authorized_keys of root
  ## sudo mkdir /root/.ssh
  ## sudo cat $USER_HOME/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
  ## sudo chmod +r /root/.ssh/authorized_keys
  ## ssh root@localhost (once manually, to add key to known_hosts)
  def test_start_restart_stop_delete_pool
    test_opts = {
      :vm_host_url => 'localhost',
      :vm_host_login => 'root',
      :pool_size => 3,
      :vol_pool_path => '/opt/kvm'
    }
    
    pool_manager = PoolManager.new(test_opts)
    #    assert_raise_with_message(PoolStartException,'Base VM puptes does not exist on host localhost/system. Please check your configuration.') 
    
    begin
      pool_manager.start_pool({
          :vm_host_url => 'localhost',
          :vm_host_login => 'root',
          :base_vm => 'puptes',
          :vm_level => 'system'
        })
      raise(StandardError,'pool start exception not raised.')
    rescue PoolStartException => exception_trace
      assert_not_nil(Regexp.new('Base VM puptes does not exist on host localhost/system. Please check your configuration.').match(exception_trace.to_s))
    end
    
    pool_manager.start_pool()
    assert_equal(3, pool_manager.pool.size)    
    
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
    
    ## running commands in pool vms
    ## no threading
    #    puppet_version = run_command_in_pool_vm('puppet --version', test_opts)
    
    assert_equal(2, pool_manager.stop_pool().size)
    assert_equal(2, pool_manager.get_all_pool_vms(test_opts).size)
    assert_equal(0, pool_manager.get_running_pool_vms(test_opts).size)
    assert_equal(2, pool_manager.delete_pool().size)
    assert_nil(pool_manager.pool)
  end
 
  
  def test_occupy_run_command_free
    test_opts = {
      :vm_host_url => 'localhost',
      :vm_host_login => 'root',
      :pool_size => 2,
      :vol_pool_path => '/opt/kvm',
      :pool_vm_identity_file => File.dirname(__FILE__)+File::SEPARATOR+'puptest-base_rsa'
    }
    FileUtils.chmod(0600,test_opts[:pool_vm_identity_file])
    
    pool_manager = PoolManager.new(test_opts)
    pool_manager.start_pool()
    
    assert_equal(2, pool_manager.pool.size)  
    assert_equal(0,pool_manager.currently_in_use.size)
    
    selected_vm = pool_manager.occupy
    assert_equal(true,pool_manager.currently_in_use.include?(selected_vm))
    assert_equal(false,pool_manager.pool.include?(selected_vm))
    assert_equal(1, pool_manager.pool.size)  
    assert_equal(1,pool_manager.currently_in_use.size)
    
    output, statuscode = pool_manager.run_command_in_pool_vm('echo test_output', selected_vm)
    assert_equal(0,statuscode)
    assert_equal(true,Regexp.new(/test_output/).match(output) != nil)
    output, statuscode = pool_manager.run_command_in_pool_vm('exfgscho test_output', selected_vm)
    assert_equal(127,statuscode)    
    
    pool_manager.free(selected_vm)
    assert_equal(0,pool_manager.currently_in_use.size)
    assert_equal(false,pool_manager.currently_in_use.include?(selected_vm))
    assert_equal(true,pool_manager.pool.include?(selected_vm))
    assert_equal(2, pool_manager.pool.size)  
    assert_equal(0,pool_manager.currently_in_use.size)
    
    assert_equal(2, pool_manager.delete_pool().size)
    assert_nil(pool_manager.pool)
  end
  
#  def shutdown
#    puts "POOL MANAGER TEST shutdown"
#    test_opts = {
#      :vm_host_url => 'localhost',
#      :vm_host_login => 'root',
#      :pool_size => 3,
#      :vol_pool_path => '/opt/kvm'
#    }
#    
#    pool_manager = PoolManager.new(test_opts)
#    pool_manager.delete_pool()
#    assert_nil(pool_manager.pool)
#  end
  
end
