# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

class ScriptRunner
  ## scripts is an array of script objects
  attr_reader :scripts, :exec_counter
  
  def initialize(scripts,pool_manager)
    @scripts = scripts
    @exec_counter = -1
    @pool_manager = pool_manager
  end
  
  def run
    threads = []
    @pool_manager.pool.size.times do
      threads << run_next_script
    end
    threads.each do |thread| 
      if (thread != nil) 
        thread.join 
      end
    end
    
    return @scripts
  end
  
  private
  
  def get_next_id
    next_id = nil
    mutex = Mutex.new
    mutex.synchronize do
      if (@exec_counter < @scripts.size-1)
        @exec_counter += 1
        next_id = @exec_counter
      end  
    end
    
    return next_id
  end
  
  def run_next_script(selected_vm=nil)
    id = get_next_id
    if (id != nil)
      
      thread = Thread.new(id) do |id|
        script = @scripts[id]
        if (selected_vm == nil)
          selected_vm = @pool_manager.occupy
        end      
        script.commands.each do |command|
          result, statuscode = @pool_manager.run_command_in_pool_vm(command, selected_vm)
          script.add_result_by_command(command, result, statuscode)
        end
        pool, selected_vm = @pool_manager.free(selected_vm)
        inner_thread = run_next_script(selected_vm)
        if (inner_thread != nil)
          inner_thread.join
        end        
      end
    end      
    return thread
  end
end
