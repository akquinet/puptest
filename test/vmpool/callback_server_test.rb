# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

$:.unshift File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')
puts File.join(File.dirname(__FILE__),'..'+File::SEPARATOR+'..','lib')

require 'test/unit'
require 'vmpool/callback_server'

class CallbackServerTest < Test::Unit::TestCase
  def test_wait_for_callbacks
    opts = {
      :callback_server_ip => '127.0.0.1',
      :callback_server_port => 2828
    }
    CallbackServer.new.wait_for_callback(opts) { |msg| 
      puts "received msg: "+msg  
      assert_equal("hello",msg)
    }
    
    s = TCPSocket.new(opts[:callback_server_ip], opts[:callback_server_port])
    s.print("hello")
    s.close 
    sleep(1)
    ## make sure only the first message gets handled by the server
    assert_raise(Errno::ECONNREFUSED) {
      s = TCPSocket.new(opts[:callback_server_ip], opts[:callback_server_port])
      s.print("hello2")
      s.close
    }
    
  end
  
   def test_wait_for_callbacks_joined
    opts = {
      :callback_server_ip => '127.0.0.1',
      :callback_server_port => 3838
    }
    thread = CallbackServer.new.wait_for_callback(opts) { |msg| 
      puts "received msg: "+msg  
      assert_equal("hello",msg)
    }
    s = TCPSocket.new(opts[:callback_server_ip], opts[:callback_server_port])
    s.print("hello")
    s.close 
     
    thread.join
  end
  
#  def test_wait_for_callbacks_nat_default
#    opts = {
#      :callback_server_ip => '192.168.122.1',
#      :callback_server_port => 3838
#    }
#    thread = CallbackServer.new.wait_for_callback(opts) { |msg| 
#      puts "received msg: "+msg  
#      assert_equal("hello",msg)
#    }
#    thread.join
#  end
end
