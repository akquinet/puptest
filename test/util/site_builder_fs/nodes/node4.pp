node 'node4' {
	case $::operatingsystem {
		centos, redhat, oel : {
			$javadist = 'java-1.6.0-openjdk'
		}
		debian, ubuntu : {
			$javadist = 'openjdk-6-jre'
		}
	}
	class {
		"java" :
			distribution => $javadist,
			version => 'latest',
	}
	class {
		"jetty" :
			require => [Class["java"], User["jetty"], File["/opt"]]
	}
	
	service {
		"jetty" :
			require => Class["jetty"]
	}
	

}