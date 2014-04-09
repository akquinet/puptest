# To change this template, choose Tools | Templates
# and open the template in the editor.

require 'json'

class ChangeSet
  attr_writer :nodes, :modules, :classes, :previous_promoted_commit, :promoted_commit, :promoted_ref, :dev_ref
  attr_reader :nodes, :modules, :classes, :repo_dir, :previous_promoted_commit, :promoted_commit, :promoted_ref, :dev_ref
  def initialize(repo_dir)
    @modules = Hash.new
    #    nodes hashkey is the absolute file path to ease test running processes 
    #    (file path does not have to be detected again)
    @nodes = Hash.new
    @classes = Hash.new
    @repo_dir = repo_dir
  end
  
  def to_s
    output = ""
    output+="nodes: \n"
    @nodes.each { |key,component| output +="-- "+component.name+" ("+component.item_type+")"+"\n"}       
    return output
  end
  
  NODES = 'nodes'
  MODULES = 'modules'
  CLASSES = 'classes'
  PREVIOUS_PROMOTED_COMMIT = 'previous_promoted_commit'
  PROMOTED_COMMIT = 'promoted_commit'
  PROMOTED_REF = 'promoted_ref'
  DEV_REF = 'dev_ref'
  JSON_CLASS = 'json_class'
  
  
  def to_json(*a)
    { JSON_CLASS => self.class.name,
      NODES => @nodes,
      MODULES => @modules,
      CLASSES => @classes,
      PREVIOUS_PROMOTED_COMMIT => @previous_promoted_commit, 
      PROMOTED_COMMIT => @promoted_commit, 
      PROMOTED_REF => @promoted_ref, 
      DEV_REF => @dev_ref
    }.to_json(*a)
  end
  
  def self.json_create(o)
    new(*o['data'])
  end
  
  def initialize_json(json)
    @dev_ref=json[DEV_REF]
    @promoted_ref=json[PROMOTED_REF]
    @promoted_commit=json[PROMOTED_COMMIT]
    @previous_promoted_commit=json[PREVIOUS_PROMOTED_COMMIT]
    
#    nodes modules and classes are not required so far, while restoring a changes.json 
#    json[NODES]
#    json[MODULES]
#    json[CLASSES]
    return nil
  end
end
