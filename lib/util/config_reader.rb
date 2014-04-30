# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'inifile'

class ConfigReader
  attr_reader :opts, :puppetmaster_opts
  
  def initialize(inifile_path, ppinifile_path)
    inifile = IniFile.load(inifile_path)
    @opts = Configuration.new(inifile['default'])
    ppinifile = IniFile.load(ppinifile_path)
    @puppetmaster_opts = Configuration.new(ppinifile['master'])
  end
end

class Configuration < Hash
  def initialize(hash)
    hash.each do |key,val|
      self[key] = val
      self[key.to_sym] = val
    end
  end
end
