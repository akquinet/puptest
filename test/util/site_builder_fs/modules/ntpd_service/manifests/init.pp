# Class: ntpd-service
#
# This module manages ntpd-service
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class ntpd_service {
	## package / service for ubuntu machines: openntpd / openntpd
	case $::operatingsystem {
		redhat, centos, oel : {
			$ntp_pkg = 'ntpdate'
			$ntp_srv = 'ntpd'
		}
		ubuntu, debian : {
			$ntp_pkg = 'openntpd'
			$ntp_srv = 'openntpd'
		}
	}
	package {
		"${ntp_pkg}" :
			ensure => present
	}
	service {
		"${ntp_srv}" :
			enable => true,
			ensure => running,
			require => Package["${ntp_pkg}"],
	}
}
