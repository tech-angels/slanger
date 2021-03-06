require 'eventmachine'
require 'em-websocket'

module Slanger
  module WebSocketServer
    def run
      EM.epoll
      EM.kqueue

      EM.run do
        options = {
          host:    Slanger::Config[:websocket_host],
          port:    Slanger::Config[:websocket_port],
          debug:   Slanger::Config[:debug]
        }

        if Slanger::Config[:tls_options]
          options.merge! secure: true,
                         tls_options: Slanger::Config[:tls_options]
        end

        EM::WebSocket.start options do |ws|
          # Keep track of handler instance in instance of EM::Connection to ensure a unique handler instance is used per connection.
          ws.class_eval    { attr_accessor :connection_handler }
          # Delegate connection management to handler instance.
          ws.onopen        { Fiber.new do ws.connection_handler = Slanger::Config.socket_handler.new ws end.resume }
          ws.onmessage     { |msg| Fiber.new do ws.connection_handler.onmessage msg end.resume }
          ws.onclose       { Fiber.new do ws.connection_handler.onclose end.resume }
        end

        # Start a flash policy server
        if Slanger::Config[:flash_policy_host]
          EM::start_server(Slanger::Config[:flash_policy_host], Slanger::Config[:flash_policy_port], FlashPolicyServer)
        end
      end
    end
    extend self
  end
end
