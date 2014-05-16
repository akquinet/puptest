node 'node1' {
    package { 'vim-minimal':
        ensure => present
    }
    include ruby
}