# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'socket'

class CallbackServer
  def wait_for_callback(opts, &block)
    @server=TCPServer.new(opts[:callback_server_ip],opts[:callback_server_port])
    server_thread = Thread.new do
        client = @server.accept    # Wait for a client to connect
        addr = client.addr
        yield(client.gets)
        client.close    
        @server.close
    end
    return server_thread
  end
end
