## gem1.9.1 install rubytree

#require_relative 'util/site_builder'
#siteBuilder = SiteBuilder.new('/home/saheba-universalHome/work/puppetmasterGitRepo/manifests')
#siteBuilder.buildEffectiveSitePP
#puts siteBuilder

#require 'open3'
#
#output, status = Open3.capture2('ssh -t root@localhost "virsh console puptest_base"')
#puts output

require 'net/ssh'

Net::SSH.start('localhost', 'root' ) do|ssh|
#  ssh.open_channel do |channel|
#    channel.on_data do |ch,data|
#      puts "recieved #{data} from shell"
#    end
#    channel.on_close do
#      puts "shell terminated"
#    end
#    
#    channel.exec('virsh console puptest_base')
#    channel.send_data('root') 
#  end
#  ssh.loop
#ssh.process.popen3( "virsh console puptest_base" ) do |input, output, error,thr|
#  puts "thread done: "+thr.pid
#end

#   input, output, error,thr = ssh.process.popen3( "virsh console puptest_base" )
#   puts "thread done: "+thr.pid
#   input.puts "root"
#   puts output.read
  puts "i am done" 
 
end  
# result = ssh.exec!('virsh console puptest_base')
# puts result
# end
