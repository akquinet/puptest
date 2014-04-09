node 'node1', 'node1.local.com' {
	class { "unzip": }
	
	
		
	include openjdk_6_jre
        class { "maven" :
		install_package => false,		
	}	
	
	jboss::install {
		"jboss_4_tdm_install" :
			require => [Exec["mvn_client_download_${gav_group}.${gav_artifact}.${gav_version}.${gav_classifier}"], Class["postgresql::server"]]
	}
	
	class {
		"postgresql::server" : 
	
	}
	
}