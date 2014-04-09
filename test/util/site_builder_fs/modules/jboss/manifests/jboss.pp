# Class: jboss
#
# This module manages jboss
#
# Parameters:
#
# Actions:
#
# Requires:
#
# [Remember: No empty lines between comments and class definition]
class jboss {
	$require = Class['java']	
}

define jboss::install (
	$jboss_version) {
	## download the jboss-as bundle
	include wgetadvanced
	
#       include wget
#	wget::fetch {
#		"download" :
#			source => "whatevery.works",
#			destination =>
#			"/tmp/tmp.zip"
#	} 
	# bla
	case $version {
		n : {
			include jboss_jdbc_driver
			jboss_jdbc_driver::install {
                            "install_jdbc": 
			}
		}
	}
	
	if $yes { 
		include jboss_service
		jboss_service::install { 
		  "$install_jboss_service":
			
		}
	}
}
