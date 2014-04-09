# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
puts File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'util/module_initializer'
require 'util/git_change_inspector'

class ModuleInitializerTest < Test::Unit::TestCase
  def test_install_modules
    test_root_dir='/tmp'    
    repo_name='git_change_inspector_test.git'
    repo_url='https://git.spree.de/scm-manager/git/infrastructure/ppt/'+repo_name
    repo = GitChangeInspector.new.clone_repo(repo_url, test_root_dir, repo_name)
    mi = ModuleInitializer.new(repo.dir.to_s)
    mi.install_modules()
    
    fsep = File::SEPARATOR
    mod_dir = repo.dir.to_s + fsep + 'modules'
    
    expectedModules = ['apache','apache_addfiles','apache_crowd','unzip','stdlib','archmngt','java',
      'openjdk_6_jre','maven','jboss','postgresql','phantomjs','jpackage_repo'
    ]
    
    expectedModules.each do |item| 
      itemDir = mod_dir+fsep+item
      assert(File.exist?(itemDir),'expected file/dir does not exist '+itemDir)
      assert(File.directory?(itemDir),'expected fs element is not a dir '+itemDir)
    end
    
    
  end
end
