#encoding: utf-8
require 'spec/spec_helper'
  
describe 'Metrics:' do
  describe "work data" do
    before :each do
      cleanup_db
      start_slanger_with_mongo
    end

    describe 'number of connections' do
      it 'should reflect number of clients' do
        nb_connections_while = nil

        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            if messages[0]['event'] == 'pusher:error'
              EM.stop
            end
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            nb_connections_while = get_number_of_connections(1)
            EM.stop
          end
        end
  
        nb_connections_while.should eq(1)
      end
  
      it 'should decrease after a client exit' do
        nb_connections_while = nil 
        nb_connections_after = nil
  
        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            if messages[0]['event'] == 'pusher:error'
              EM.stop
            end
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            nb_connections_while = get_number_of_connections(1)
            EM.stop
          end
        end
  
        # Give slanger the chance to run before checking the number of connections again
        sleep 2
        nb_connections_after = get_number_of_connections(1)
  
        nb_connections_while.should eq(1)
        nb_connections_after.should eq(0)
      end
  
      it 'should be zero when slanger is killed' do
        nb_connections_while = nil 
        nb_connections_after = nil
  
        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            if messages[0]['event'] == 'pusher:error'
              EM.stop
            end
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            nb_connections_while = get_number_of_connections(1)
            kill_slanger
            timer = EventMachine::Timer.new(2) do
              # get number of connection before quitting. If slanger was still running it would be 1
              nb_connections_after = get_number_of_connections(1)
              EM.stop
            end
          end
        end
  
        nb_connections_while.should eq(1)
        nb_connections_after.should eq(0)
      end
    end
  
    describe 'number of messages' do
      it 'should increase as messages are received' do
        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: "Mit Raben Und Wölfen" }
          when 3
            EM.stop
          end
        end
        nb_messages = get_number_of_messages
  
        nb_messages.should eq(1)
      end

      it 'should be resetable for all applications' do
        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: "Mit Raben Und Wölfen" }
          when 3
            EM.stop
          end
        end
        nb_messages_before_reset = get_number_of_messages
        rest_api_put('/applications/metrics/reset_nb_messages.json')
        nb_messages_after_reset = get_number_of_messages
  
        nb_messages_before_reset.should eq(1)
        nb_messages_after_reset.should eq(1)
      end
 
      it 'should be resetable for a given application' do
        messages = em_stream do |websocket, messages|
          case messages.length
          when 1
            websocket.callback { websocket.send({ event: 'pusher:subscribe', data: { channel: 'MY_CHANNEL'} }.to_json) }
          when 2
            Pusher['MY_CHANNEL'].trigger_async 'an_event', { some: "Mit Raben Und Wölfen" }
          when 3
            EM.stop
          end
        end
        nb_messages_before_reset = get_number_of_messages
        rest_api_put('/applications/metrics/1/reset_nb_messages.json')
        nb_messages_after_reset = get_number_of_messages
  
        nb_messages_before_reset.should eq(1)
        nb_messages_after_reset.should eq(1)
      end
    end
  end 

  describe "stale work data" do
    it 'should be cleaned up when starting' do
      cleanup_db
      insert_stale_metrics
      nb_connections_before1 = get_number_of_connections(1)
      nb_connections_before2 = get_number_of_connections(2)
      start_slanger_with_mongo
      # Give slanger time to start up
      sleep 2
      nb_connections_after1 = get_number_of_connections(1)
      nb_connections_after2 = get_number_of_connections(2)

      nb_connections_before1.should eq(1)
      nb_connections_before2.should eq(1)
      nb_connections_after1.should eq(0)
      nb_connections_after2.should eq(0)
    end
  end
end
