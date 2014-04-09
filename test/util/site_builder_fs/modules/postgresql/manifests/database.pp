define postgresql::database(
  $owner, 
  $charset='UTF8', 
  $ensure=present, 
  $template=undef
) {
  $dbexists = "psql -ltA | grep '^${name}|'"

  if $ensure == 'present' {
    
    if $template == undef {
      $templateDB = ''
    } else {
      $templateDB = " -T $template"
    }
    
    exec { "createdb $name":
      command => "createdb -O ${owner} -E ${charset}$templateDB ${name}",
      user    => 'postgres',
      unless  => $dbexists,
      path => ["/bin", "/sbin", "/usr/bin"],
      require => Postgresql::User[$owner],
    }


  } elsif $ensure == 'absent' {

    exec { "dropdb $name":
      command => "dropdb ${name}",
      user    => 'postgres',
      onlyif  => $dbexists,
      path => ["/bin", "/sbin", "/usr/bin"],
      before  => Postgresql::User[$owner],
    }
  }
}
