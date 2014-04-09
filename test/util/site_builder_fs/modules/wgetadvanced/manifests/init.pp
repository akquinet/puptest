################################################################################
# Class: wgetadvanced
#
# This module manages wget-with-auth
#
################################################################################
class wgetadvanced {
	require wget
}

################################################################################
# Definition: wget::fetchadvanced
#
# This class will download files from the internet. You may define a web proxy
# using $http_proxy if necessary. You may also define a user and a password in 
# case authentication is required.
#
################################################################################
define wgetadvanced::fetchadvanced ($source,
	$destination,
	$user = '',
	$password = '') {
	## assemble authentication string
	if $user != '' {
		if $password != '' {
			$authentication = " --user=$user --password=$password"
		}
		else {
			$authentication = ''
		}
	}
	else {
		$authentication = ''
	}

	## perform the request
	if $http_proxy {
		exec {
			"wget-$name" :
				command =>
				"/usr/bin/wget --output-document=$destination $source$authentication",
				creates => "$destination",
				environment => ["HTTP_PROXY=$http_proxy", "http_proxy=$http_proxy"],
		}
	}
	else {
		exec {
			"wget-$name" :
				command =>
				"/usr/bin/wget --output-document=$destination $source$authentication",
				creates => "$destination",
		}
	}
}