node 'subnode1' {

	include wget, openjdk_6_jre 
	
	package { "mod_perl":
			ensure => present,
	} package { "perl-SOAP-Lite":
			ensure => present,
	} package { "perl-Cache-Cache":
			ensure => present,
	} package { "perl-libwww-perl":
			ensure => present,
	}
	
	
	include unzip
	
	class { "apache":		
	}	
	
	file { "/etc/httpd/conf.d/irgendwas_http.conf":
		ensure => present,
		notify => Service['httpd'],
		require => Package['apache'],
	}
		
	apache::module { 'ssl':
		install_package => true,
	}
	
	apache_addfiles::place_module_files { 'place_ssl_files':
	 	    module_name => 'ssl',
	}
	
		
	wget::fetch {
		"mod_authnz_crowd_fetch" :
			require => Package["apache","mod_perl","perl-SOAP-Lite","perl-Cache-Cache","perl-libwww-perl"],
	} 
	
}