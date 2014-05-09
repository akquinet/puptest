require 'git'
require 'fileutils'
require 'util/git_change_inspector'

module ChangeSimulator
  def apply_prepared_changes(inspector,change_set,scm_repo,base_repo,src_repo,commit_hash,opts,exclude_modules_dir=false,do_push=false)
    ## there is no cherry-pick support in ruby-git yet
    ## so we use this rather complicated 
    ## "checkout master commit"-"copy files to branch"-"commit changes in branch"-workflow
    puts "applying change "+commit_hash
    puts "to "+scm_repo.dir.to_s
    if (base_repo.dir != nil && base_repo.dir.to_s != '')
      base_repo.checkout('master')          
    end
    inspector.promote_changes(scm_repo, change_set, opts)
    src_repo.checkout(commit_hash)
    scm_repo.checkout(scm_repo.branch(opts[:dev_branch]))
    scmdir = scm_repo.dir.to_s+File::SEPARATOR
    srcdir = src_repo.dir.to_s+File::SEPARATOR
    puts FileUtils.rm_rf([scmdir+'Puppetfile',scmdir+'Puppetfile.lock',scmdir+'manifests',scmdir+'.tmp',scmdir+'.librarian']).to_s
    if exclude_modules_dir == true
      FileUtils.rm_rf([scmdir+'modules'])
    end
    FileUtils.cp_r([srcdir+'Puppetfile',srcdir+'Puppetfile.lock',srcdir+'manifests'], scmdir)
    puts scm_repo.add(:all=>true)
    puts scm_repo.commit_all('squashed master '+commit_hash)
    if do_push
      puts scm_repo.push('origin',opts[:dev_branch],{:tags => true})
    end
    
  end
end
