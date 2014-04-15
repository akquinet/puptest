# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'set'

class PoolManager
  attr_reader :opts, :pool
  
  PUPTEST_INIT_STATE = 'puptest_init_state'
  
  def initialize(opts = {})
    opts = ensure_all_options_are_initialized(opts)
    @opts = opts
    
    @pool = start_pool
  end
  
  def ensure_all_options_are_initialized(opts={})
    opts[:vm_host_url] = 'localhost' if opts[:vm_host_url] == nil
    opts[:vm_name_prefix] = 'puptest_' if opts[:vm_name_prefix] == nil
    opts[:base_vm] = 'puptest_base' if opts[:base_vm] == nil
    opts[:pool_size] = 3 if opts[:pool_size] == nil
    opts[:vm_engine] = 'kvm' if opts[:vm_engine] == nil
    opts[:vm_host_login] = 'root' if opts[:vm_engine] == nil
    opts[:vm_level] = 'system' if opts[:vm_level] == nil
    opts[:vol_pool_path] = '/tmp' if opts[:vol_pool_path] == nil
    opts[:vol_file_suffix] = '.qcow2' if opts[:vol_file_suffix] == nil
    opts[:init_snapshot_name] = PUPTEST_INIT_STATE if opts[:init_snapshot_name] == nil
    # note that key-based ssh authentication is required for security reasons  
    return opts
  end
  
  def delete_pool(opts=self.opts)
    all_pool_vms = get_all_pool_vms(opts)
    all_pool_vms.each do |pool_vm|
      delete_vm(opts,pool_vm)
    end
    
    @pool = nil
    return all_pool_vms
  end
  
   def stop_pool(opts=self.opts)    
    result = stop_vms(opts,get_all_pool_vms(opts))
    @pool = Set.new
    return result
  end
  
  def restart_pool(opts=self.opts)
    @pool = start_pool(opts)
  end
  
  def start_pool(opts=self.opts)
    virsh_connection = get_virsh_connection_string(opts)
    
    ensure_base_vm_exists(opts)
    stop_vms(opts,get_running_pool_vms(opts))
        
    all_pool_vms = get_all_pool_vms(opts)
    all_pool_vms_duplicate = all_pool_vms.clone()
    
    ## check if there is a puptest init snapshot, 
    ## if so reset each pool vm to this init snapshot state otherwise delete the vm
    ## TODO refactor using blocks
    all_pool_vms_duplicate.each do |pool_vm|
      info = run_command(virsh_connection+' snapshot-dumpxml '+pool_vm+' '+opts[:init_snapshot_name])
      if info[1] == 0
        revert = run_command(virsh_connection+' snapshot-revert '+pool_vm+' '+opts[:init_snapshot_name])
        if revert[1] != 0
          # TODO delete vm physically
          delete_vm(opts,pool_vm)
          all_pool_vms.delete(pool_vm)
        end
      else
        # TODO delete vm pysically
        delete_vm(opts,pool_vm)
        all_pool_vms.delete(pool_vm)
      end
    end
    
    ## adjust pool to defined pool size
    break_condition = all_pool_vms.size - opts[:pool_size]
    
    if break_condition != 0
      pool_change_type = break_condition > 0 ? :reduce : :extend
      break_condition = -break_condition if break_condition < 0
      if (pool_change_type == :reduce)
        count = 0
        all_pool_vms_duplicate = all_pool_vms.clone()
        all_pool_vms_duplicate.each do |pool_vm|        
          # TODO delete vm pysically
          delete_vm(opts,pool_vm)
          all_pool_vms.delete(pool_vm)        
          count += 1;
          break if (count >= break_condition)
        end
      elsif (pool_change_type == :extend)
        (1..break_condition).each do
          vm_name = clone_base_vm(opts)
          ## create snapshot in VM
          create_vm_snapshot(opts,vm_name)
          all_pool_vms.add(vm_name)
        end
      end
    end
    
    ## ensure all pool vms are running    
    ensure_vms_are_running(opts, all_pool_vms)
    
    return all_pool_vms
  end
  
  def get_virsh_connection_string(opts)
    opts = ensure_all_options_are_initialized(opts)
    return 'virsh -c qemu+ssh://'+opts[:vm_host_login]+'@'+
      opts[:vm_host_url]+'/'+opts[:vm_level]
  end
  
  def get_all_pool_vms(opts,only_running=false)
    opts = ensure_all_options_are_initialized(opts)
    virsh_connection = get_virsh_connection_string(opts)
    
    selector=' --all'
    if (only_running)
      selector=''
    end
    pool_list_all = run_command(virsh_connection+' list'+selector+' --name | grep '+opts[:vm_name_prefix])
    all_vms = array_to_set(pool_list_all[0].split(/\n/))
    all_vms.delete(opts[:base_vm])
    all_pool_vms = regexp_based_subset(all_vms,/^#{opts[:vm_name_prefix]}/)
    return all_pool_vms
  end
  
  def get_running_pool_vms(opts)
    return get_all_pool_vms(opts,true)
  end
  
  def ensure_base_vm_exists(opts)
    opts = ensure_all_options_are_initialized(opts)
    virsh_connection = get_virsh_connection_string(opts)
    # check if base vm exists
    base_vm_exists = run_command(virsh_connection+' dominfo '+opts[:base_vm])
    
    if base_vm_exists[1] != 0
      raise(PoolStartException,'Base VM '+opts[:base_vm]+' does not exist on host '+
          opts[:vm_host_url]+'/'+opts[:vm_level]+'. Please check your configuration.')
    end
  end
  
  def delete_all_snapshots(opts,vm_name)
    opts = ensure_all_options_are_initialized(opts)
    virsh_connection = get_virsh_connection_string(opts)
    list_snapshots = run_command(virsh_connection+' snapshot-list '+vm_name)
    if list_snapshots[1] != 0
          raise(ConnectionOrExecuteException,'Snapshots could not be listed for vm: '+vm_name)
    end
    snapshot_lines = array_to_set(list_snapshots[0].split(/\n/))
    snapshot_lines.each do |line|   
      trimmed_line = line.strip      
      match = Regexp.new(/^#{opts[:vm_name_prefix]}\S*/).match(trimmed_line)      
      if match        
        del_snapshot = run_command(virsh_connection+' snapshot-delete --children '+vm_name+' '+match[0])
        if del_snapshot[1] != 0
          raise(ConnectionOrExecuteException,'vm snapshot could not be deleted.')
        end
      end
    end
        
    
    
    return list_snapshots[0]
  end
  
  def create_vm_snapshot(opts,vm_name)
    opts = ensure_all_options_are_initialized(opts)
    virsh_connection = get_virsh_connection_string(opts)
    create_snapshot = run_command(virsh_connection+' snapshot-create-as '+vm_name+' '+opts[:init_snapshot_name])
    if create_snapshot[1] != 0
      raise(ConnectionOrExecuteException,'vm snapshot could not be created.')
    end
    
    return create_snapshot[0]
  end
  
  def ensure_vms_are_running(opts,vms)
    opts = ensure_all_options_are_initialized(opts)
    virsh_connection = get_virsh_connection_string(opts)
    running_vms_list = run_command(virsh_connection+' list --name --state-running')    
    paused_vms_list = run_command(virsh_connection+' list --name --state-paused')    
    if running_vms_list[1] != 0 || paused_vms_list[1] != 0
      raise(ConnectionOrExecuteException,'vm list could not be executed properly.')
    end
    
    running_vms = array_to_set(running_vms_list[0].split(/\n/))
    paused_vms = array_to_set(paused_vms_list[0].split(/\n/))
    vms.each do |vm|
      if (!running_vms.include?(vm))
        ## try to start i.e. resume vm
        start_vm = nil
        if (paused_vms.include?(vm))
          start_vm = run_command(virsh_connection+' resume '+vm)
        else
          start_vm = run_command(virsh_connection+' start '+vm)
        end
        if start_vm[1] != 0
          raise(PoolStartException,'VM '+vm+' could not be started or resumed.')
        end
      end
    end
    
    return vms
  end
  
  def delete_vm(opts,vm_name)
    ## remove all snapshots of vm
    delete_all_snapshots(opts,vm_name)
    ## then delete vm
    return deactivate_vm(opts,vm_name,'undefine --remove-all-storage')
  end
  
  def stop_vms(opts,vms)
    vms.each do |vm|
      # shutdown command only works after full boot, so we use destroy 
      # to be sure it was shutdown
      deactivate_vm(opts,vm,'destroy')
    end
    
    return vms
  end
  
  def deactivate_vm(opts,vm_name,cmd='shutdown')
    opts = ensure_all_options_are_initialized(opts)
    virsh_connection = get_virsh_connection_string(opts)
    
    delete = run_command(virsh_connection+' '+cmd+' '+vm_name)
    if delete[1] != 0
      raise(DeleteException,'VM '+vm_name+' command failed:'+cmd)
    end
    puts delete[0]
    
    return vm_name
  end
  
  def clone_base_vm(opts)    
    opts = ensure_all_options_are_initialized(opts)
    virtclone_connection='virt-clone --connect qemu+ssh://'+opts[:vm_host_login]+'@'+
      opts[:vm_host_url]+'/'+opts[:vm_level]+' --original '+opts[:base_vm]
    identifier = Time.now.strftime('%s_%12N')
    vm_name = opts[:vm_name_prefix] + identifier
    clone = run_command(virtclone_connection+
        ' --name '+vm_name+
        ' --file '+opts[:vol_pool_path]+File::SEPARATOR+vm_name+opts[:vol_file_suffix])
    if clone[1] != 0
      raise(CloneException,"Clone "+vm_name+" of base VM "+opts[:base_vm]+" could not be created.")
    end
    puts "base vm clone created: "+vm_name
    
    return vm_name
  end
  
  def regexp_based_subset(set, regexp)
    subset = Set.new()
    set.each do |item|
      if item =~ regexp
        subset.add(item)
      end
    end
    
    return subset
  end
  
  def array_to_set(array)
    set = Set.new()
    array.each do |item|
      set.add(item)
    end
    
    return set
  end
  
  def run_command(cmd, &block)
    puts "executing cmd: "+cmd
    if block_given?
      out = IO.popen(cmd, &block)
      out.readlines
    else
      out = `#{cmd}`.chomp
    end
      
    return out, $?
  end
end

class PoolStartException < StandardError
  
end

class CloneException < StandardError
  
end

class DeleteException < StandardError
  
end

class ConnectionOrExecuteException < StandardError
  
end