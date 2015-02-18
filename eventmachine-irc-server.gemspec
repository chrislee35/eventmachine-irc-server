# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eventmachine/irc/server/version'

Gem::Specification.new do |spec|
  spec.name          = "eventmachine-irc-server"
  spec.version       = EventMachine::IRC::Server::VERSION
  spec.authors       = ["chrislee35"]
  spec.email         = ["rubygems@chrislee.dhs.org"]
  spec.summary       = %q{Simple EventMachine-based IRC server. 簡単なイベントマシーンのIRCのサーバーです。}
  spec.description   = %q{For use in the Rubot Emulation Framework, this simple IRC server allows test bots to connect and receive commands.}
  spec.homepage      = "http://github.com/chrislee35/eventmachine-irc-server"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "eventmachine", ">= 0.12.10"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "minitest", "~> 5.5"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "em-irc", ">= 0.0.2"
end
