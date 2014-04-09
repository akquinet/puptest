class postgresql::client (
  $version, 
  $package_client_to_install = undef
) {
  if $package_client_to_install == undef {
    $clpkgname = $::operatingsystem ? {
      'redhat' => "postgresql",
      'centos' => "postgresql",
      default  => "postgresql-${version}",
    }

    package { "$clpkgname":
      ensure => present,
    }
  } else {
    package { "$package_client_to_install":
      ensure => present,
    }
  }
}
