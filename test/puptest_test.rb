# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'puptest/runner'
require 'util/git_repo_manager'
require 'util/command_module'

class PuptestTest < Test::Unit::TestCase
  include GitRepoManager
  include CommandModule
  
  def setup
#    @base_dest=File.join('/tmp','puptest_base')
#    @prod_dest=File.join('/tmp','puptest_puppet_prod')
    assert_equal(true,cleanup(File.join('/tmp','puptest_base')))
    assert_equal(true,cleanup(File.join('/tmp','puptest_puppet_prod')))
    assert_equal(true,cleanup(File.join('/tmp','puptest_changing')))
    
    @puptest_base = clone_repo('https://github.com/saheba/puppetmaster-sample.git','/tmp','puptest_base',true)
    @puppet_prod = clone_repo(@puptest_base.repo.to_s,'/tmp','puptest_puppet_prod')
    ## puppet_prod repo is not changed during tests, it is just used to run a fresh, lean configured puppetmaster
    @change_base = clone_repo(@puptest_base.repo.to_s,'/tmp','puptest_changing')
    ## change base is used to apply prepared changes to puptest base
    
    @ssh_connection_string = 'ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no '+'root'+'@localhost'
    run_command(@ssh_connection_string +' service puppetmaster stop')
    run_command(@ssh_connection_string +' mv /etc/puppet /etc/puppet_temp_off')
    run_command(@ssh_connection_string +' ln -s '+@puppet_prod.dir.to_s+' /etc/puppet')
    run_command(@ssh_connection_string +' rm -rf /var/lib/puppet/sslserver')
    run_command(@ssh_connection_string +' service puppetmaster start')
  end
  
  def test_run
    puptest = Puptest::Runner.new()
    config_file = File.join(File.dirname(__FILE__),'puptest.conf')
    pp_config_file = File.join(@puppet_prod.dir.to_s,'puppet.conf')
    ## pp_config_file does not contain confdir variable
    ## -> confdir is DEFAULT = /etc/puppet which we changed into a symbolic 
    ##    link pointing to our @puppet_prod.dir.to_s which is /tmp/puptest_puppet_prod
    
    copy_commit_push('change_0')
    status, failed_scripts, scripts = puptest.run(config_file, pp_config_file)
    # statuscode 2 in script.statuscodes array simply means that puppet has successfully recognized changes in the puppet catalog
    assert_equal(2,scripts.size)
    assert_equal(0,scripts[0].statuscodes[0])
    assert_equal(true,scripts[0].statuscodes[1] == 0 || scripts[0].statuscodes[1] == 2)
    assert_equal(0,scripts[1].statuscodes[0])
    assert_equal(true,scripts[1].statuscodes[1] == 0 || scripts[1].statuscodes[1] == 2)
    assert_equal(0,failed_scripts.size)
    assert_equal(0,status)
    
    copy_commit_push('change_1')
#    puts "press return to finish test run"
#    a = gets.chomp
    status, failed_scripts, scripts = puptest.run(config_file, pp_config_file)
    assert_equal(1,scripts.size)
    assert_equal(0,scripts[0].statuscodes[0])
    ## statuscode 6 in script.statuscodes array means there were both changes and failures
    assert_equal(true,scripts[0].statuscodes[1] != 0 && scripts[0].statuscodes[1] != 2)
    assert_equal(1,failed_scripts.size)
    assert_equal(1,status)
    
#    puts "TEST RESULT: \n"+scripts[0].results[1].to_s
    
    copy_commit_push('change_2')
#     puts "press return to finish test run"
#    a = gets.chomp
    status, failed_scripts, scripts = puptest.run(config_file, pp_config_file)
    assert_equal(0,status)
    assert_equal(0,failed_scripts.size)
    assert_equal(2,scripts.size)
    assert_equal(0,scripts[0].statuscodes[0])
    assert_equal(true,scripts[0].statuscodes[1] == 0 || scripts[0].statuscodes[1] == 2)
    assert_equal(0,scripts[1].statuscodes[0])
    assert_equal(true,scripts[1].statuscodes[1] == 0 || scripts[1].statuscodes[1] == 2) 
    
    copy_commit_push('change_3')
    status, failed_scripts, scripts = puptest.run(config_file, pp_config_file)
    assert_equal(0,status)
    assert_equal(0,failed_scripts.size)
    assert_equal(5,scripts.size)
    5.times do |i|
      assert_equal(0,scripts[i].statuscodes[0])
      assert_equal(true,scripts[i].statuscodes[1] == 0 || scripts[i].statuscodes[1] == 2)      
    end    
  end
  
  def copy_commit_push(changes_dir,branch='master')
    abs_changes_dir=File.join(File.dirname(__FILE__),'puptest',changes_dir)
#    puts abs_changes_dir.to_s
#    puts File.directory?(abs_changes_dir)
    if File.directory?(abs_changes_dir)
      Dir.entries(abs_changes_dir).each do |entry|
        if (entry != '.' && entry != '..')
#          puts "copying : "+entry
          FileUtils.cp_r(File.join(abs_changes_dir,entry.to_s), @change_base.dir.to_s)
        end        
      end
    end
    
    puts @change_base.add(:all=>true)
    puts @change_base.commit_all(changes_dir)
    puts @change_base.push('origin',branch,{:tags => true})
  end
  
  def teardown
    assert_equal(true,cleanup(@puptest_base.repo.to_s))
    assert_equal(true,cleanup(@puppet_prod.dir.to_s))
    assert_equal(true,cleanup(@change_base.dir.to_s))
    run_command(@ssh_connection_string +' service puppetmaster stop')
    run_command(@ssh_connection_string +' rm -f /etc/puppet')
    run_command(@ssh_connection_string +' mv /etc/puppet_temp_off /etc/puppet')    
    run_command(@ssh_connection_string +' service puppetmaster start')
  end
end
