unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'helper'
require 'em-irc'
require 'logger'

# monkey patching broken gem
module EventMachine
  module IRC
    class Client
      def unbind(reason)
        #log Logger::INFO "Unbind reason: #{reason}" if reason != nil
        trigger(:disconnect)
      end
    end
  end
end

class TestIrcServer < Minitest::Test
  def test_irc_server_start
    return
    EventMachine.run {
      Signal.trap("INT") { EventMachine.stop }
      Signal.trap("TERM") { EventMachine.stop }
      srvr = EventMachine::start_server "0.0.0.0", 6667, EventMachine::IRC::Server
      testbot = EventMachine::IRC::Client.new do
        host '127.0.0.1'
        port '6667'

        on(:connect) do
          nick('testbot')
        end

        on(:nick) do
          join('#test')
        end

        on(:join) do |channel|  # called after joining a channel
          message(channel, "howdy all")
        end

        on(:message) do |source, target, message|  # called when being messaged
          puts "<#{source}> -> <#{target}>: #{message}"
          if message =~ /quit/
            testbot.conn.close_connection
          end
        end

        # callback for all messages sent from IRC server
        on(:parsed) do |hash|
          puts "#{hash[:prefix]} #{hash[:command]} #{hash[:params].join(' ')}"
        end
        
        on(:disconnect) do
          puts "testbot disconnected"
        end
      end
      
      botmaster = EventMachine::IRC::Client.new do
        host '127.0.0.1'
        port '6667'

        on(:connect) do
          nick('botmaster')
        end

        on(:nick) do
          join('#test')
          message('#test', 'quit')
        end

        on(:join) do |channel|  # called after joining a channel
        end

        on(:message) do |source, target, message|  # called when being messaged
          puts "<#{source}> -> <#{target}>: #{message}"
        end

        # callback for all messages sent from IRC server
        on(:parsed) do |hash|
          puts "#{hash[:prefix]} #{hash[:command]} #{hash[:params].join(' ')}"
        end
        
        on(:disconnect) do
          puts "botmaster disconnected"
        end
      end
      testbot.connect
      
      timer = EventMachine::Timer.new(1) do
        botmaster.connect
      end
      timer2 = EventMachine::Timer.new(5) do
        EM.stop
      end

    }
  end
  
  def test_irc_server_many_bots
    return
    EM.epoll
    EM.set_descriptor_table_size 60000
    EM.run {
      Signal.trap("INT") { EventMachine.stop }
      Signal.trap("TERM") { EventMachine.stop }
      srvr = EventMachine::start_server "0.0.0.0", 6667, EventMachine::IRC::Server
      bots = Array.new
      0.upto(600) do |x|
        bots << EventMachine::IRC::Client.new do
          host '127.0.0.1'
          port '6667'

          on(:connect) do
            nick("testbot#{x}")
          end

          on(:nick) do
            join('#test')
          end

          on(:join) do |channel|  # called after joining a channel
            #message("#test", "howdy all")
          end

          on(:message) do |source, target, message|  # called when being messaged
            #puts "<#{source}> -> <#{target}>: #{message}"
            if message =~ /quit/
              self.conn.close_connection
            end
          end

          # callback for all messages sent from IRC server
          on(:parsed) do |hash|
            #puts "#{hash[:prefix]} #{hash[:command]} #{hash[:params].join(' ')}"
          end
        
          on(:disconnect) do
            #puts "testbot#{x} disconnected"
          end
        end
        bots[x].connect
      end
      botmaster = EventMachine::IRC::Client.new do
        host '127.0.0.1'
        port '6667'

        on(:connect) do
          nick('botmaster2')
        end

        on(:nick) do
          join('#test')
        end

        on(:join) do |channel|  # called after joining a channel
        end

        on(:message) do |source, target, message|  # called when being messaged
          puts "<#{source}> -> <#{target}>: #{message}"
        end

        # callback for all messages sent from IRC server
        on(:parsed) do |hash|
          #puts "#{hash[:prefix]} #{hash[:command]} #{hash[:params].join(' ')}"
        end
      
        on(:disconnect) do
          puts "botmaster disconnected"
        end
      end
      botmaster.connect
    
      timer = EventMachine::Timer.new(30) do
        botmaster.message("#test", "quit")
      end
      timer2 = EventMachine::Timer.new(60) do
        EM.stop
      end
    }
  end
  
  def test_many_channels
    EM.run {
      Signal.trap("INT") { EventMachine.stop }
      Signal.trap("TERM") { EventMachine.stop }
      srvr = EventMachine::start_server "0.0.0.0", 6667, EventMachine::IRC::Server
      testbot = EventMachine::IRC::Client.new do
        host '127.0.0.1'
        port '6667'

        on(:connect) do
          nick('testbot')
        end

        on(:nick) do
          1.upto(6000) do |x|
            join("#test#{x}")
          end
        end

        on(:join) do |channel|  # called after joining a channel
          message(channel, "howdy all") if channel =~ /^#/
        end

        on(:message) do |source, target, message|  # called when being messaged
          puts "<#{source}> -> <#{target}>: #{message}"
          if message =~ /quit/
            testbot.conn.close_connection
            EventMachine::Timer.new(10) do
              EM.stop
            end
          end
        end

        # callback for all messages sent from IRC server
        on(:parsed) do |hash|
          puts "#{hash[:prefix]} #{hash[:command]} #{hash[:params].join(' ')}"
        end
        
        on(:disconnect) do
          puts "testbot disconnected"
        end
      end
      testbot.connect
    }
  end
  
end