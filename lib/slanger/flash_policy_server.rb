require 'eventmachine'

module Slanger
  class FlashPolicyServer < EventMachine::Connection
    def post_init
      send_data '<cross-domain-policy><allow-access-from domain="*" to-ports="*"/></cross-domain-policy>'
      close_connection_after_writing
    end
  end
end

