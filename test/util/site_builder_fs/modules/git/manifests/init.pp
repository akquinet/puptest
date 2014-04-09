# Class: git
#
# This class installs git
#
# Actions:
#   - Install the git package
#
# Sample Usage:
#  class { 'git': }
#
class git {

    case $operatingsystem {

    centos, redhat, oel: {
    	$pkg_name='git'
    	}
    debian, ubuntu: {
    	$pkg_name='git-core'
    	}
    }

  package { $pkg_name:
    ensure => installed,
  }
}
