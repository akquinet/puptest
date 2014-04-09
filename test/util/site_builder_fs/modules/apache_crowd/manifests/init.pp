# Class: puppet-apache_crowd
#
# This module manages puppet-apache_crowd, so far only for RHEL environments.
#
# Parameters: 
# $adjust_selinux_config=true requires 
#       https://github.com/akquinet/puppet-selinux.git to ensure selinux is 
#       in a non-blocking state to be able to use the apache crowd integration 
#       instantly. 
#                       =false requires
#       that you manage your selinux configuration with another 
#       puppet-selinux module or manually before the apache crowd integration 
#       may work.
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class apache_crowd (
	$authnz_version = '2.0.1-1.el6.x86_64',
	$filter_release = '*.el6.*',
	$adjust_selinux_config = true,
){	
  #	installation of 3rd party dependencies
	case $::operatingsystem {
		redhat,centos,oel : {
			$pkg_perl = 'mod_perl'
			$pkg_perl_soap = 'perl-SOAP-Lite'
			$pkg_perl_cache = 'perl-Cache-Cache'
			$pkg_perl_libwww = 'perl-libwww-perl'
			
			package { "$pkg_perl":
					ensure => present,
			}
			package { "$pkg_perl_soap":
					ensure => present,
			} 
			package { "$pkg_perl_cache":
					ensure => present,
			} 
			package { "$pkg_perl_libwww":
					ensure => present,
			}
			$pkg_dependencies = Package['apache',"$pkg_perl","$pkg_perl_soap","$pkg_perl_cache","$pkg_perl_libwww"]			
		}
		default : {
			fail("operating system currently not supported")		
		}
	}
	
	$cmdyum = "/usr/bin/yum"
	$cmdgrep = "/bin/grep"
	$cmdtest = "/usr/bin/test"
  # adjustment of selinux state (instantly + permanently)
  if $adjust_selinux_config {
    class { "selinux":      
    }
  } else {
    notice ("please take care yourself that selinux is in permissive mode or disable if you use selinux on the target machine.")
  }
  
  # installation of apache crowd connector 
	$rpms_zipfile = "/tmp/RPMS-saved.zip"
	file { $rpms_zipfile :
	  source => "puppet:///modules/apache_crowd/RPMS.zip",	  
	}
	
	pkgmngt::install {
		"atlassian_rpms" :
			download_url => $rpms_zipfile,
			custom_install_selection => "$filter_release",
			require => [$pkg_dependencies,File[$rpms_zipfile]],
			onlyif => "$cmdtest \"$($cmdyum search perl-Atlassian-Crowd | $cmdgrep \"No Matches found\")\" != \"\"",
			notify => Service['apache'],
	}
		
}
