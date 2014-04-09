class selinux::params {
  $selinux_state_permissive = 'permissive'
  $selinux_state_enforcing = 'enforcing'
  $selinux_state_disabled = 'disabled'
  $selinux_sync_state_instantly_default = true
  $selinux_type_default = 'targeted'
  $selinux_type_multi = 'mls'
}