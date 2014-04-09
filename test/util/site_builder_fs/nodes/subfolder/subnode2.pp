node 'subnode2'{
	class { "openjdk_6_jre": }
	class { "wget": }
	class { "unzip": }
	class { "maven" :
		version => '3.0.4'		
	}
	wget::fetch {
		"pgsql_reporpm_fetch" :
			source => "$repo_rpm_url",
			destination => "$repo_rpm_file",
	} -> exec {
		"pgsql_reporpm_install" :
			command => "/bin/rpm -Uhv $repo_rpm_file",		
	} -> class {
		"postgresql::server" :
			package_to_install => 'postgresql92-server',
			version => '9.2',
			clean => true,			
	}
	postgresql::user {
		"${dbUser}" :
	} -> postgresql::database {
		"${dbName}" :
			owner => "${dbUser}",
			charset => "SQL_ASCII",
	}
	
	 ############################
  #### jboss installation ####
  ############################
  $var_jboss_name = 'jboss-eap'
  $var_jboss_version = '6.0'
  $gav_group='bla.bla'
  $gav_artifact = 'distribution-jboss-bla' 
  $gav_version='0.1.0-BLA'
  $gav_type = 'zip'
  $gav_classifier = ''
  $downloaded_filename="${gav_artifact}-${gav_version}.${gav_type}"
  $download_target='/tmp'
  
  file { "$var_install_dir" : 
    ensure => directory,
  }
  maven::client_download { "download_jboss_conf":
    target_dir => $download_target,
    target_filename => $downloaded_filename
  }
  
  jboss::install {
    "jboss_6_install" :
      jboss_name => "${var_jboss_name}",
      jboss_version => "${var_jboss_version}",    
      require => Exec["mvn_client_download_${gav_group}.${gav_artifact}.${gav_version}.${gav_classifier}"]      
  }
  user {
    "test" :
      ensure => present,
      groups => ["test", "jboss"],
      require => Group["jboss"]
  } 

##special case: requirement injection
	class { "apache":
		service_requires => [Package['apache'],File["$location_pps_conf","$http_proxy_conf"]],	
	}	
	
	$servername = 'bla.bla.bla'
	
	class { "apache_crowd":		
	}
	
	apache_crowd::location { "crowd":		
	}
	

	$ssl_servername = "$servername" 
	$ssl_certs_dir="$apache_home/ssl"
	
	apache::module { 'ssl':
		install_package => true,
		templatefile => 'ssl.conf.erb',
	}
	
	apache_addfiles::place_module_files { 'place_ssl_files':
	 	    module_name => 'ssl',
	 }
	## special case requirement injection reference
	file { "$apache_home/conf.d/ssl.conf":
		ensure => absent,
		require => Package['ApacheModule_ssl'], 
	}

}