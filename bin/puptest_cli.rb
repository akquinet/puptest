#!/usr/bin/env ruby

lib = File.join(File.dirname(__FILE__),'..','lib')
$:.unshift(lib) unless $:.include?(lib)

require "rubygems" # ruby1.9 doesn't "require" it though
require "thor"
require 'puptest'

class PuptestCli < Thor

  desc "audit", "executes the puptest framework and promotes detected changes if all detected changes have been applied to a pool vm successfully"
  method_option :conf_file, :default => Puptest::DEFAULT_CONFIG_FILE, :type => :string , :aliases => '-t', :required => true
  method_option :pp_conf_file, :default => Puptest::DEFAULT_PP_CONFIG_FILE, :type => :string , :aliases => '-m', :required => true
  def audit
    cf = options[:conf_file] == nil ? Puptest::DEFAULT_CONFIG_FILE : options[:conf_file]
    pcf = options[:pp_conf_file] == nil ? Puptest::DEFAULT_PP_CONFIG_FILE : options[:pp_conf_file]
    puts "option values: \n-- conf file: "+cf+"\n-- puppetmaster conf file: "+pcf
    executor = get_executor()
    puts "executor: "+executor.to_s
    executor.run(cf,pcf)
  end
  
  private
  
  def get_executor
    return Puptest.new()
  end
  
end

PuptestCli.start
