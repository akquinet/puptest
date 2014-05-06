# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

module CommandModule
  def run_command(cmd, &block)
    puts "executing cmd: "+cmd
    if block_given?
      out = IO.popen(cmd, &block)
      out.readlines
    else
      out = `#{cmd}`.chomp
    end
      
    return out, $?.exitstatus
  end
  
  def run_command_in_dir(dir, cmd, &block)
    puts "executing cmd: "+cmd+" in directory: "+dir
    out = nil
    exitstatus = 1
    Dir.chdir(dir) do
        puts run_command('pwd', &block)[0]
      out, exitstatus = run_command(cmd, &block)
    end
    return out, exitstatus
  end
end
