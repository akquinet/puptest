# = Define: pkgmngt::install
#
# This define installs a package from an rpm
#
# == Parameters
#
# [*download_url*]
# url from where to receive the rpm or a file archive (zip, tar) containing several rpms
#
# [*gpgcheck *]
# perform gpgcheck during installation, default: true
# 
#[*exec_pkgmngt_install_prefix*]
#variable which is used to attach the install exec command as a require attribute to other
#catalogue definitions
#
#[*custom_install_selection*]
#regexp filtering which files of an archive shall be part of the installation step, default: *
#
define pkgmngt::install (
	$download_url,
	$gpgcheck = true,
	$nocheckcertificate_if_https = false,
	$onlyif = undef,
	$exec_pkgmngt_install_prefix = 'pkgmngt_install_',
	$custom_install_selection = '*',
) {
	$segments = split($download_url, '[/]')
	$package_file = last_element($segments)
	$file_suffix_segments = split($download_url, '[.]')
	$file_suffix = last_element($file_suffix_segments)	
	
	case $file_suffix {
		'tar','zip','gz': {
			$target_dir="/tmp/acr_$package_file"
			file { "$target_dir":
				ensure => directory,
			}
			$segments_p = split($download_url, '[:]')
			$segment= $segments_p[0]
			exec { "echo ":
				command => "/bin/echo $segment >/tmp/echo.txt",
				cwd => "/tmp",
			}
			
			archmngt::extract { "pkgmngt_install_fetch_extract_${name}" :
				archive_file => "$download_url",
				target_dir => "$target_dir",
				overwrite => true,
				nocheckcertificate_if_https => $nocheckcertificate_if_https,
				before => Exec["${exec_pkgmngt_install_prefix}${name}"],
				require => File["$target_dir"]
			}
			$install_selection =  "$target_dir/$custom_install_selection"
		}
		default : {
			wget::fetch {
				"pkgmngt_install_fetch_${name}" :
					source => "$download_url",
					destination => "/tmp/$package_file",
					redownload => true,
					nocheckcertificate => $nocheckcertificate_if_https,
					before => Exec["${exec_pkgmngt_install_prefix}${name}"],
			}	
			$install_selection = "/tmp/$package_file"
		}
	}
			
	case $::operatingsystem {
		redhat, centos, oel : {
			$pkgmngt = "/usr/bin/yum"			
			$param_gpgcheck = $gpgcheck ? {
				false => ' --nogpgcheck',
				default => ''
			}
			exec {
				"${exec_pkgmngt_install_prefix}${name}" :
					command => "$pkgmngt -y$param_gpgcheck install $install_selection",
					cwd => "/tmp",
					onlyif => $onlyif,
			}
		}
		default : {
			exec {
				"${exec_pkgmngt_install_prefix}${name}" :
					command => "/bin/echo \"operating system $::operatingsystem not yet supported by pkgmngt\"",
										
			}
			fail("operating system $::operatingsystem not yet supported by pkgmngt")
		}
	}
}
