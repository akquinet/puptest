class postgresql::server ($version = '8.4',
	$listen_addresses = 'localhost',
	$max_connections = 100,
	$shared_buffers = '24MB',
	$package_to_install = '',
	$package_client_to_install = undef,
	$clean = false,
	$pg_hba_access_rules =
	['local   all         all                               ident',
	'host    all         all         127.0.0.1/32          ident',
	'host    all         all         ::1\/128               ident'],
	$conf_track_counts_value = 'off',
	$conf_autovacuum_value = 'off',
	$conf_max_prepared_transactions_value = '0',
	$conf_max_connections_value = '100',
	$conf_shared_buffers_value = '32MB',
	$conf_data_dir = 'standard',
	$conf_pghba_dir = 'standard') {
	$confpathRHC = $version ? {
		'9.2' => '/var/lib/pgsql/9.2/data',
		default => '/var/lib/pgsql/data',
	}
	$confpath = $::operatingsystem ? {
		'redhat' => "$confpathRHC",
		'centos' => "$confpathRHC",
		default => "/etc/postgresql/${version}/main",
	}
	class {
		'postgresql::client' :
			version => $version,
			package_client_to_install => $package_client_to_install,
	}
#	Class['postgresql::server'] -> Class['postgresql::client'] 
	
	if $package_to_install == '' {
		$pkgname = $::operatingsystem ? {
			'redhat' => "postgresql-server",
			'centos' => "postgresql-server",
			default => "postgresql-${version}",
		}
	}
	else {
		$pkgname = "$package_to_install"
	}
	package {
		"${pkgname}" :
			ensure => present,
	}
	File {
		owner => 'postgres',
		group => 'postgres',
	}
	case $version {
		'9.2' : {
			$initdSuffix = '-9.2'
		}
		default : {
			$initdSuffix = ''
		}
	}
	if $clean {
	  $confdatadir = $conf_data_dir ? {
	    'standard' => '',
	     default => " ; rm -rf $conf_data_dir",
	  }
		exec {
			"reinitialize_pgsql_server" :
				command =>
				"/etc/init.d/postgresql$initdSuffix stop; rm -rf $confpath$confdatadir ; /etc/init.d/postgresql$initdSuffix initdb",
				path => ["/bin", "/sbin"],
				cwd => "/var",
				require => Package[$pkgname],
		}
		$srv_subscriptions = [File['pg_hba.conf'], File['postgresql.conf']]
	}
	else {
		exec {
			"reinitialize_pgsql_server" :
				command =>
				"echo \"puppet: postgresql-module: clean was set to false -> no reinitialization of data folder performed\"",
				path => ["/bin", "/sbin"],
				cwd => "/var",
				require => Package[$pkgname],
		}
		$srv_subscriptions = [Package[$pkgname], File['pg_hba.conf'],
		File['postgresql.conf']]
	}
	
	case $conf_data_dir {
		'standard' : {
			exec {
				"cp_recursively_data_dir" :
				command => "/bin/echo 'nothing to do because standard configuration is used'",
			}
		}
		default : {
			exec {
				"cp_recursively_data_dir_1" :
				command => "/bin/cp -rf $confpath/* $conf_data_dir/ ; chown -R postgres:postgres $conf_data_dir ; chmod -R 700 $conf_data_dir",
				cwd => "$conf_data_dir",
				path => ["/bin", "/sbin"],
				require => Exec["reinitialize_pgsql_server"],
			} -> exec {
				"cp_recursively_data_dir" :
				command => "sed -i \"s%PGDATA=$confpath%PGDATA=$conf_data_dir%\" /etc/init.d/postgresql$initdSuffix",
				cwd => "$conf_data_dir",
				path => ["/bin", "/sbin"],
			}
			
		}
	}
	
	$pghba_dir = $conf_pghba_dir ? {
		'standard' => $confpath,
		default => $conf_pghba_dir,
	}
	file {
		'pg_hba.conf' :
			path => "$pghba_dir/pg_hba.conf",
			content => template('postgresql/pg_hba.conf.erb'),
			mode => '0640',
			require => [Package[$pkgname], Exec["reinitialize_pgsql_server","cp_recursively_data_dir"]]
	}

	##postgresql.conf prepare vars start#
	if $conf_autovacuum_value != 'off' {
		$cfg_autovacuum = ''
	}
	else {
		$cfg_autovacuum = '#'
	}
	if $conf_track_counts_value != 'off' {
		$cfg_track_counts = ''
	}
	else {
		$cfg_track_counts = '#'
	}
	if $conf_max_prepared_transactions_value != '0' {
		$cfg_max_prepared_transactions = ''
	}
	else {
		$cfg_max_prepared_transactions = '#'
	}

	##postgresql.conf prepare vars end#
	case $::operatingsystem {
		redhat, centos : {
			$os_conf_file_suffix = '.rhel'
		}
		default : {
			$os_conf_file_suffix = ''
		}
	}
	$conf_file_dir = $conf_data_dir ? {
		'standard' => "$confpath",
		default => "$conf_data_dir", 
	}
	
	file {
		'postgresql.conf' :
			path => "$conf_file_dir/postgresql.conf",
			content => template("postgresql/postgresql.conf$os_conf_file_suffix.erb"),
			require => [Package[$pkgname], Exec["reinitialize_pgsql_server","cp_recursively_data_dir"]]
	}
	
	
	service {
		"postgresql$initdSuffix" :
			ensure => running,
			enable => true,
			hasstatus => true,
			hasrestart => true,
			subscribe => $srv_subscriptions,
			require => Exec["cp_recursively_data_dir"],
	}
}
