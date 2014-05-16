# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.
require 'analysis/change_detector'
require 'util/config_reader'
require 'util/change_set'
require 'util/environment_manager'
require 'vmpool/pool_manager'
require 'vmpool/script'
require 'vmpool/script_runner'

#require 'util/command_module'

class Puptest
  include CommandModule
  
  def initialize
    
  end
  
  DEFAULT_CONFIG_FILE = File.join('/etc','puptest','puptest.conf')
  DEFAULT_PP_CONFIG_FILE = File.join('/etc','puppet','puppet.conf')
  
  def run(config_file, pp_config_file)
    ## 1: load configuration    
    if config_file == nil
      config_file = DEFAULT_CONFIG_FILE
    end
    
    if pp_config_file == nil
      pp_config_file = DEFAULT_PP_CONFIG_FILE
    end
    config_reader = ConfigReader.new(config_file,pp_config_file)    
    
    if config_reader.opts[:repo_url] == nil
      raise(StandardError,'missing repo_url=[YOUR URL] in configuration file '+config_file.to_s)
    end
    config_reader.opts[:puptest_env] = 'puptest'
    ## 2: detect changes
    change_detector = ChangeDetector.new()
    change_set = change_detector.detect_changes(config_reader.opts[:repo_url], config_reader.opts)
    
    if change_set.nodes.size <= 0
      puts "no changes detected, puptest will do nothing."
      return nil
    end
    ## 3+4: prepare test env in puppetmaster (clone repo into $confdir/environments/puptest)
    ## and initialize modules in puptest env
    environment_manager = EnvironmentManager.new(pp_config_file, config_reader.opts[:puptest_env], config_reader.opts[:repo_url])
    environment_manager.ensure_puptest_env_exists()
    
    ## 4-result: server is restarted by environment manager if env was successfully initialized
#    run_command('cp -rfL /etc/puppet/ /tmp/before_pool_start')
    ## 5: compile a small test script for each change
    scripts = compile_test_scripts(change_set.nodes,config_reader.opts)
    
    ## 6: delete certs of tests nodes from master
    certnames = Set.new
    scripts.each do |script|
      certnames.add(script.name)
    end
    environment_manager.cleanup_puppetmaster_certs(certnames,pp_config_file)
    
    ## 7: start vm pool
    pool_manager = PoolManager.new(config_reader.opts)
    pool_manager.start_pool()
        
    ## 8: run each script in a fresh vm
    script_runner = ScriptRunner.new(scripts,pool_manager)
    scripts = script_runner.run()

    ## 9: stop vm pool
    stop_result = pool_manager.stop_pool(config_reader.opts)
    
    ## 10: check results/parse output for errors, problems and statuscodes != 0
    overall_statuscode, failed_scripts = check_results(scripts)
    
    if overall_statuscode != 0
      puts "puptest found problems while executing the following scripts/node tests: "
      puts ""
      failed_scripts.each do |key, failed_script|
        puts failed_script.name+" stacktrace: "
        failed_script.results.each do |result|
          puts ""
          puts result.to_s
          puts "----------------"
        end
      end
    else
    ## 11: if no errors have been found: promote changes
    change_detector.scm_change_inspector.promote_changes(change_detector.scm_repo, change_set, config_reader.opts)
    end
    
    FileUtils.rm_rf(change_detector.scm_repo.dir.to_s)
    
    return overall_statuscode, failed_scripts, scripts
  end
  
  private 
  
  def check_results(scripts)
    overall_statuscode = 0
    failed_scripts = Hash.new
    problem_indicators = ['ERROR','error','Error','Exception']
    scripts.each do |script|
      script.statuscodes.each do |statuscode|
        puts "script "+script.name+" statuscode "+statuscode.to_s
        if statuscode != 0 && statuscode != 2
          overall_statuscode = 1
          failed_scripts[script.name] = script
        end
      end
      script.results.each do |result|
        puts "script "+script.name+" result "+result
        problem_indicators.each do |problem_indicator|
          if result =~ /#{problem_indicator}/
            overall_statuscode = 1
            failed_scripts[script.name] = script
          end
        end
      end
    end
    
    return overall_statuscode,failed_scripts
  end
  
  def compile_test_scripts(changed_nodes,opts)
    scripts = Array.new
    changed_nodes.each do |node_file, changed_node|
      commands = Array.new
      hostname=changed_node.name
      if changed_node.short_names.size > 0
        hostname = changed_node.short_names.to_a[0].to_s
      end
      if hostname =~ /,/
        hostname = hostname.split(',')[0].strip()
      end
      server = opts[:puppetmaster_server]
      commands[0] = 'hostname '+hostname
      commands[1] = 'puppet agent --server='+server+' --environment='+opts[:puptest_env]+' --verbose --onetime --no-daemonize --detailed-exitcodes'      
      scripts << Script.new(hostname, commands)
    end
    return scripts
  end
end
