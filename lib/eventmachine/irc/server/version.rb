require 'eventmachine'

module EventMachine
  module IRC
    class Server < EventMachine::Connection
      VERSION = "0.0.1"
    end
  end
end
