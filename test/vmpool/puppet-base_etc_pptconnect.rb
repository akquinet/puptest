#!/usr/bin/ruby

## copy this file to /etc/pptconnect.rb in your base vm and add the following
## line to /etc/rc.local in your base vm:
## /usr/bin/ruby /etc/pptconnect.rb

require 'socket'

ipstats=%x(ip addr)
ips=ipstats.scan(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
msg = ''
ips.each do |ip|
  if ip != '127.0.0.1' && ip != '0.0.0.0'
    if msg != ''
       msg += ','
    end
    msg += ip
  end
end
puts "trying to send msg:"+msg

server_ip = '192.168.122.1'
s = TCPSocket.new(server_ip,2828)
s.print msg
puts "successfully sent msg:"+msg
s.close