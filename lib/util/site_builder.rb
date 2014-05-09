# To change this template, choose Tools | Templates
# and open the template in the editor.

require 'util/item'

class SiteBuilder
  attr_reader :pp_files, :module_files, :dependency_tree, :condensed_dependency_tree, :module_tree, :item_is_part_of, :unresolved_detail_module_dependencies, :unresolved_detail_node_dependencies
  def initialize()
    @pp_files = Hash.new
    @module_files = Hash.new
    @dependency_tree = Hash.new
    @condensed_dependency_tree = Hash.new
    @module_tree = Hash.new
    @item_is_part_of = Hash.new
    @unresolved_detail_node_dependencies = Hash.new
    @unresolved_detail_module_dependencies = Hash.new
  end
  
  SITE_PP = 'site.pp'
  DEFAULT_MODULES_DIR= 'modules'
  
  def build_effective_site_pp(path_to_root_pp,module_path=nil,filename = SITE_PP)
    return build_effective_pp(path_to_root_pp, filename,module_path)
  end
    
  def build_effective_pp(path,filename,module_path=nil)
    File.open(path+File::SEPARATOR+filename) do |file|
      file.each_line() do |line|  
        trimmed_line = line.strip
        handle_import_statements(trimmed_line,path,filename,@pp_files)
        #elsif trimmed_line =~ /$/
        # site scope variable found
        #end
      end
    end
    if (module_path)
      @module_tree, @item_is_part_of = build_module_tree(module_path,@module_tree)      
    end
    @dependency_tree = build_dependency_tree(@pp_files,@dependency_tree)
    puts "inner: "+@dependency_tree.to_s
    @condensed_dependency_tree, @unresolved_detail_node_dependencies = translate_detail_dependencies_to_module_dependencies(@dependency_tree,@condensed_dependency_tree, @item_is_part_of, @unresolved_detail_node_dependencies)
    return @dependency_tree, @condensed_dependency_tree, @module_tree
  end
    
  def to_s
    output = ""
    #@pp_files.each { |key,val| output+=key+" REF BY "+val+"\n" }  
    output += "\n\nDependency Tree:\n"
    @dependency_tree.each do |key,val|
       
      output+="--"+key+"\n"
      val.each { |key,child| output +="----"+child.name+" ("+key+"; "+child.item_type+")"+"\n"}
    end
    output += "\n\nCondensed Dependency Tree:\n"
    @condensed_dependency_tree.each do |key,val|
       
      output+="--"+key+"\n"
      val.each { |key,child| output +="----"+child.name+" ("+key+"; "+child.item_type+")"+"\n"}
    end
    output += "\n\nModule Tree:\n"
    @module_tree.each_value do |val|
      output+="\n" +val.to_s
    end
    return output
  end
  
  def parse_modulefiles_for_dependency_declarations(tree_to_build,module_root)
    Dir.foreach(module_root) do |module_dir|
      abs_dir = module_root + File::SEPARATOR + module_dir
      if module_dir != '..' && module_dir != '.' && module_dir != nil
        mfile = abs_dir + File::SEPARATOR + 'Modulefile'
        if File.exists?(mfile)
#          puts "\n\nmodulefile "+module_dir             
          #          modulename = nil
          dependencies = Set.new
          File.open(mfile) do |file|
            file.each_line() do |line|  
              trimmed_line = line.strip  
#              puts "line:"+trimmed_line
              #            match_name= Regexp.new(/^name\s['"][0-9a-zA-Z_\-:.,\s]+['"]/).match(trimmed_line)
              match_dependency= Regexp.new(/^dependency\s*['"][0-9a-zA-Z_\/-:.,\s]+['"]/).match(trimmed_line)            
              #            if match_name
              #              modulename = match_name[0].gsub('"', '').gsub("'", '').gsub('name', '').strip
              #              split = modulename.split('/')
              #              if split.size > 1
              #                modulename = split[1]
              #              end
              #            end
              if match_dependency
#                puts "match: "+match_dependency[0]
                dependency_name = match_dependency[0].gsub('"', '').gsub("'", '').gsub('dependency', '').strip
                split = dependency_name.split('/')
                if split.size > 1
                  dependency_name = split[1]
                end
#                puts "adding: "+dependency_name
                dependencies.add(dependency_name)
              end
            end   
          
            #          if (modulename != nil && modulename != '' && modulename == module_dir && dependencies.size > 0)
            if (dependencies.size > 0)
              if tree_to_build[module_dir] == nil
                tree_to_build[module_dir] = Item.new(Item::MODULE, :plain_name, module_dir)
#                puts "adding module to tree: "+module_dir
              end
              dependencies.each do |dependency|
                #puts "adding dependency :"+dependency+" to module: "+module_dir
                tree_to_build[module_dir][dependency] = Item.new(Item::MODULE, :plain_name, dependency)
              end            
            end
          end
        end
      end
    end
    
    return tree_to_build
  end
  
  private
  
  def build_module_tree(path,tree_to_build)
    # MODULE_ROOT/module/manifests/*
    module_root = path
    if !(path =~/modules$/)      
      module_root += File::SEPARATOR + DEFAULT_MODULES_DIR
    end
    puts "module root: "+module_root
    ## get a list of all files of each module
    Dir.foreach(module_root) do |module_dir|
      abs_dir = module_root + File::SEPARATOR + module_dir
      if module_dir != '..' && module_dir != '.' && module_dir != nil
        include_all_manifests_in_dir_recursively(abs_dir,module_dir,@module_files)      
        parent_item = Item.new(Item::MODULE,:plain_name,module_dir)
        
        #### scan for module functions #### start
        functions_dir = abs_dir + File::SEPARATOR + 'lib' + File::SEPARATOR +
          'puppet' + File::SEPARATOR + 'parser' + File::SEPARATOR + 'functions'
        if File.exist?(functions_dir) && File.directory?(functions_dir) 
          module_function_files = Hash.new
          module_function_files = include_all_functions_in_dir_recursively(functions_dir,module_dir,module_function_files)
          parent_item = detect_functions(module_function_files,parent_item)
        end
        #### scan for module functions #### end
        
        tree_to_build[module_dir] = parent_item 
        puts "added module dir: " + module_dir + " id "+parent_item.object_id.to_s
      end
    end
    
    #    puts "module files start"
    #    @module_files.each { |key,val|   puts key + " ............. referred by " + val}
    #    puts "module files end\n"
    
    ## parse each file for dependencies to other classes and modules
    tree_to_build = build_dependency_tree(@module_files,tree_to_build,true,true)
    ## remove children/dependencies which are actually contained in the module
    tree_to_build.each do |key,module_item| 
      cloned_items = module_item.clone
      cloned_items.each do |key,child|
       
        child_ref = child.name
        if (child.name[0,2] == "::")
          child_ref = child.name[2,child.name.length]
        end        
        if child_ref.eql?(module_item.name)
          module_item.delete(child.name)
        end
        if module_item.contains[child_ref]
          module_item.delete(child.name)
        end                  
      end
    end
    
    ## generate item_is_part_of map (saves traversals in next steps)
    tree_to_build.each_value do |module_item| 
      module_item.contains.each_value do |item|
        @item_is_part_of[item.map_id] = module_item
        #puts "added "+item.map_id + " to partOf map"
      end
    end
        
    ## translate class/define/include dependencies to module dependencies
    #    tree_to_build.each_value do |module_item| 
    #      detail_dependencies = module_item.clone
    #      module_item.clear
    #      detail_dependencies.each_value do |detail_dependency|  
    #        puts "searching : "+detail_dependency.map_id
    #        dependency = @item_is_part_of[detail_dependency.map_id]
    #        if (dependency)
    #          module_item[dependency.name] = dependency
    #        else 
    #          if (!@unresolved_detail_dependencies[module_item.name])
    #            @unresolved_detail_dependencies[module_item.name] = Hash.new
    #          end
    #          (@unresolved_detail_dependencies[module_item.name])[detail_dependency.map_id] = detail_dependency
    #        end
    #      end
    #    end
    
    tree_to_build, @unresolved_detail_module_dependencies = translate_detail_dependencies_to_module_dependencies(tree_to_build,tree_to_build,@item_is_part_of,@unresolved_detail_module_dependencies)
    
    ## parse librarian-puppet Modulefile if available and add dependencies listed in it
    tree_to_build = parse_modulefiles_for_dependency_declarations(tree_to_build,module_root)
    
    return tree_to_build, @item_is_part_of
  end
  
  def translate_detail_dependencies_to_module_dependencies(base_tree,tree_to_build,map,unresolved_detail_dependencies)
    #    puts "TRANSLATION DICTIONARY:"
    #    map.each do |key,val|
    #      puts key.to_s+" ->"+val.name.to_s+" ("+val.item_type.to_s+")"
    #    end
    #    puts "-TRANSLATION DICTIONARY"
    base_tree.each do |key,module_item| 
      #      puts "ORIGINAL : "+module_item.to_s
      translated_item = module_item.clone
      #      puts "TRANSLATED : "+translated_item.to_s
      translated_item.clear
      #      detail_dependencies = module_item.clone
      #      module_item.clear
      module_item.each_value do |detail_dependency|  
        dependency = map[detail_dependency.map_id]
        #        puts "searching : "+detail_dependency.map_id+"... maps to "+dependency.to_s
        
        if (dependency)
          translated_item[dependency.name] = dependency
        else 
          if (!unresolved_detail_dependencies[module_item.name])
            unresolved_detail_dependencies[module_item.name] = Hash.new
          end
          (unresolved_detail_dependencies[module_item.name])[detail_dependency.map_id] = detail_dependency
        end
      end
      tree_to_build[key] = translated_item
    end
    
    return tree_to_build, unresolved_detail_dependencies
  end
  
  def detect_functions(files_to_parse, module_item)
    # ref_as_parent requires, that tree is already filled with parent_items
    files_to_parse.each do |path_to_file,referee| 
      #puts "Parsing RB File : "+path_to_file
      File.open(path_to_file) do |file|
        file.each_line() do |line|  
          trimmed_line = line.strip        
         
          if trimmed_line =~ /newfunction\(:/
            # function declaration found            
            function_name = trimmed_line.split('newfunction(:')[1]
            #puts "RB found: "+trimmed_line+" ... function_namePart "+(function_name ? function_name : "")
            function_name = function_name.split(')')[0].split(',')[0]
            #puts referee+" function found "+function_name
            module_item.contains[function_name] = Item.new(Item::FUNCTION,:plain_name,function_name)
          end
        end
      end
    end
    
    return module_item
  end
  
  def build_dependency_tree(files_to_parse, tree_to_build, ref_as_parent=false, depth_zero_is_part_of_parent=false)
    # ref_as_parent requires, that tree is already filled with parent_items
    files_to_parse.each do |path_to_file,referee| 
      #puts "Parsing ... "+path_to_file
      File.open(path_to_file) do |file|
        depth_counter = 0           
        #        current_parent_item = initialCurrentParentItem
        current_parent_item = nil
        if (ref_as_parent) 
          current_parent_item = tree_to_build[referee]
        end
        #        puts "current parent id "+current_parent_item.object_id.to_s
        next_line_name_scan_item = nil
        file.each_line() do |line|  
          trimmed_line = line.strip        
         
          if trimmed_line =~ /^#/
            # puts "code comment : "+ trimmed_line
          else
            if next_line_name_scan_item
              item_name = extract_item_name(trimmed_line,depth_counter,next_line_name_scan_item[0])
              if (item_name)
                if next_line_name_scan_item[0] == Item::NODE
                  full_item_name = path_to_file
                else 
                  full_item_name = item_name
                end
                item = Item.new(next_line_name_scan_item[0],next_line_name_scan_item[1],full_item_name)
                if next_line_name_scan_item[0] == Item::NODE
                  item.short_names.add(item_name)
                end
                add_to_tree_structure(item,current_parent_item,tree_to_build)                  
                next_line_name_scan_item = nil
              end
            else
              ## detection of dependencies
              current_parent_item,next_line_name_scan_item = parsing_line(path_to_file,tree_to_build,current_parent_item,ref_as_parent,depth_zero_is_part_of_parent,depth_counter,trimmed_line)
            end
            ## track depth changes
            if trimmed_line =~/\{/
              depth_counter += 1
            end
            if trimmed_line =~/\}/
              depth_counter -= 1
              if depth_counter == 0 && !ref_as_parent
                parent_item = nil
              end
            end
          
          end
          #### parsing file completed
        end
        #### parsing files completed
        
        ## duplicate nodes if their name is actually a list of several node selectors
        #        if (current_parent_item != nil && current_parent_item.item_type == Item::NODE)
        #          node_names = current_parent_item.name.split(',')
        #          if node_names.size > 1
        #            current_parent_item.name = node_names[0].strip
        #            for i in 0...node_names.length
        #              clonedItem = current_parent_item.clone
        #              clonedItem.name = node_names[i].strip
        #              add_to_tree_structure(clonedItem,nil,tree_to_build)
        #               current_parent_item.short_names.add(node_names[i])
        #            end
        #          end
        #        end
      end      
    end
    return tree_to_build
  end
  
  def parsing_line(path_to_file,tree_to_build,current_parent_item,ref_as_parent,depth_zero_is_part_of_parent,depth_counter,trimmed_line)
    if trimmed_line =~ /^node\s.*\{.*/ 
      ## parse node name or node name regexp
      if ((depth_counter==0 && depth_zero_is_part_of_parent) || ref_as_parent)
        raise(NotYetSupportedException,"nodes can not be part of modules")
      end
      match_reg_exp_rule = Regexp.new(/\/.*\//).match(trimmed_line) 
      match_normal_rule = Regexp.new(/["'].*["']/).match(trimmed_line) 
      if match_reg_exp_rule
        node_name= match_reg_exp_rule[0]
        node_name_type = :regexp_name
      elsif match_normal_rule
        node_name= match_normal_rule[0].gsub('"','').gsub("'","")
        node_name_type = :plain_name
      end

      current_parent_item = Item.new(Item::NODE,node_name_type,path_to_file)
      node_names = node_name.split(',')
      for i in 0...node_names.length
        current_parent_item.short_names.add(node_names[i].strip)
      end
      
      tree_to_build[path_to_file] = current_parent_item                

    elsif trimmed_line =~ /^class.*[({]/
      # can be either ( or { e.g. as in modules/apache/init.pp test case
      # ( start of params list ; { start of class body
      node_name_type = :plain_name                                     
      item_name = extract_item_name(trimmed_line,depth_counter,Item::CLASS)  
      #item_nameP = item_name == nil ? "noname" : item_name
      #puts "class detected >> "+item_nameP + " depth : "+depth_counter.to_s
      if item_name                  
        item = Item.new(Item::CLASS,node_name_type,item_name)
        if (depth_counter==0 && depth_zero_is_part_of_parent && ref_as_parent) 
          #puts "ref as parent: "+parent_item.name
          current_parent_item.contains[item_name]=item
        else      
          #puts "add to tree"
          add_to_tree_structure(item,current_parent_item,tree_to_build)                
        end
      else 
        #if node_name = nil or '' then 
        #                    puts "next_line_name_scan_item:class"
        next_line_name_scan_item = [Item::CLASS,node_name_type]
      end             
    elsif trimmed_line =~ /^define.*[({]/
      node_name_type = :plain_name                                     

      item_name = extract_item_name(trimmed_line,depth_counter,Item::DEFINE)                 
      if item_name                  
        item = Item.new(Item::DEFINE,node_name_type,item_name)
        if (depth_counter==0 && depth_zero_is_part_of_parent && ref_as_parent) 
          current_parent_item.contains[item_name]=item
        else                    
          add_to_tree_structure(item,current_parent_item,tree_to_build)                
        end
      else 
        #if node_name = nil or '' then 
        #                    puts "next_line_name_scan_item:define"
        next_line_name_scan_item = [Item::DEFINE,node_name_type]
      end  
    elsif trimmed_line =~ /^include [0-9a-zA-Z_\-:.,\s]+/ || trimmed_line =~ /^require [0-9a-zA-Z_\-:.,\s]+/
      # list of one or several classes the parent depends on             
      removed_include_statement = trimmed_line.gsub(/^include/,'').gsub(/^require/,'')
      #                puts "include >> "+removed_include_statement
      class_name_array = removed_include_statement.split(',')
      class_name_array.each do |class_name|
        extracted = class_name.gsub('"','').gsub("'","").strip
        item = Item.new(Item::CLASS,:plain_name,extracted)
        if (depth_counter==0 && depth_zero_is_part_of_parent) 
          current_parent_item.contains[item_name]=item
        else                    
          add_to_tree_structure(item,current_parent_item,tree_to_build)                
        end
      end
    elsif trimmed_line =~ /^[0-9a-zA-Z_\-.,]+::[0-9a-zA-Z_\-.,]+\s*\{/
      # reference to define, e.g. : wget::fetch {              
      define_name = Regexp.new(/^[0-9a-zA-Z_\-.,]+::[0-9a-zA-Z_\-.,]+/).match(trimmed_line)[0]
      item = Item.new(Item::DEFINE, :plain_name, define_name)
      #puts "found a define usage: "+trimmed_line +" >> "+define_name
      add_to_tree_structure(item,current_parent_item,tree_to_build)
    elsif trimmed_line =~ /^[0-9a-zA-Z_\-.,]+\(/
      # reference to a function, e.g. :              
      define_name = Regexp.new(/^[0-9a-zA-Z_\-.,]+/).match(trimmed_line)[0]
      item = Item.new(Item::FUNCTION, :plain_name, define_name)
      #puts "found a function usage: "+trimmed_line +" >> "+define_name
      add_to_tree_structure(item,current_parent_item,tree_to_build)
    end
    
    return current_parent_item, next_line_name_scan_item
  end
  
  def extract_item_name(line,depth_counter,item_type)
    match_rule = nil
    if (depth_counter == 0)
      cleaned_line = line.gsub(item_type, '')
      #      puts "cleaned line: "+cleaned_line
      match_rule = Regexp.new(/[0-9a-zA-Z_\-:.]+/).match(cleaned_line) 
      #      puts "match: "+match_rule[0]
    else
      match_rule = Regexp.new(/["'][0-9a-zA-Z_\-:.]+.*[:]*.*["'].*:/).match(line) 
      #         puts "matchi: "+match_rule[0]
    end
    item_name = nil
    if match_rule
      item_name= match_rule[0].gsub('"','').gsub("'","").gsub(/:$/,"").strip
    end 
             
    return item_name
  end
  
  def add_to_tree_structure(item,parent,tree)
    if parent
      parent[item.name]=item
    else
      tree[item.name] = item
    end
    return nil
  end
  
  def handle_import_statements(line,path,filename,file_map)
    if line =~ /^import/
      # reference to more pp files found
      subfile = line.gsub(/^import\s*['"]/,'').gsub!(/['"]$/,'')
      if subfile =~ /\*/   
        if subfile[-1,1] == '*' 
          puts "contains wildcard import reference " + subfile[-1,1]
          # that means subfile is another dir
          dir = subfile[0..-2]
          abs_dir = path + File::SEPARATOR + dir
          if File.directory?(abs_dir) 
            # Dir.entries(abs_dir) do |entry|
            include_all_manifests_in_dir_recursively(abs_dir,filename,file_map)
              
          else 
            raise(NotYetSupportedException,"wildcard reference just supported at the end of import statements for selection of all directory contents")
          end
               
        else
          raise(NotYetSupportedException,"wildcard reference just supported at the end of import statements")
        end
            
      else          
        # explicit file reference
        file_map[path+File::SEPARATOR+subfile] = path + File::SEPARATOR + filename
      end
    end
    
    return file_map
  end
  
  def include_all_manifests_in_dir_recursively(dir,referee,file_map)
    return include_all_files_in_dir_recursively('.pp', dir,referee,file_map)
  end
  
  def include_all_functions_in_dir_recursively(dir,referee,file_map)
    return include_all_files_in_dir_recursively('.rb', dir,referee,file_map)
  end
  
  def include_all_files_in_dir_recursively(file_suffix, dir,referee,file_map)
    Dir.foreach(dir) do |entry|  
      filesep = dir[-1,1] == File::SEPARATOR ? '' : File::SEPARATOR
      entry_path = dir + filesep + entry
      if File.directory?(entry_path)
        # recursion  
        if entry != '..' && entry != '.' && entry != nil
          include_all_manifests_in_dir_recursively(entry_path,referee,file_map)
        end
      elsif entry[-file_suffix.size,file_suffix.size] == file_suffix
        file_map[entry_path] = referee
      end
    end
    
    return file_map
  end
end

class NotYetSupportedException < StandardError
  
end

class ParsingException < StandardError
  
end