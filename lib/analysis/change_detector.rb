# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'util/git_change_inspector'
require 'util/change_set'
require 'util/module_initializer'
require 'util/site_builder'

class ChangeDetector
  def initialize
    
  end
  
  def detect_changes(repo_url, destination_dir, promoted_branch, dev_branch, file_suffix, module_dir='modules', path_to_root_pp= 'manifests', root_pp_file_name=SiteBuilder::SITE_PP)
    scm_change_inspector = GitChangeInspector.new()
    change_set = scm_change_inspector.investigate_repo(repo_url, destination_dir, promoted_branch, dev_branch, file_suffix, module_dir)
    module_initializer = ModuleInitializer.new(scm_change_inspector.repo_destination)
    module_initializer.install_modules()
    site_builder = SiteBuilder.new()
    abs_path_to_root_pp = scm_change_inspector.repo_destination + File::SEPARATOR + path_to_root_pp
    site_builder.buildEffectiveSitePP(abs_path_to_root_pp,module_dir,root_pp_file_name)
    
    ## walk through list of changed modules and figure out which nodes are 
    ## affected using the module and the dependency trees built with the
    ## site builder
    
    affections = generate_affection_tree(site_builder.module_tree)
    ## generate set of all modules, which are either directly affected by a change or indirectly
    all_change_affected_modules = flatten_affection_map(affections)
    
    ## go through all nodes in siteBuilder.dependency_tree
    site_builder.depencendy_tree.each do |itemKey, item|
      if item.item_type == Item::NODE
        item.each_value do |dependency|
          if (dependency.item_type == Item::MODULE && all_change_affected_modules.include?(dependency.name))
            change_set.nodes[item.name] = item
          end
        end
      end
    end
    return change_set
  end
  
  def flatten_affection_map(affections)
    change_affected_modules = Set.new
    affections.each do |affector, affected_items|
      change_affected_modules.add(affector)
      affected_items.each do |affected_item|
        change_affected_modules.add(affected_item)
      end
    end
    return change_affected_modules
  end
  
  def generate_affection_tree(module_tree)
    # affections key is the affector module name, value is a set of module names (directly or indirectly) affected by the affector
    affections = Hash.new
    module_tree.each_value do |module_item|  
      module_item.each_value do |affector_item|
        affections = recursive_affection_path_parsing(affections, affector_item, module_item)
      end
    end
    
    return affections
  end
  
  def recursive_affection_path_parsing(affections, affector_item, affected_item)
    if (!affections[affector_item.name])
      affections[affector_item.name] = Set.new
    end
    
    ## only if dependency path has not been added yet
    if (!(affections[affector_item.name].include?(affected_item.name)))
      affections[affector_item.name].add(affected_item.name)
      affector_item.each_value do |affector_dependency|
        ## only if affectorItem is not affected_item
        if (affector_dependency.name != affected_item.name)
          affections = recursive_affection_path_parsing(affections, affector_dependency, affected_item)
        end
      end
    end
    
    return affections
  end
end
