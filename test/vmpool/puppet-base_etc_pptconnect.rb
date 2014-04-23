#!/usr/bin/ruby

## copy this file to /etc/pptconnect.rb in your base vm and add the following
## line to /etc/rc.local in your base vm:
## /usr/bin/ruby /etc/pptconnect.rb

require 'socket'

ipstats=%x(ip addr)
ips=ipstats.scan(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
ips.each do |ip|
  if ip != '127.0.0.1' && ip != '0.0.0.0'
    segments = ip.split('.')
    server_ip = segments[0]+'.'+segments[1]+'.'+segments[2]+'.1'
    puts "trying to inform: "+server_ip
    s = TCPSocket.new(server_ip,2828)
    s.print ip
    s.close
  end
end