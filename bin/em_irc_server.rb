#!/usr/bin/env ruby
require 'eventmachine/irc/server'

EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  srvr = EventMachine::start_server "0.0.0.0", 6667, EventMachine::Irc::Server
}
