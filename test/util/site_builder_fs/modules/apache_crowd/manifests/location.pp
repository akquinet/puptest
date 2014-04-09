define apache_crowd::location (
	$url = 'http://localhost:8095',
	$crowd_authentication_dialog_title = 'Crowd Authentication',
	$crowd_app_path,
	$crowd_app_name,
	$crowd_app_password,
	$crowd_cache = 'on',
	$crowd_cache_location = '/tmp/CrowdAuthCache',
	$crowd_cache_expiry = '300',
	$crowd_allowed_users = '',
	$crowd_allowed_groups = '',	
	$conf_file_path = '',	
) {
	
	$set_custom_conf_file_path = ($conf_file_path == '') 
	$segments = split($crowd_app_path, '[/]')
	$last_name_segment = last_element($segments)
	
	$location_conf = $set_custom_conf_file_path ? {
	 false => "$conf_file_path",
	 default => "$apache::params::config_dir/conf.d/location_${last_name_segment}.conf",
	}
	file { "$location_conf":
		ensure => present,
		content => template('apache_crowd/location.conf.erb'),
		require => [Package['apache'],Exec["pkgmngt_install_atlassian_rpms"]],
		notify => Service['apache'],
	}
}