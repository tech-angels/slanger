#encoding: utf-8
require 'spec/spec_helper'

describe 'Integration:' do
  before :each do
    cleanup_db
    start_slanger_with_mongo
  end

  describe 'limits on the number of messages' do

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

    it "should be enforced for client events" do
      # Set the app to 1 bellow limit
      set_app_near_message_limit

      client1_messages, client2_messages  = [], []

      em_thread do
        client1, client2 = new_websocket, new_websocket
        client2_messages, client1_messages = [], []

        stream(client1, client1_messages) do |message|
          case client1_messages.length
          when 1
            private_channel client1, client1_messages.first
          when 3
            # This should be reject silently
            client2.send({ event: 'client-something2', data: { some: 'stuff' }, channel: 'private-channel' }.to_json)
            EM::Timer.new(1) {
              # Wait for 1 second then end the test
              EM.stop
            }
          end
        end

        stream(client2, client2_messages) do |message|
          case client2_messages.length
          when 1
            private_channel client2, client2_messages.first
          when 2
            client2.send({ event: 'client-something', data: { some: 'stuff' }, channel: 'private-channel' }.to_json)
          end
        end
      end

      client1_messages.one? { |m| m['event'] == 'client-something' }.should be_true
      client1_messages.none?  { |m| m['event'] == 'client-something2' }.should be_true
      client2_messages.none?  { |m| m['event'] == 'client-something' }.should be_true
      client2_messages.none?  { |m| m['event'] == 'client-something2' }.should be_true
    end
  end
  
  describe 'limits on number of connections' do
    it "should be enforced" do
      client1_messages, client2_messages, client3_messages  = [], [], []

      em_thread do
        client1 = new_websocket
        client2 = new_websocket
        client3_messages, client2_messages, client1_messages = [], [], []
        EM::Timer.new(1) do
          client3 = new_websocket
          stream(client3, client3_messages) do |message|
            case client3_messages.length
            when 1
              EM.stop()
            end
          end
        end

        stream(client1, client1_messages) do |message|
        end

        stream(client2, client2_messages) do |message|
        end
    end



      client1_messages.length.should eq 1
      client2_messages.length.should eq 1
      client3_messages.length.should eq 1
      client1_messages.all? { |m| m['event'] == 'pusher:connection_established' }.should be_true
      client2_messages.all? { |m| m['event'] == 'pusher:connection_established' }.should be_true
      client3_messages.all? { |m| m['event'] == 'pusher:error' and m['data']['code'] == 4004 }.should be_true
    end
  end
end
