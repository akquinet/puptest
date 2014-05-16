# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'inifile'
require 'util/git_repo_manager'
require 'util/command_module'
require 'util/config_reader'
require 'util/module_initializer'

class EnvironmentManager
  include CommandModule
  include GitRepoManager
  
  attr_reader :repo_url, :pp_conf_file, :puptest_env
  
  DEFAULT_PUPTEST_ENV_NAME='puptest'
  DEFAULT_PP_CONF_DIR=File.join('/etc','puppet')
  DEFAULT_PP_CONF_FILE=File.join('/etc','puppet','puppet.conf')
  
  def initialize(pp_conf_file=DEFAULT_PP_CONF_FILE,
      puptest_env=DEFAULT_PUPTEST_ENV_NAME, repo_url)
    @pp_conf_file = pp_conf_file
    ## load master properties
    @puptest_env = puptest_env
    @repo_url = repo_url
  end
  
  def cleanup_puppetmaster_certs(certnames,pp_conf_file=self.pp_conf_file)
    certnames.each do |certname|
      ssh_connection_string = 'ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no '+'root'+'@localhost'
      puppetmaster_opts = reload_ppm_conf(pp_conf_file)
      signed_certs_dir = File.join('/var','lib','puppet','ssl')
      if puppetmaster_opts[:ssldir] != nil && puppetmaster_opts[:ssldir].strip != ''
        signed_certs_dir = puppetmaster_opts[:ssldir]
      end
      signed_certs_dir = File.join(signed_certs_dir,'ca','signed')
      result, statuscode = run_command(ssh_connection_string+' rm -f '+signed_certs_dir+File::SEPARATOR+certname+'.pem')
      if statuscode != 0
        raise(StandardError,'certification management problem occured: cert '+certname+'\n'+result.to_s)        
      end
    end
    
    return restart_puppetmaster()
  end
  
  def ensure_puptest_env_exists(repo_url=self.repo_url,pp_conf_file=self.pp_conf_file,
    puptest_env = self.puptest_env)
    puppetmaster_opts, puptest_env_opts = reload_conf(pp_conf_file, puptest_env)
    fsep = File::SEPARATOR
    puptest_env_path=get_gen_env_path(puppetmaster_opts)+fsep+puptest_env    
    
    if (puptest_env_opts == nil || puptest_env_opts.size == 0)
      ## add environment declaration to puppet conf
      File.open(pp_conf_file,'a') do |io|  
        io.puts(get_configuration_section_header(puptest_env))
        io.puts(get_configuration_section_module_path(puptest_env_path))
        io.puts(get_configuration_section_manifest_path(puptest_env_path))
      end
    end
    ## delete environment files
    cleanup(puptest_env_path)
    ## add environment files: fresh repo clone
    FileUtils.mkdir_p(get_gen_env_path(puppetmaster_opts))
    repo = clone_repo(repo_url, get_gen_env_path(puppetmaster_opts), puptest_env)
    ## initialize modules    
    if !File.exists?(puptest_env_path) || !File.directory?(puptest_env_path)
      raise(StandardError,'environment setup failed.')
    end
    
    initialize_modules(puptest_env_path)
    ## restart puppetmaster
    return restart_puppetmaster()
  end
  
  def ensure_puptest_env_does_not_exist(pp_conf_file=self.pp_conf_file,
    puptest_env = self.puptest_env)
    puppetmaster_opts, puptest_env_opts = reload_conf(pp_conf_file, puptest_env)
    fsep = File::SEPARATOR
    puptest_env_path=get_gen_env_path(puppetmaster_opts)+fsep+puptest_env
    if (puptest_env_opts != nil)
      ## remove environment declaration from puppet conf
      lines = File.readlines(pp_conf_file)
      clean_conf = []
      lines.each do |line|
        match_header = Regexp.new(escape_regexp_chars(get_configuration_section_header(puptest_env))).match(line)
        match_module_path = Regexp.new(escape_regexp_chars(get_configuration_section_module_path(puptest_env_path))).match(line)
        match_manifest_path = Regexp.new(escape_regexp_chars(get_configuration_section_manifest_path(puptest_env_path))).match(line)
        if (match_header == nil && match_module_path == nil && match_manifest_path == nil)
          clean_conf.push(line)
        end
      end
      
      File.open(pp_conf_file, 'w+') {|f| f.write(clean_conf.join()) }
    end
    ## delete environment files
    cleanup(puptest_env_path)
    
    ## restart puppetmaster
    return restart_puppetmaster()
  end
  
  private 
  
  def escape_regexp_chars(string)
    chars_to_escape = ['[', ']','.','(',')']
    chars_to_escape.each do |char|  
      string = string.gsub(char,'\\'+char)
    end
    return string
  end
  
  def get_configuration_section_header(puptest_env = self.puptest_env)
    return '['+puptest_env+']'
  end
  
  def get_configuration_section_module_path(puptest_env_path)
    return 'modulepath = '+puptest_env_path+File::SEPARATOR+'modules'
  end
  
  def get_configuration_section_manifest_path(puptest_env_path)
    return 'manifest = '+puptest_env_path+File::SEPARATOR+'manifests/site.pp'
  end 
  
  def get_gen_env_path(puppetmaster_opts)
    confdir = DEFAULT_PP_CONF_DIR
    if puppetmaster_opts['confdir'] != nil
      confdir = puppetmaster_opts['confdir']
    end
    return confdir+File::SEPARATOR+'environments'
  end
  
  def initialize_modules(puptest_env_path)
    ## TODO use librarian class calls instead
#    puts "init modules in "+puptest_env_path
#    puts run_command_in_dir(puptest_env_path, 'which librarian-puppet')[0]
#    return run_command_in_dir(puptest_env_path, 'librarian-puppet install')

    return ModuleInitializer.new(puptest_env_path).install_modules()
  end
  
  def restart_puppetmaster
    ssh_connection_string = 'ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no '+'root'+'@localhost'
    return run_command(ssh_connection_string+' /etc/init.d/puppetmaster restart')
  end
  
  def reload_conf(pp_conf_file, puptest_env)
    pp_conf = IniFile.load(pp_conf_file)    
    puptest_env_opts = Configuration.new(pp_conf[puptest_env])
    
    return reload_ppm_conf(pp_conf_file), puptest_env_opts
  end
  
  def reload_ppm_conf(pp_conf_file)
    pp_conf = IniFile.load(pp_conf_file)
    puppetmaster_opts = Configuration.new(pp_conf['main'])
    
    puppetmaster_specific_opts = Configuration.new(pp_conf['master'])
    puppetmaster_opts = puppetmaster_opts.merge(puppetmaster_specific_opts)
    if (puppetmaster_opts[:confdir] == nil)
      puppetmaster_opts[:confdir] = File.join('etc','puppet')
    end
    
    return puppetmaster_opts
  end
  
end
