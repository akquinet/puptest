class jetty(
	$jetty_version
) {

  
	  include wget
	  wget::fetch { "jetty_download":
	    source => "jetty.tar.gz",
	    destination => "/tmp/jetty.tar.gz",
	  }
  
}