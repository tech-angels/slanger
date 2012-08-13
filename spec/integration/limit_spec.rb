#encoding: utf-8
require 'spec/spec_helper'

describe 'Integration:' do
  before :each do
    cleanup_db
    start_slanger_with_mongo
  end

  describe 'limits on number of messages' do
    it 'should be enforced for messages sent via the API' do
      # Set the app to 1 bellow limit
      set_app_near_message_limit

      status1 = nil
      status2 = nil
      messages = em_stream do |websocket, messages|
        case messages.length
        when 1
          if messages[0]['event'] == 'pusher:error'
            EM.stop
          end
          websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
        when 2
          # This should work
          Pusher['MY_CHANNEL'].trigger! 'an_event', { some: "Mit Raben Und Wölfen" }
        when 3
           # This should not
          lambda {Pusher['MY_CHANNEL'].trigger! 'an_event', { some: "Aus dem vereisten Unterholz verschneiter Wälder" }}.should raise_error(Pusher::Error)
          EM.stop
        end
      end
    end
  end
end
