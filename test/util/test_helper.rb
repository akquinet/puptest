# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'fileutils'

module TestHelper
   
  def create_simple_change_set
    change_set = ChangeSet.new(nil)
    @ref1 = 'master'
    @ref2 = 'promoted'
    @commit1 = '1324fwt432z'
    @commit2 = 'wzwegsf4t'
    change_set.dev_ref = @ref1
    change_set.promoted_ref = @ref2
    change_set.promoted_commit = @commit1
    change_set.previous_promoted_commit = @commit2
    change_set.nodes['node1'] = Item.new(Item::NODE, :plain, 'node1')
    change_set.nodes['node1'].short_names = Set.new ['shorty1','shorty2']
    change_set.modules['module1'] = Item.new(Item::MODULE, :plain, 'module1')
    change_set.classes['class1'] = Item.new(Item::CLASS, :plain, 'class1')
    return change_set
  end
  
  def create_temp_repo(clone_path)
    filename = 'git_test' + Time.now.to_i.to_s + rand(300).to_s.rjust(3, '0')
    @tmp_path = File::SEPARATOR + "tmp" + File::SEPARATOR + filename
    FileUtils.mkdir_p(@tmp_path)
    FileUtils.cp_r(clone_path, @tmp_path)
    FileUtils.cp_r(clone_path + File::SEPARATOR + '.git', @tmp_path + File::SEPARATOR + '.git')
    tmp_path = File.join(@tmp_path, 'working')
#    Dir.chdir(tmp_path) do
#      FileUtils.mv('dot_git', '.git')
#    end
    return tmp_path
  end
end
