node 'node2' {
		
	include openjdk_6_jre
	include jboss
	
	jboss::install { 
	"jboss_7_install":
	}
	
	include phantomjs
	phantomjs::install { 'phantom-js': }
	
}