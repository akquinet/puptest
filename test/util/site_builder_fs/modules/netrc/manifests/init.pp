# Class: puppet-netrc
#
# This module manages puppet-netrc
#
# Parameters: $user is the useraccount on the machine for which the netrc shall be configured, 
#				$machine_user_password_triples is an array of arrays containing three string params: machine, user, password
#				$root_home_directory (optional) is the directory where all user homes are located on the target machine, default value is "/home" 
#
# Actions:
#
# Requires:
#
# Sample Usage: netrc::foruser("netrc_myuser": user => 'myuser', machine_user_password_triples => [['myserver.localdomain','myuser','pw'],['mysecondserver.localdomain','myuser','pw2']])
#
# [Remember: No empty lines between comments and class definition]
class netrc {

}

define netrc::foruser($root_home_directory="/home",$user, $machine_user_password_triples) {
	$filename = ".netrc"
	$prefixes = ['machine ','	login ','	password ']
	
	file { "$root_home_directory/$user/$filename":
		ensure => present,
		content => template('netrc/netrc.erb'),
		mode => '0600',
		owner => "$user"		
	}
}