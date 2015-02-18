# EventMachine::IRC::Server

EventMachine::IRC::Server provides a basic IRC server for Ruby's EventMachine.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'eventmachine-irc-server'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install eventmachine-irc-server

## Usage

	require 'eventmachine'
    require 'eventmachine/irc/server'
	
	EventMachine.run {
      Signal.trap("INT") { EventMachine.stop }
      Signal.trap("TERM") { EventMachine.stop }
      srvr = EventMachine::start_server "0.0.0.0", 6667, EventMachine::IRC::Server
	}

## Contributing

1. Fork it ( https://github.com/[my-github-username]/eventmachine-irc-server/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
