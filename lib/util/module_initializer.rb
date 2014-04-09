# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'librarian/action'
require 'librarian/puppet'

class ModuleInitializer
  def initialize(repo_dir)
    @repo_dir = repo_dir
  end
  
  def install_modules()
    env = Librarian::Puppet::Environment.new({ :project_path => @repo_dir})
    Librarian::Action::Resolve.new(env, {}).run
    Librarian::Action::Install.new(env, {}).run
    return nil
  end
end