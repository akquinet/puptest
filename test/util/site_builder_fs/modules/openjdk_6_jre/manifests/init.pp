# Class: openjdk-6-jre
#
# This module manages openjdk-6-jre
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
class openjdk_6_jre {
case $::operatingsystem {

    centos, redhat, oel: {
    	$javadist='java-1.6.0-openjdk'    
    	}
    debian, ubuntu: {
    	$javadist='openjdk-6-jre'
    	}
    }

class { "java" : 
	distribution => $javadist,
    version      => 'latest',
}

}
