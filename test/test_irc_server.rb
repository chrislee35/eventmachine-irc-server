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
        log Logger::INFO "Unbind reason: #{reason}" if reason != nil
        trigger(:disconnect)
      end
    end
  end
end

class TestIrcServer < Minitest::Test
  def test_irc_server_start
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
end