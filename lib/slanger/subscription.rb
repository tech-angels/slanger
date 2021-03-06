module Slanger
  class Subscription
    attr_accessor :connection, :socket
    delegate :send_payload, :send_message, :error, :socket_id, to: :connection

    def initialize application, socket, socket_id, msg
      @application = application
      @connection = Connection.new socket, socket_id
      @msg       = msg
    end

    def subscribe
      send_payload channel_id, 'pusher_internal:subscription_succeeded'

      channel.subscribe { |m| send_message m }
    end

    private

    def channel
      @application.channel_from_id channel_id
    end

    def channel_id
      @msg['data']['channel']
    end

    def token(channel_id, params=nil)
      to_sign = [socket_id, channel_id, params].compact.join ':'

      digest = OpenSSL::Digest::SHA256.new
      OpenSSL::HMAC.hexdigest digest, @application.secret, to_sign
    end

    def invalid_signature?
      token(channel_id, data) != auth.split(':')[1]
    end

    def auth
      @msg['data']['auth']
    end

    def data
      @msg['data']['channel_data']
    end

    def handle_invalid_signature
      message = "Invalid signature: Expected HMAC SHA256 hex digest of "
      message << "#{socket_id}:#{channel_id}, but got #{auth}"

      error({ message: message})
    end

    def log_message(msg)
      peername = @connection.socket.get_peername
      if peername.nil?
        "socket_id: " + @connection.socket_id.to_s + " " + msg
      else
        port, ip = Socket.unpack_sockaddr_in(peername) 
        "Peer: " + ip.to_s + ":" + port.to_s + " socket_id: " + @connection.socket_id.to_s + " " + msg.to_s
      end
    end
  end
end
