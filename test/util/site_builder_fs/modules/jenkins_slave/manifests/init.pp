# Class: jenkins-slave
#
# This module manages jenkins-slave. 
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class jenkins_slave (
	$install_xvfbserver=false) {
	if ($xy != undef) {
		netrc::foruser { "netrc_for":
		  user=> $username,
		  machine_user_password_triples => $triples		  
		}
	}
        ## download tools and settings samples
        include wget 
        wget::fetch {
                "tools_download" :
                        source => "http://whatever.com",
                        destination => "/tmp/whatever.zip"
        } 
			
}
