# Class: puppet-archmngt
#
# This module contains definitions to manage archives. It supports methods to deal with tar and zip-files at the moment.
#
# Parameters: 
# 
# [*archive_file*]
# absolute path to the archive file with which you would do something (extract, compress, etc.)
#
# [*target_dir]
# directory to which contents of an archive shall be extracted
#
# [*overwrite*]
# whether to overwrite existing files without prompt (prompts may cause puppet warnings or errors), default value is 
# false, set this parameter to true if you are sure you do not overwrite anything important accidently in the [*target_dir*]
#
# [*archive_type*]
# file suffix can be explicitly set through this variable, if download url does not end with .tar, .gz or .zip
#
# Actions:
#
# Requires:
#
# Sample Usage: 
# archmngt::extract { "extract_file.zip":
# 			archive_file => 'path/to/my/file.zip', 
# 			target_dir => 'extract/to/this/dir',
# }
#
# [Remember: No empty lines between comments and class definition]
define archmngt::extract ($archive_file,
	$nocheckcertificate_if_https = false,
	$target_dir,
	$overwrite = false,
	$archive_type = undef) {
	$file_name_segments = split($archive_file, '[.]')
	case $archive_type {
	  undef: {
	     $file_suffix = last_element($file_name_segments)	   
	   }
	   default: {
	     $file_suffix = $archive_type
	   }
	}
	
	case $::operatingsystem {
		/(?i:Debian|Ubuntu|RedHat|Centos|OEL)/ : {
			case $file_suffix {
				'gz', 'tar' : {
					$extract_command = "tar xf"
					$overwrite_param = $overwrite ? {
						true => " --overwrite",
						default => "",
					}
					$extract_command_params_before_filename = ""
					$extract_command_params_after_filename =
					" --no-same-owner$overwrite_param"
					$extract_requires = undef
				}
				'zip' : {
					$extract_command = "unzip"
					$overwrite_param = $overwrite ? {
						true => " -o",
						default => "",
					}
					$extract_command_params_before_filename = "$overwrite_param"
					$extract_command_params_after_filename = ""
					$extract_requires = [Package['unzip']]
				}
				default : {
					fail("packaging type $file_suffix is not yet supported.")
				}
			}
			$segments_archive_file = split($archive_file, '[:]')
			$first_seg_archive_file = $segments_archive_file[0]
			case $first_seg_archive_file {
				'http','https': {
					$timestamp=time()
					$tmp_file = "/tmp/puppet_download_$timestamp.$file_suffix"
					wget::fetch { "fetch_archive_from_remote_$timestamp.$file_suffix":
						source => "$archive_file",
						destination => "$tmp_file",
						before => Exec["${archive_file}_extract"],
						redownload => true,
						nocheckcertificate => $nocheckcertificate_if_https,
					}
					$file_to_extract = "$tmp_file"					
				}
				default : {
					$file_to_extract = "$archive_file"
				}
			}	
			
			exec {
				"${archive_file}_extract" :
					command =>
					"$extract_command$extract_command_params_before_filename ${file_to_extract}$extract_command_params_after_filename",
					path => ["/bin", "/sbin", "/usr/bin"],
					cwd => "${target_dir}",
					require => $extract_requires,
			}
			case $first_seg_archive_file {
				'http','https': {
					file { "$tmp_file":
						ensure => absent,					
						require => Exec ["${archive_file}_extract"],
					}
				}
				default : {
					
				}
			
			}
		}
		default : {
			 fail("operatingsystem $::operatingsystem is not supported")
		}
	}
}
