require 'date'
require 'git'
require 'json'
require 'inifile'
require 'thor'
require 'librarian/action'
require 'librarian/puppet'
require 'librarian/resolver'
require "librarian/spec_change_set"
require 'librarian/puppet/environment'
require 'set'
require 'fileutils'
require 'rubygems'
require 'socket'

Gem::Specification.new do |s|
  s.authors = ['saheba']
  s.date = Date.today.to_s
  s.email = 'mail-@-saheba-dot-net'
  s.homepage = 'http://github.com/saheba/puptest'
  s.license = 'ASL 2.0'
  s.name = 'puptest'
  s.summary = 'puptest is a library that can be used in addition to librarian-puppet and puppet to
  automatically generate and run infrastructure tests according to changes made in a puppetmaster git repository.
  It documents detected change sets and promotes them to the current productive puppetmaster after all generated test cases have succeeded.'
  s.description = s.summary  
  # s.executables = ['executable_here']
  s.files = %w(LICENSE README.md Rakefile) + Dir.glob("{bin,lib,spec}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
  s.version = '0.0.1'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ['lib']
  s.requirements = ['git 1.2.6.2, or greater','librarian-puppet 1.0.2, or greater',
    'puppet 3.6.0, or greater', 'json 1.8.1, or greater', 'inifile 2.0.2, or greater',
    'librarian 0.1.2, or greater', 'thor 0.18.1, or greater'
  ]

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'test-unit'
  
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.md', 'LICENSE']  
  s.rdoc_options = ['--charset=UTF-8']
end
