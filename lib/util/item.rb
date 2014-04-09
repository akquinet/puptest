# items have children on which they depend on terms of puppet resource relations.
# only items which are modules contain classes and define-resources.
#require 'rubytree'

class Item < Hash
  MODULE='module'
  NODE='node'  
  CLASS='class'
  DEFINE='define'
  FUNCTION='function'
  NONAME='noname'

  attr_reader :item_type, :name_type, :name, :contains, :short_names
  attr_writer :contains, :name, :short_names
    
  def initialize(item_type,name_type,name)
    if (!name)
      raise StandardError "item must have a name"
    end
    @name=name
    @item_type = item_type
    @name_type = name_type
    @contains = Hash.new
    @short_names = Set.new
  end
  
  def to_s
    output = ""
    shorties = ''
    @short_names.each { |short_name| shorties += ' '+short_name  }
    output+=@item_type+": "+@name+" (id: "+self.object_id.to_s+") ["+shorties+" ]\n"
    output+="-- contains: \n"
    @contains.each { |key,component| output +="-- "+component.name+" ("+component.item_type+")"+"\n"} 
    output+="---- depends on: \n"
    self.each { |key,child| output +="---- "+child.name+" ("+key+"; "+child.item_type+")"+"\n"}
    return output
  end
  
  def map_id
    output = ""
    output+=@item_type+": "+@name+" (name_type: "+@name_type.to_s+")"
    return output
  end
  
  NAME = 'name'
  ITEM_TYPE='item_type'
  NAME_TYPE='name_type'
  CONTAINS='contains'
  SHORT_NAMES='short_names'
  JSON_CLASS='json_class'  
  
  def to_json(*a)
    { JSON_CLASS => self.class.name,
      ITEM_TYPE => @item_type,
      NAME_TYPE => @name_type.to_s, 
      NAME => @name, 
      CONTAINS => @contains, 
      SHORT_NAMES => @short_names.to_a
    }.to_json(*a)
  end
  
  def self.json_create(o)
    new(*o['data'])
  end
end
