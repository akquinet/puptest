node "node5" {
  include openjdk_6_jre 
   
  package { "httpd" :
     ensure => present,    
  }
 
  service { "httpd_start" :
    name => "httpd",
    ensure => running,
    enable => true,
    hasstatus => true,
    restart => true,
    require => Package["httpd"],
  } 
  include jpackage_repo
  package { "tomcat6" :
     ensure => present,
     require => [Class["jpackage_repo"]],    
  }
  class { "maven" :
    version => '3.0.4',
  }
  class { "ant" :
    version => '1.9.1',
  }  
}

import '../nodes2/*'