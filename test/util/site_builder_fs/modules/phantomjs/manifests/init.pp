################################################################################
# Class: phantomjs
#
# This class will install phantomjs - a headless webkit browser
#
################################################################################
class phantomjs {
     $require = Class['wgetadvanced']
}


################################################################################
# Definition: phantomjs::fetch
################################################################################

define phantomjs::install(
        $install_dir = "/usr/local/",
        $download_url) {

    include wgetadvanced
    
    $download = "/tmp/phantomjs_download.tar.bz2"
    
    wgetadvanced::fetchadvanced {
                "phantomjs_download" :
                        source => "$download_url",
                        destination => "$download"
        }
        
}
