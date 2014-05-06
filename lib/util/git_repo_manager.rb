# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'git'

module GitRepoManager
  def initialize
    
  end
  
  def clone_repo(repo_url, destination_dir, repo_name=nil,bare=false)    
    if (repo_name == nil)
      repo_name=repo_url.split(File::SEPARATOR).last    
    end
    repo_destination=destination_dir+File::SEPARATOR+repo_name
    
    cleanup(repo_destination)
    
    return Git.clone(repo_url, repo_destination, :bare => false)
  end
  
  def cleanup(repo_destination)
    if repo_destination != nil
      if File.exists?(repo_destination)
        FileUtils.rm_rf(repo_destination)        
      end
    end
    result = true
    if File.exists?(repo_destination)
      result = false
    end
    return result
  end
end
