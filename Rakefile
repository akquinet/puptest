require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rubygems/package_task'
require 'rdoc/task'
require 'rake/testtask'
require 'git'
require 'json'
require 'librarian/action'
require 'librarian/puppet'
require 'librarian/resolver'
require "librarian/spec_change_set"
require 'librarian/puppet/environment'
require 'test/unit'
require 'set'
require 'fileutils'

spec = Gem::Specification.new do |s|
  s.name = 'puptest'
  s.version = '0.0.1'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README', 'LICENSE']
  s.summary = 'puptest is a library that can be used in addition to librarian-puppet and puppet to
  automatically generate and run infrastructure tests according to changes made in a puppetmaster git repository.
  It documents detected change sets and promotes them to the current productive puppetmaster after all generated test cases have succeeded.'
  s.description = s.summary
  s.author = 'saheba'
  s.email = 'mail-@-saheba-dot-net'
  # s.executables = ['your_executable_here']
  s.files = %w(LICENSE README Rakefile) + Dir.glob("{bin,lib,spec}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
end

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

Rake::RDocTask.new do |rdoc|
  files =['README', 'LICENSE', 'lib/**/*.rb']
  rdoc.rdoc_files.add(files)
  rdoc.main = "README" # page to start on
  rdoc.title = "puptest Docs"
  rdoc.rdoc_dir = 'doc/rdoc' # rdoc output folder
  rdoc.options << '--line-numbers'
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*.rb']
end

