# Class: puppet-jpackage-repo
#
# This module manages puppet-jpackage-repo
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class jpackage_repo {

  $repo_file="jpackage.repo"
  $repo_key_file="RPM-GPG-KEY-jpackage"
  
  file { "repo_key_file" :
    path => "/etc/pki/rpm-gpg/$repo_key_file",
    ensure => present,
    source => "puppet:///modules/jpackage_repo/$repo_key_file",
    replace => true,
  }

  file { "repo_file" :
    path => "/etc/yum.repos.d/$repo_file",
    ensure => present,
    source => "puppet:///modules/jpackage_repo/$repo_file",
    replace => true,
    require => File["repo_key_file"]
  }

}
