class jboss_jdbc_driver {
}
define jboss_jdbc_driver::install (
	$jdbc_db) {
	
	include wget 
	wget::fetch {
		"download_${jdbc_driver_file}.jar" :
			source => "http://whatever.jar",
			destination => "/tmp/tmp.jar"
	}
}