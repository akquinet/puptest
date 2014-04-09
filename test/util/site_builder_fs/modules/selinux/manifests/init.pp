# Class: puppet-selinux
#
# This module manages puppet-selinux
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class selinux (
  $permanent_selinux_state = params_lookup('selinux_state_permissive'), 
  $permanent_selinux_type = params_lookup('selinux_type_default'),
  $sync_state_instantly = params_lookup('selinux_type_default'),
) inherits selinux::params {
    case $::operatingsystem {
      redhat, centos, oel : {
        $config_file = '/etc/selinux/config'
      
      }
      default : {
        notice("selinux module: not yet supported $::operatingsystem")
      }
    }
  
    file {$config_file:
      content => template('selinux/etc.selinux.config.erb'),
      ensure => present,
    }
    
    
    if $sync_state_instantly {
      case $::operatingsystem {
		      redhat, centos, oel : {
		        if ($permanent_selinux_state == $selinux::params::selinux_state_enforcing) {
		            $setenf = '1'
		        } else {
		            $setenf = '0'
		        }
		        
		        $cmdtest = "/usr/bin/test"    
		        $cmdgetenf = "/usr/sbin/getenforce"
            $cmdsetenf = "/usr/sbin/setenforce"
		        exec { "setenforce_cmd":
		            command => "$cmdsetenf $setenf",
		            cwd => '/tmp',
		            onlyif => "$cmdtest $($cmdgetenf) != 'Disabled'"
		        }
		      }
		      default : {
		        notice("selinux module: not yet supported $::operatingsystem")
		      }
		  }
    } else {
      notice ("selinux current mode is still unchanged, after reboot it will be in the state: $permanent_selinux_state .")
    }
}
