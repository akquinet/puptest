# To change this template, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
puts File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'util/site_builder'
require 'util/item'
require 'set'

class SiteBuilderTest < Test::Unit::TestCase    
  def test_handle_import_statements  
    test_file_system = File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + "site_builder_fs"
      
    site_builder = SiteBuilder.new()
    site_builder.build_effective_site_pp(test_file_system)
    assert_equal(true,site_builder.pp_files.has_key?(test_file_system + File::SEPARATOR + 'resources.pp'))
    assert_equal(false,site_builder.pp_files.has_key?(test_file_system + File::SEPARATOR + 'resource.pp'))
    5.times do |i|  
      assert_equal(true,site_builder.pp_files.has_key?(test_file_system + File::SEPARATOR+'nodes'+File::SEPARATOR+ 'node'+ (i+1).to_s+ '.pp'))
    end
    3.times do |i|  
      assert_equal(true,site_builder.pp_files.has_key?(test_file_system +File::SEPARATOR+'nodes'+File::SEPARATOR + 'subfolder'+File::SEPARATOR+'subnode'+ (i+1).to_s+'.pp'))
    end
    1.times do |i|  
      assert_equal(true,site_builder.pp_files.has_key?(test_file_system +File::SEPARATOR+'nodes'+File::SEPARATOR + 'subfolder'+File::SEPARATOR+'subsubfolder'+File::SEPARATOR+'subsubnode'+ (i+1).to_s+'.pp'))
    end
    ## feature not implemented - bad puppet style
    1.times do |i|  
      assert_equal(false,site_builder.pp_files.has_key?(test_file_system +File::SEPARATOR+'nodes2'+File::SEPARATOR + 'sub2node'+ (i+1).to_s+'.pp'))
    end
  end
    
  def test_build_dependency_tree
    test_file_system = File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + "site_builder_fs"
      
    site_builder = SiteBuilder.new()
    site_builder.build_effective_site_pp(test_file_system)
    puts site_builder
  
    fsep = File::SEPARATOR
    abs_manifests = test_file_system + fsep + "nodes"
    abs_2_manifests = test_file_system + fsep + "nodes2"
    abs_sub_manifests = abs_manifests + fsep + "subfolder"
   
    expected_children = Hash.new
    expected_children[abs_manifests+fsep+'node1'+'.pp'] = Set.new ['unzip','maven','postgresql::server','openjdk_6_jre','jboss::install']
    domain = '.local.com'
#    expected_children['node1'+domain] = Set.new ['unzip','maven','postgresql::server','openjdk_6_jre','jboss::install']
    expected_children[abs_manifests+fsep+'node2'+'.pp'] = Set.new ['openjdk_6_jre','jboss','jboss::install','phantomjs','phantomjs::install']
    expected_children[abs_manifests+fsep+'node3'+'.pp'] = Set.new
    expected_children[abs_manifests+fsep+'node5'+'.pp'] = Set.new ['ant','maven','jpackage_repo','openjdk_6_jre']
    expected_children[abs_manifests+fsep+'node4'+'.pp'] = Set.new ['java','jetty']
    expected_children[abs_sub_manifests+fsep+'subnode1'+'.pp'] = Set.new ['apache','openjdk_6_jre','wget','unzip']
    expected_children[abs_sub_manifests+fsep+'subnode2'+'.pp'] = Set.new ['apache','apache_crowd','maven','unzip','wget','openjdk_6_jre']
    expected_children[abs_sub_manifests+fsep+'subnode3'+'.pp'] = Set.new
      
      
    5.times do |i|  
      nodename=abs_manifests+fsep+'node'+ (i+1).to_s+'.pp'      
#      if (i==0) 
#        assert_equal(true,site_builder.depencendy_tree.has_key?(nodename))
#        assert_equal(true,site_builder.depencendy_tree.has_key?(nodename+domain))
#        if expected_children.has_key?(nodename+domain)
#        puts nodename+domain + " found"
#        duplicate_set=expected_children[nodename+domain].clone()
#        site_builder.depencendy_tree[nodename+domain].each_value do |child|
#          result= duplicate_set.delete?(child.name)
#          assert_not_nil(result)
#        end
#        assert_equal(0,duplicate_set.size())
#      end
#      else
      assert_equal(true,site_builder.depencendy_tree.has_key?(nodename))
#      end
      if (i==0)
        assert(site_builder.depencendy_tree[nodename].short_names.include?('node1'+domain))
      end
      
      if expected_children.has_key?(nodename)
        puts nodename + " found"
        duplicate_set=expected_children[nodename].clone()
        site_builder.depencendy_tree[nodename].each_value do |child|
          result= duplicate_set.delete?(child.name)
          assert_not_nil(result)
        end
        assert_equal(0,duplicate_set.size())
      end
    end
      
    3.times do |i|  
      assert_equal(true,site_builder.depencendy_tree.has_key?(abs_sub_manifests+fsep+'subnode'+ (i+1).to_s+'.pp'))
    end
    1.times do |i|  
      assert_equal(true,site_builder.depencendy_tree.has_key?(abs_sub_manifests+fsep+'subsubfolder'+fsep+'subsubnode'+ (i+1).to_s+'.pp'))
    end
    ## feature not implemented - bad puppet style
    1.times do |i|  
      assert_equal(false,site_builder.depencendy_tree.has_key?(abs_2_manifests+fsep+'sub2node'+ (i+1).to_s+'.pp'))
    end
  end
    
  def test_buildModuleTree
    puts "\ntest_buildModuleTree\n---------------\n"
    test_file_system = File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + "site_builder_fs"
    module_file_system = File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + "site_builder_fs" + File::SEPARATOR + "modules"
     
    site_builder = SiteBuilder.new()    
    site_builder.build_effective_site_pp(test_file_system,module_file_system)
    puts site_builder
    
    expected_dependencies = Hash.new
    expected_contents = Hash.new
    
    expected_contents['ant'] = {
      'ant::tasks::maven' => Item::CLASS,
      'ant::tasks::sonar' => Item::CLASS,
      'ant' => Item::CLASS,
      'ant::ivy' => Item::CLASS,
      'ant::lib' => Item::DEFINE,
      'ant::params' => Item::CLASS
    }
    expected_contents['apache'] = {
      'apache::dotconf' => Item::DEFINE, 'apache' => Item::CLASS, 'apache::module' => Item::DEFINE,
      'apache::params' => Item::CLASS, 'apache::passenger' => Item::CLASS, 'apache::redhat' => Item::CLASS,
      'apache::spec' => Item::CLASS, 'apache::ssl' => Item::CLASS, 'apache::vhost' => Item::DEFINE,
      'apache::virtualhost' => Item::DEFINE
    }
    expected_contents['apache_addfiles'] = {
      'apache_addfiles::place_module_files' => Item::DEFINE
    }
    expected_contents['apache_crowd'] = {
      'apache_crowd' => Item::CLASS, 'apache_crowd::location' => Item::DEFINE
    }
    expected_contents['archmngt'] = {
      'archmngt::extract' => Item::DEFINE,
      'last_element' => Item::FUNCTION,
    }
    expected_contents['jboss'] = {
      'jboss_jdbc_driver' => Item::CLASS, 'jboss_jdbc_driver::install' => Item::DEFINE, 'jboss_service' => Item::CLASS,
      'jboss_service::install' => Item::DEFINE, 'jboss' => Item::CLASS, 'jboss::install' => Item::DEFINE
    }
    expected_contents['jenkins_slave'] = {
      'jenkins_slave' => Item::CLASS
    }
    expected_contents['https-jetty'] = {
      'https-jetty' => Item::CLASS
    }
    expected_contents['nagios-client'] = {
      'nagios_client' => Item::CLASS
    }
    expected_contents['create_resources'] = {
      'create_resources' => Item::FUNCTION     
    }
    expected_contents['git'] = {
      'git' => Item::CLASS, 'git::gitosis' => Item::CLASS
    }    
    expected_contents['java'] = {
      'java' => Item::CLASS, 'java::package_debian' => Item::CLASS, 'java::package_redhat' => Item::CLASS
    }
    expected_contents['jetty'] = {
      'jetty' => Item::CLASS   
    }
    expected_contents['jpackage_repo'] = {
      'jpackage_repo' => Item::CLASS
    }
    expected_contents['maven'] = {
      'maven::buildr' => Item::CLASS, 'maven::client_download' => Item::DEFINE, 'maven::environment' => Item::DEFINE, 
      'maven' => Item::CLASS, 'maven::install-gem' => Item::DEFINE, 'maven::managed' => Item::CLASS, 
      'maven::maven' => Item::DEFINE, 'maven::params' => Item::CLASS, 'maven::settings' => Item::DEFINE,
      'maven::settingssecurity' => Item::DEFINE, 'snapshotbaseversion' => Item::FUNCTION
    }
    expected_contents['mysql'] = {
      'mysql::bindings::java' => Item::CLASS, 'mysql::bindings::perl' => Item::CLASS, 'mysql::bindings::python' => Item::CLASS, 
      'mysql::bindings::php' => Item::CLASS, 'mysql::bindings::ruby' => Item::CLASS, 'mysql::client::install' => Item::CLASS, 
      'mysql::server::account_security' => Item::CLASS, 'mysql::server::backup' => Item::CLASS, 'mysql::server::config' => Item::CLASS, 
      'mysql::server::install' => Item::CLASS, 'mysql::server::monitor' => Item::CLASS, 'mysql::server::mysqltuner' => Item::CLASS, 
      'mysql::server::root_password' => Item::CLASS, 'mysql::server::service' => Item::CLASS, 
      'mysql::backup' => Item::CLASS, 'mysql::client' => Item::CLASS, 'mysql::bindings' => Item::CLASS, 
      'mysql::db' => Item::DEFINE, 'mysql' => Item::CLASS, 'mysql::params' => Item::CLASS, 'mysql::server' => Item::CLASS, 
      'mysql_deepmerge' => Item::FUNCTION, 'mysql_password' => Item::FUNCTION, 'mysql_strip_hash' => Item::FUNCTION
    }
    expected_contents['nagios_nrpe'] = {
      'nagios_nrpe' => Item::CLASS,     
    }
    expected_contents['netrc'] = {
      'netrc' => Item::CLASS, 'netrc::foruser' => Item::DEFINE,
    }
    expected_contents['ntpd_service'] = {
      'ntpd_service' => Item::CLASS,     
    }
    expected_contents['openjdk_6_jre'] = {
      'openjdk_6_jre' => Item::CLASS,     
    }
    expected_contents['phantomjs'] = {
      'phantomjs::install' => Item::DEFINE,
    }
    expected_contents['pkgmngt'] = {
      'pkgmngt::install' => Item::DEFINE,     
    }
    expected_contents['postgresql'] = {
      'postgresql::user' => Item::DEFINE, 'postgresql::client' => Item::CLASS, 'postgresql::server' => Item::CLASS,    
      'postgresql::database' => Item::DEFINE, 'postgresql::python' => Item::CLASS, 'postgresql::ruby' => Item::CLASS,    
      
    }
    expected_contents['puppi'] = {
      'puppi::info::instance' => Item::DEFINE,'puppi::info::module' => Item::DEFINE,'puppi::info::readme' => Item::DEFINE,     
      'puppi::mcollective::client' => Item::CLASS,'puppi::mcollective::server' => Item::CLASS,     
      'puppi::project::archive' => Item::DEFINE,'puppi::project::builder' => Item::DEFINE,'puppi::project::dir' => Item::DEFINE,     
      'puppi::project::files' => Item::DEFINE,'puppi::project::git' => Item::DEFINE,'puppi::project::maven' => Item::DEFINE,     
      'puppi::project::mysql' => Item::DEFINE,'puppi::project::service' => Item::DEFINE,'puppi::project::svn' => Item::DEFINE,         
      'puppi::project::tar' => Item::DEFINE,'puppi::project::war' => Item::DEFINE,'puppi::project::y4maven' => Item::DEFINE,     
      'puppi::project::yum' => Item::DEFINE,
      'puppi::check' => Item::DEFINE,'puppi::dependencies' => Item::CLASS,'puppi::deploy' => Item::DEFINE,     
      'puppi::extras' => Item::CLASS,'puppi::helper' => Item::DEFINE,'puppi::helpers' => Item::CLASS,     
      'puppi::info' => Item::DEFINE,'puppi' => Item::CLASS,'puppi::initialize' => Item::DEFINE,     
      'puppi::log' => Item::DEFINE,'puppi::netinstall' => Item::DEFINE,'puppi::one' => Item::CLASS,     
      'puppi::params' => Item::CLASS,'puppi::project' => Item::DEFINE,'puppi::report' => Item::DEFINE,     
      'puppi::rollback' => Item::DEFINE,'puppi::run' => Item::DEFINE,'puppi::skel' => Item::CLASS,     
      'puppi::todo' => Item::DEFINE,'puppi::two' => Item::CLASS,'puppi::ze' => Item::DEFINE,     
      'any2bool' => Item::FUNCTION, 'bool2ensure' => Item::FUNCTION, 'get_class_args' => Item::FUNCTION,
      'get_magicvar' => Item::FUNCTION, 'is_array' => Item::FUNCTION, 'options_lookup' => Item::FUNCTION,
      'params_lookup' => Item::FUNCTION, 'url_parse' => Item::FUNCTION
    }
    expected_contents['selinux'] = {
      'selinux' => Item::CLASS,     
      'selinux::params' => Item::CLASS,     
    }
    expected_contents['sshd'] = {
      'sshd' => Item::CLASS,     
    }
    expected_contents['stdlib'] = {
      'stdlib' => Item::CLASS,     
      'stdlib::stages' => Item::CLASS,     
      'abs' => Item::FUNCTION, 'bool2num' => Item::FUNCTION, 'capitalize' => Item::FUNCTION, 'chomp' => Item::FUNCTION, 
      'chop' => Item::FUNCTION, 'delete_at' => Item::FUNCTION, 'delete' => Item::FUNCTION, 'downcase' => Item::FUNCTION, 
      'empty' => Item::FUNCTION, 'flatten' => Item::FUNCTION, 'fqdn_rotate' => Item::FUNCTION, 'get_module_path' => Item::FUNCTION,
      'getvar' => Item::FUNCTION, 'grep' => Item::FUNCTION, 'has_key' => Item::FUNCTION, 'hash' => Item::FUNCTION, 
      'is_array' => Item::FUNCTION, 'is_domain_name' => Item::FUNCTION, 'is_float' => Item::FUNCTION, 'is_hash' => Item::FUNCTION, 
      'is_integer' => Item::FUNCTION, 'is_ip_address' => Item::FUNCTION, 'is_mac_address' => Item::FUNCTION,
      'is_numeric' => Item::FUNCTION, 'is_string' => Item::FUNCTION, 'join' => Item::FUNCTION, 'keys' => Item::FUNCTION, 
      'loadyaml' => Item::FUNCTION, 'lstrip' => Item::FUNCTION, 'member' => Item::FUNCTION, 'merge' => Item::FUNCTION, 
      'num2bool' => Item::FUNCTION, 'parsejson' => Item::FUNCTION, 'parseyaml' => Item::FUNCTION, 'prefix' => Item::FUNCTION, 
      'range' => Item::FUNCTION, 'reverse' => Item::FUNCTION, 'rstrip' => Item::FUNCTION, 'shuffle' => Item::FUNCTION, 
      'size' => Item::FUNCTION, 'sort' => Item::FUNCTION, 'squeeze' => Item::FUNCTION, 'str2bool' => Item::FUNCTION, 
      'str2saltedsha512' => Item::FUNCTION, 'strftime' => Item::FUNCTION, 'strip' => Item::FUNCTION, 'swapcase' => Item::FUNCTION, 
      'time' => Item::FUNCTION, 'type' => Item::FUNCTION, 'unique' => Item::FUNCTION, 'upcase' => Item::FUNCTION, 
      'validate_absolute_path' => Item::FUNCTION, 'validate_array' => Item::FUNCTION, 'validate_bool' => Item::FUNCTION, 
      'validate_hash' => Item::FUNCTION, 'validate_re' => Item::FUNCTION, 'validate_slength' => Item::FUNCTION, 'validate_string' => Item::FUNCTION, 
      'values_at' => Item::FUNCTION, 'values' => Item::FUNCTION, 'zip' => Item::FUNCTION
    }
    expected_contents['unzip'] = {
      'unzip' => Item::CLASS,     
    }
    expected_contents['wget'] = {
      'wget' => Item::CLASS,  
      'wget::fetch' => Item::DEFINE,     
      'wget::authfetch' => Item::DEFINE,     
    }
    expected_contents['wgetadvanced'] = {
      'wgetadvanced' => Item::CLASS,     
      'wgetadvanced::fetchadvanced' => Item::DEFINE,     
    }
    
    expected_dependencies['wgetadvanced'] = [ 'wget' ]
    expected_dependencies['pkgmngt'] = [ 'wget','archmngt' ]
    expected_dependencies['archmngt'] = [ 'wget' ]
    expected_dependencies['phantomjs'] = [ 'wgetadvanced' ]
    expected_dependencies['openjdk_6_jre'] = [ 'java' ]
    expected_dependencies['nagios_nrpe'] = [ 'wget' ]
    expected_dependencies['maven'] = [ 'wget', 'archmngt' ]
    expected_dependencies['jetty'] = [ 'wget' ]
    expected_dependencies['java'] = [ 'stdlib' ]
    expected_dependencies['mysql'] = [ 'stdlib' ]
    expected_dependencies['nagios-client'] = [ 'nagios_nrpe' ]
    expected_dependencies['jenkins_slave'] = [ 'wget' ]
    expected_dependencies['jboss'] = [ 'wget','wgetadvanced' ]
    expected_dependencies['archmngt'] = [ 'wget' ]
    expected_dependencies['apache_crowd'] = [ 'pkgmngt']
    expected_dependencies['apache_addfiles'] = [ 'archmngt']
    expected_dependencies['apache'] = [ 'puppi']
    expected_dependencies['ant'] = [ 'wget']
    
    
    # contents test cases
    expected_contents.each do |module_name,contents|
      module_item = site_builder.module_tree[module_name]
      #puts "module: "+module_name
      assert_not_nil(module_item)
      duplicate_contents = contents.clone
      contents.each do |exp_name,exp_type|  
        item_to_check=module_item.contains[exp_name]
        assert_not_nil(item_to_check)
        assert_equal(exp_type,item_to_check.item_type)
        duplicate_contents.delete(exp_name)
      end
      assert_equal(0,duplicate_contents.size())
      
      # test translation of class/define/include/require dep to module dep
      # TODO implement function usage scan
      dependencies_to_check = expected_dependencies[module_name]
      if (dependencies_to_check)
        duplicate_dependencies = dependencies_to_check.clone
        dependencies_to_check.each do |exp_dep| 
          dep_to_check = module_item[exp_dep]
          #puts "checking dependency: "+exp_dep+" for module "+module_name
          assert_not_nil(dep_to_check)
          assert_equal(exp_dep, dep_to_check.name)
          assert_equal(Item::MODULE, dep_to_check.item_type)
          duplicate_dependencies.delete(exp_dep)
        end
        assert_equal(0,duplicate_dependencies.size())      
      else
        #puts "module not found: "+module_item.name
        assert_equal(0,module_item.size())      
      end
    end
  end

  def test_dependency_translation
    puts "\ntest_dependency_translation\n---------------\n"
    test_file_system = File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + "site_builder_fs"
    module_file_system = File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + "site_builder_fs" + File::SEPARATOR + "modules"
     
    site_builder = SiteBuilder.new()    
    site_builder.build_effective_site_pp(test_file_system,module_file_system)
    puts site_builder
  
    fsep = File::SEPARATOR
    abs_manifests = test_file_system + fsep + "nodes"
    
    expected_condensed_children = Hash.new
    expected_condensed_children[abs_manifests+fsep+'node1'+'.pp'] = Set.new ['unzip','maven','postgresql','openjdk_6_jre','jboss']
    expected_condensed_children[abs_manifests+fsep+'node2'+'.pp'] = Set.new ['openjdk_6_jre','jboss','phantomjs']
   
      
    2.times do |i|  
      nodename=abs_manifests+fsep+'node'+ (i+1).to_s+'.pp'      
      assert_equal(true,site_builder.depencendy_tree.has_key?(nodename))
      if expected_condensed_children.has_key?(nodename)
        puts nodename + " condensed found"
        duplicate_set=expected_condensed_children[nodename].clone()
        puts "YEAH"+site_builder.condensed_dependency_tree[nodename].to_s
        site_builder.condensed_dependency_tree[nodename].each_value do |child|
          result= duplicate_set.delete?(child.name)
          assert_not_nil(result)
        end
        assert_equal(0,duplicate_set.size())
      end
    end
      
  end

end
