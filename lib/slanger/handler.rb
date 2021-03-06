# Handler class.
# Handles a client connected via a websocket connection.

require 'active_support/core_ext/hash'
require 'securerandom'
require 'signature'
require 'fiber'

module Slanger
  class Handler

    attr_accessor :connection
    attr_reader :socket
    delegate :error, :send_payload, to: :connection

    def initialize(socket)
      @socket        = socket
      @peername      = socket.get_peername
      @connection    = Connection.new(@socket)
      @subscriptions = {}
      check_limits and authenticate
    end

    # Dispatches message handling to method with same name as
    # the event name
    def onmessage(msg)
      msg   = JSON.parse msg
      event = msg['event'].gsub(/^pusher:/, 'pusher_')

      if event =~ /^client-/
        msg['socket_id'] = connection.socket_id
        channel = application.channel_from_id msg['channel']
        channel.try :send_client_message, msg
      elsif respond_to? event, true
        send event, msg
      else
        Logger.error "Unknown event: " + event.to_s
      end

    rescue JSON::ParserError
      Logger.error log_message("JSON Parse error on message: '" + msg.to_s + "'")
      error({ code: 5001, message: "Invalid JSON" })
    rescue Exception => e
      error({ code: 500, message: "#{e.message}\n #{e.backtrace}" })
    end

    def onclose
      # Unsubscribe from channels
      @subscriptions.each do |channel_id, subscription_id|
        channel = application.channel_from_id channel_id
        channel.try :unsubscribe, subscription_id
      end
      Logger.debug log_message("Closed connection.")
      Metrics.connection_closed(self)
    end

    def check_limits
      # If the application is nil, let authenticate take care of rejecting it
      return true if application.nil?
      # If application doesn't have a limit or metrics are not running, accept
      return true if application.connection_limit.nil? or not Config.metrics
      # Compare number of connections to the limit
      metrics = Metrics::get_metrics_data_for(application.app_id)
      if metrics && metrics[:nb_connections] && metrics[:nb_connections] >= application.connection_limit
        Logger.error log_message("Application is over the limit of number of connections.")
        error({ code: 4004, message: "Application is over the limit of number of connections." })
        @socket.close_websocket
        false
      else
        true
      end
    end 


    def authenticate
      if valid_app_key? app_key
        Logger.debug log_message("Connection established.")
        Metrics.new_connection(self)
        return connection.establish
      else
        error({ code: 4001, message: "Could not find app by key #{app_key}" })
        @socket.close_websocket
        Logger.error log_message("Application key not found: " + app_key.to_s)
      end
    end

    def pusher_ping(msg)
      send_payload nil, 'pusher:ping'
      Logger.debug log_message("Ping sent.")
    end

    def pusher_pong msg
      Logger.debug log_message("Pong received: " + msg.to_s)
    end

    def pusher_subscribe(msg)
      channel_id = msg['data']['channel']
      klass      = subscription_klass channel_id
      subscription_id = klass.new(application, connection.socket, connection.socket_id, msg).subscribe
      @subscriptions[channel_id] = subscription_id
      Logger.debug log_message("Subscribed to channel: " + channel_id.to_s + " subscriptions id: " + subscription_id.to_s)
      Logger.audit log_message("Subscribed to channel: " + channel_id.to_s + " subscriptions id: " + subscription_id.to_s)
    end

    def application
      @application ||= Application.find_by_key(app_key)
    end

    def peer_ip_port()
      if @peername.nil?
        nil
      else
        port, ip = Socket.unpack_sockaddr_in(@peername)
        "" + ip.to_s + ":" + port.to_s
      end
    end
 
    private

    def app_key
      @socket.request['path'].split(/\W/)[2]
    end

    def valid_app_key? app_key
      not application.nil?
    end

    def subscription_klass channel_id
      klass = channel_id.match(/^(private|presence)-/) do |match|
        Slanger.const_get "#{match[1]}_subscription".classify
      end

      klass || Slanger::Subscription
    end

    def log_message(msg)
      result = ''
      if peername = connection.socket.get_peername
        port, ip = Socket.unpack_sockaddr_in(peername)
        result += "Peer: " + ip.to_s + ":" + port.to_s
      end
      result += " socket_id: " + connection.socket_id.to_s + " " + msg.to_s
    end
  end
end
