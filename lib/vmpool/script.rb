# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

class Script
  
  # name is a String, commands is an array of single commands, results is an array of results corresponding to the commands array
  attr_reader :name, :commands, :results, :statuscodes
  
  def initialize(name, commands)
    @name = name
    @commands = commands
    @results = Array.new
    @statuscodes = Array.new
  end
  
  def add_result_by_command(command, result, statuscode)
    id = nil
    counter = 0
    @commands.each do |existing|
      if (existing == command)
        id = counter
        break
      else
        counter += 1
      end
    end
    if id == nil
      raise(StandardError, 'command '+command+' not found in array of commands.')
    end
    
    return add_result_by_command_id(id, result, statuscode)
  end
  
  def add_result_by_command_id(command_id, result, statuscode)
    results[command_id] = result
    statuscodes[command_id] = statuscode
    
    return true
  end
end
