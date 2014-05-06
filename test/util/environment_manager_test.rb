# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'util/environment_manager'
require 'inifile'

class EnvironmentManagerMock < EnvironmentManager
  TEST_BASE=File.join('/'+'tmp','test_environment_manager')
  
  attr_reader :confdir_set
 def initialize(pp_conf_file=DEFAULT_PP_CONF_FILE,
      puptest_env=DEFAULT_PUPTEST_ENV_NAME, repo_url)
    super(pp_conf_file,puptest_env,repo_url)
    @confdir_set=false
  end
#  def initialize_modules(puptest_env_path)
#    return 'yeah', 0
#  end
  
  def restart_puppetmaster
    return 'yeah_ppm', 0
  end
  
  def get_gen_env_path(puppetmaster_opts)
   if puppetmaster_opts['confdir'] != nil
      @confdir_set = true
    end
    return File.join(TEST_BASE,'environments')
  end
end

class EnvironmentManagerTest < Test::Unit::TestCase
  FSEP=File::SEPARATOR
  
  def test_env_exists_does_not_exist
    env_name= 'puptest_test_env'
    base_repo = File.dirname(__FILE__) + FSEP + 'environment_manager_repo'
#    inspector = GitChangeInspector.new    
#    scm_repo = inspector.clone_repo(base_repo, FSEP+'tmp', 'test_analyse_files_for_module_changes')
    pp_base_file = File.dirname(__FILE__) + FSEP + 'environment_manager_test.puppet.conf'
    pp_conf_file = EnvironmentManagerMock::TEST_BASE + FSEP + 'environment_manager_test.puppet.conf'
    FileUtils.mkdir_p(EnvironmentManagerMock::TEST_BASE)
    FileUtils.cp(pp_base_file,pp_conf_file)
    
    environment_manager = EnvironmentManagerMock.new(pp_conf_file,env_name,base_repo)
    environment_manager.ensure_puptest_env_exists()
    assert_equal(true, File.exists?(File.join(EnvironmentManagerMock::TEST_BASE,'environments')))
    assert_equal(true, File.exists?(File.join(EnvironmentManagerMock::TEST_BASE,'environments',env_name)))
    ## test if module initialization generated expected results
    assert_equal(true, File.exists?(File.join(EnvironmentManagerMock::TEST_BASE,'environments',env_name,'modules')))
    assert_equal(true, File.exists?(File.join(EnvironmentManagerMock::TEST_BASE,'environments',env_name,'modules','apt')))
    assert_equal(true, File.exists?(File.join(EnvironmentManagerMock::TEST_BASE,'environments',env_name,'modules','stdlib')))
    assert_equal(true, File.exists?(File.join(EnvironmentManagerMock::TEST_BASE,'environments',env_name,'modules','ntp')))
    ## test if puppet.conf was updated successfully
    inifile = IniFile.load(pp_conf_file)
    check_standard_pp_config(inifile, env_name)
    assert_not_nil(inifile[env_name])
    assert_equal(2,inifile[env_name].size)    
    assert_equal(File.join(EnvironmentManagerMock::TEST_BASE,'environments',env_name,'modules'),inifile[env_name]['modulepath'])
    assert_equal(File.join(EnvironmentManagerMock::TEST_BASE,'environments',env_name,'manifests','site.pp'),inifile[env_name]['manifest'])
    
    environment_manager.ensure_puptest_env_does_not_exist()
    inifile = IniFile.load(pp_conf_file)
    assert_equal(true, File.exists?(File.join(EnvironmentManagerMock::TEST_BASE,'environments')))
    assert_equal(false, File.exists?(File.join(EnvironmentManagerMock::TEST_BASE,'environments',env_name)))
    check_standard_pp_config(inifile, env_name)
    assert_equal(true,(inifile[env_name] == nil || inifile[env_name].size == 0))
    
    FileUtils.rm_rf(EnvironmentManagerMock::TEST_BASE)
  end
  
  private 
  def check_standard_pp_config(inifile, env_name)
    assert_equal(true, (inifile['tes'] == nil || inifile['tes'].size == 0))
    assert_not_nil(inifile['master'])
    assert_equal(1,inifile['master'].size)
    assert_not_nil(inifile['agent'])
    assert_equal(2,inifile['agent'].size)
    assert_not_nil(inifile['main'])
    assert_equal(3,inifile['main'].size)
    assert_not_nil(inifile['test'])
    assert_equal(2,inifile['test'].size)
    assert_equal('/var/log/puppet',inifile['main']['logdir'])
    assert_equal('/var/run/puppet',inifile['main']['rundir'])
    assert_equal('$vardir/ssl',inifile['main']['ssldir'])
    assert_equal('$vardir/classes.txt',inifile['agent']['classfile'])
    assert_equal('$vardir/localconfig',inifile['agent']['localconfig'])
    assert_equal('/etc/puppet/tagmail.conf',inifile['master']['tagmap'])
    assert_equal('$confdir/environments/test/modules',inifile['test']['modulepath'])
    assert_equal('$confdir/environments/test/manifests/site.pp',inifile['test']['manifest'])
  end
end
