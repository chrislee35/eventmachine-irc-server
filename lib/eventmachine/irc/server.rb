# Most of the code for this module was taken from blufox's project at
# https://code.google.com/p/ruby-ircd/
# As I build more functionality/bug-fixes into this, expect major refactoring

require 'eventmachine'
require "eventmachine/irc/server/version"
require 'socket'
require_relative 'server/replies'

include EventMachine::IRC::Replies

def carp(message)
  puts message
end

module EventMachine
  module IRC

    CHANNEL = /^[#\$&]+/
    PREFIX  = /^:[^ ]+ +(.+)$/

    class SynchronizedStore
    	def initialize
    		@store = {}
    		#@mutex = Mutex.new
    	end

    	def method_missing(name,*args)
    		#@mutex.synchronize { 
          @store.__send__(name,*args)
        #}
    	end

    	def each_value
    		#@mutex.synchronize do
    			@store.each_value {|u|
    				#@mutex.unlock
    				yield u
    				#@mutex.lock
    			}
          #end
    	end

    	def keys
    		#@mutex.synchronize{
          @store.keys
        #}
    	end
    end
    
    class ConnectedClient
    	attr_reader :nick, :user, :realname, :channels, :state
      
      def initialize(server)
        @server = server
        @channels = Array.new
        @nick = nil
        @user = nil
        @pass = nil
        @last_ping = Time.now
        @last_pong = Time.now
        @state = {}
        @welcomed = false
        @nick_tries = 0
      end
      
      def host
        # TODO: figure out how to do this with event machine
        return @peername
      end
      
      def userprefix
        # Where is this defined?
        return @usermsg
      end
      
      def ready
        return (!@pass.nil? && !@nick.nil?)
      end
      
      def handle_join(channel)
        @channels << channel
      end
      
      def handle_nick(nick)
    		carp "nick => #{nick}"
    		if Server.user_store[nick].nil?
    			userlist = {}
    			if @nick.nil?
    				handle_newconnect(nick)
    			else
    				userlist[nick] = self if self.nick != nick
    				Server.user_store.delete(@nick)
    				@nick = nick
    			end

    			Server.user_store << self

    			#send the info to the world
    			#get unique users.
    			@channels.each { |c|
    				Server.channel_store[c].each_user { |u|
    					userlist[u.nick] = u
    				}
    			}
    			userlist.values.each {|user|
    				user.reply :nick, nick
    			}
    			@usermsg = ":#{@nick}!~#{@user}@#{@peername}"
    		else
    			#check if we are just nicking ourselves.
    			unless Server.user_store[nick] == self
    				#verify the connectivity of earlier guy
  					reply :numeric, ERR_NICKNAMEINUSE, "* #{nick} ", "Nickname is already in use."
  					@nick_tries += 1
  					if @nick_tries > $config['nick-tries']
  						carp "kicking spurious user #{nick} after #{@nick_tries} tries"
  						handle_abort
  					end
    			end
    		end
    		@nick_tries = 0
      end
      
      def handle_user(user, mode, unused, realname)
        @user = user
        @mode = mode
        @realname = realname
        @usermsg = ":#{@nick}!~#{@user}@#{@peername}"
        send_welcome if !@nick.nil?
      end
      
      def mode
        return @mode
      end
      
    	def handle_newconnect(nick)
    		@alive = true
    		@nick = nick
    		@host = Server.config['hostname']
    		@ver = Server.config['version']
    		@starttime = Server.config['starttime']
    		send_welcome if !@user.nil?
    	end
      
      def handle_pass(pass)
        @pass = pass
      end
      
    	def send_welcome
    		if !@welcomed
    			repl_welcome
    			repl_yourhost
    			repl_created
    			repl_myinfo
    			repl_motd
    			repl_mode
    			@welcomed = true
    		end
    	end

    	def repl_welcome
    		client = "#{@nick}!#{@user}@#{@peername}"
    		reply :numeric, WELCOME, @nick, "Welcome to this IRC server #{client}"
    	end

    	def repl_yourhost
    		reply :numeric, YOURHOST, @nick, "Your host is #{@host}, running version #{@ver}"
    	end

    	def repl_created
    		reply :numeric, CREATED, @nick, "This server was created #{@starttime}"
    	end

    	def repl_myinfo
    		reply :numeric, MYINFO, @nick, "#{@host} #{@ver} #{@server.usermodes} #{@server.channelmodes}"
    	end

    	def repl_bounce(sever, port)
    		reply :numeric, BOUNCE ,"Try server #{server}, port #{port}"
    	end

    	def repl_ison()
    		#XXX TODO
    		reply :numeric, ISON,"notimpl"
    	end

    	def repl_away(nick, msg)
    		reply :numeric, AWAY, nick, msg
    	end

    	def repl_unaway()
    		reply :numeric, UNAWAY, @nick,"You are no longer marked as being away"
    	end

    	def repl_nowaway()
    		reply :numeric, NOWAWAY, @nick,"You have been marked as being away"
    	end

    	def repl_motd()
    		reply :numeric, MOTDSTART,'', "- Message of the Day"
    		reply :numeric, MOTD,'',      "- Do the dance see the source"
    		reply :numeric, ENDOFMOTD,'', "- End of /MOTD command."
    	end

    	def repl_mode()
    	end

    	def send_topic(channel)
    		if Server.channel_store[channel]
    			reply :numeric, TOPIC,channel, "#{Server.channel_store[channel].topic}" 
    		else
    			send_notonchannel channel
    		end
    	end
            
    	def send_nonick(nick)
    		reply :numeric, ERR_NOSUCHNICK, nick, "No such nick/channel"
    	end

    	def send_nochannel(channel)
    		reply :numeric, ERR_NOSUCHCHANNEL, channel, "That channel doesn't exist"
    	end

    	def send_notonchannel(channel)
    		reply :numeric, ERR_NOTONCHANNEL, channel, "Not a member of that channel"
    	end

    	def names(channel)
    		return Server.channel_store[channel].nicks
    	end

    	def send_nameslist(channel)
    		c =  Server.channel_store[channel]
    		if c.nil?
    			carp "names failed :#{c}"
    			return 
    		end
    		names = []
    		c.each_user {|user|
    			names << c.mode(user) + user.nick if user.nick
    		}
    		reply :numeric, NAMREPLY,"= #{c.name}","#{names.join(' ')}"
    		reply :numeric, ENDOFNAMES,"#{c.name} ","End of /NAMES list."
    	end

    	def send_ping()
    		reply :ping, "#{Server.config['hostname']}"
    	end

    	def handle_join(channels)
    		channels.split(/,/).each {|ch|
    			c = ch.strip
    			if c !~ CHANNEL
    				send_nochannel(c)
    				carp "no such channel:#{c}"
    				return
    			end
    			channel = Server.channel_store.add(c)
    			if channel.join(self)
    				send_topic(c)
    				send_nameslist(c)
    				@channels << c
    			else
    				carp "already joined #{c}"
    			end
    		}
    	end

    	def handle_ping(pingmsg, rest)
    		reply :pong, pingmsg
    	end

    	def handle_pong(srv)
    		carp "got pong: #{srv}"
    	end

    	def handle_privmsg(target, msg)
    		case target.strip
    		when CHANNEL
    			channel= Server.channel_store[target]
    			if !channel.nil?
    				channel.privatemsg(msg, self)
    			else
    				send_nonick(target)
    			end
    		else
    			user = Server.user_store[target]
    			if !user.nil?
    				if !user.state[:away].nil?
    					repl_away(user.nick,user.state[:away])
    				end
    				user.reply :privmsg, self.userprefix, user.nick, msg
    			else
    				send_nonick(target)
    			end
    		end
    	end

    	def handle_notice(target, msg)
    		case target.strip
    		when CHANNEL
    			channel= Server.channel_store[target]
    			if !channel.nil?
    				channel.notice(msg, self)
    			else
    				send_nonick(target)
    			end
    		else
    			user = Server.user_store[target]
    			if !user.nil?
    				user.reply :notice, self.userprefix, user.nick, msg
    			else
    				send_nonick(target)
    			end
    		end
    	end

    	def handle_part(channel, msg)
    		if Server.channel_store.channels.include? channel
    			if Server.channel_store[channel].part(self, msg)
    				@channels.delete(channel)
    			else
    				send_notonchannel channel
    			end
    		else
    			send_nochannel channel
    		end
    	end

    	def handle_quit(msg)
    		#do this to avoid double quit due to 2 threads.
    		return if !@alive
    		@alive = false
    		@channels.each do |channel|
    			Server.channel_store[channel].quit(self, msg)
    		end
    		Server.user_store.delete(self.nick)
    		carp "#{self.nick} #{msg}"
        @server.close_connection
    	end

    	def handle_topic(channel, topic)
    		carp "handle topic for #{channel}:#{topic}"
    		if topic.nil? or topic =~ /^ *$/
    			send_topic(channel)
    		else
    			begin
    				Server.channel_store[channel].topic(topic,self)
    			rescue Exception => e
    				carp e
    			end
    		end
    	end

    	def handle_away(msg)
    		carp "handle away :#{msg}"
    		if msg.nil? or msg =~ /^ *$/
    			@state.delete(:away)
    			repl_unaway
    		else
    			@state[:away] = msg
    			repl_nowaway
    		end
    	end

    	def handle_list(channel)
    		reply :numeric, LISTSTART
    		case channel.strip
    		when /^#/
    			channel.split(/,/).each {|cname|
    				c = Server.channel_store[cname.strip]
    				reply :numeric, LIST, c.name, c.topic if c
    			}
    		else
    			#older opera client sends LIST <1000
    			#we wont obey the boolean after list, but allow the listing
    			#nonetheless
    			Server.channel_store.each_channel {|c|
    				reply :numeric, LIST, c.name, c.topic
    			}
    		end
    		reply :numeric, LISTEND
    	end

    	def handle_whois(target,nicks)
    		#ignore target for now.
    		return reply(:numeric, NONICKNAMEGIVEN, "", "No nickname given") if nicks.strip.length == 0
    		nicks.split(/,/).each {|nick|
    			nick.strip!
    			user = Server.user_store[nick]
    			if user
    				reply :numeric, WHOISUSER, "#{user.nick} #{user.user} #{user.host} *", "#{user.realname}"
    				reply :numeric, WHOISCHANNELS, user.nick, "#{user.channels.join(' ')}"
    				repl_away user.nick, user.state[:away] if !user.state[:away].nil?
    				reply :numeric, ENDOFWHOIS, user.nick, "End of /WHOIS list"
    			else
    				return send_nonick(nick) 
    			end
    		}
    	end

    	def handle_names(channels, server)
    		channels.split(/,/).each {|ch| send_nameslist(ch.strip) }
    	end

    	def handle_who(mask, rest)
    		channel = Server.channel_store[mask]
    		hopcount = 0
    		if channel.nil?
    			#match against all users
    			Server.user_store.each_user {|user|
    				reply :numeric, WHOREPLY ,
    				"#{user.channels[0]} #{user.userprefix} #{user.host} #{Server.config['hostname']} #{user.nick} H" , 
    				"#{hopcount} #{user.realname}" if File.fnmatch?(mask, "#{user.host}.#{user.realname}.#{user.nick}")
    			}
    			reply :numeric, ENDOFWHO, mask, "End of /WHO list."
    		else
    			#get all users in the channel
    			channel.each_user {|user|
    				reply :numeric, WHOREPLY ,
    				"#{mask} #{user.userprefix} #{user.host} #{Server.config['hostname']} #{user.nick} H" , 
    				"#{hopcount} #{user.realname}"
    			}
    			reply :numeric, ENDOFWHO, mask, "End of /WHO list."
    		end
    	end

    	def handle_mode(target, rest)
    		#TODO: dummy
    		reply :mode, target, rest
    	end

    	def handle_userhost(nicks)
    		info = []
    		nicks.split(/,/).each {|nick|
    			user = Server.user_store[nick]
    			info << user.nick + '=-' + user.nick + '@' + user.peer
    		}
    		reply :numeric, USERHOST,"", info.join(' ')
    	end

    	def handle_reload(password)
    	end

    	def handle_abort()
    		handle_quit('aborted..')
    	end

    	def handle_version()
    		reply :numeric, VERSION,"#{Server.config['version']} Ruby IRCD", ""
    	end

    	def handle_eval(s)
    		reply :raw, eval(s)
    	end

    	def handle_unknown(s)
    		carp "unknown:>#{s}<"
    		reply :numeric, ERR_UNKNOWNCOMMAND,s, "Unknown command"
    	end

    	def handle_connect
    		reply :raw, "NOTICE AUTH :#{Server.config['version']} initialized, welcome."
    	end

    	def reply(method, *args)
    		case method
    		when :raw
    			arg = *args
    			raw arg
    		when :ping
    			host = *args
    			raw "PING :#{host}"
    		when :pong
    			msg = *args
    			# according to rfc 2812 the PONG must be of
    			#PONG csd.bu.edu tolsun.oulu.fi
    			# PONG message from csd.bu.edu to tolsun.oulu.fi
    			# ie no host at the begining
    			raw "PONG #{@host} #{@peername} :#{msg}"
    		when :join
    			user,channel = args
    			raw "#{user} JOIN :#{channel}"
    		when :part
    			user,channel,msg = args
    			raw "#{user} PART #{channel} :#{msg}"
    		when :quit
    			user,msg = args
    			raw "#{user} QUIT :#{msg}"
    		when :privmsg
    			usermsg, channel, msg = args
    			raw "#{usermsg} PRIVMSG #{channel} :#{msg}"
    		when :notice
    			usermsg, channel, msg = args
    			raw "#{usermsg} NOTICE #{channel} :#{msg}"
    		when :topic
    			usermsg, channel, msg = args
    			raw "#{usermsg} TOPIC #{channel} :#{msg}"
    		when :nick
    			nick = *args
    			raw "#{@usermsg} NICK :#{nick}"
    		when :mode
    			nick, rest = args
    			raw "#{@usermsg} MODE #{nick} :#{rest}"
    		when :numeric
    			numeric,msg,detail = args
    			server = Server.config['hostname']
    			raw ":#{server} #{'%03d'%numeric} #{@nick} #{msg} :#{detail}"
    		end
    	end

    	def raw(arg, abrt=false)
    		begin
    			carp "--> #{arg}"
    			@server.send_data(arg.chomp + "\n") if !arg.nil?
    		rescue Exception => e
    			carp "<#{self.userprefix}>#{e.message}"
    			#carp e.backtrace.join("\n")
    			handle_abort()
    			raise e if abrt
    		end
    	end
      
      def receive_data(data)
    		carp "<-- '#{data.strip}'"
    		s = if data =~ PREFIX
    			$1
    		else
    			data
    		end
    		case s
    		when /^[ ]*$/
    			return
    		when /^PASS +(.+)$/i
    			handle_pass($1.strip)
    		when /^NICK +(.+)$/i
    			handle_nick($1.strip) #done
    		when /^USER +([^ ]+) +([0-9]+) +([^ ]+) +:(.*)$/i
    			handle_user($1, $2, $3, $4) #done
    		when /^USER +([^ ]+) +([0-9]+) +([^ ]+) +:*(.*)$/i
    			#opera does this.
    			handle_user($1, $2, $3, $4) #done
    		when /^USER ([^ ]+) +[^:]*:(.*)/i
    			#chatzilla does this.
    			handle_user($1, '', '', $3) #done
    		when /^JOIN +(.+)$/i
    			handle_join($1) #done
    		when /^PING +([^ ]+) *(.*)$/i
    			handle_ping($1, $2) #done
    		when /^PONG +:(.+)$/i , /^PONG +(.+)$/i
    			handle_pong($1)
    		when /^PRIVMSG +([^ ]+) +:(.*)$/i
    			handle_privmsg($1, $2) #done
    		when /^NOTICE +([^ ]+) +(.*)$/i
    			handle_notice($1, $2) #done
    		when /^PART :+([^ ]+) *(.*)$/i  
    			#some clients require this.
    			handle_part($1, $2) #done
    		when /^PART +([^ ]+) *(.*)$/i
    			handle_part($1, $2) #done
    		when /^QUIT :(.*)$/i
    			handle_quit($1) #done
    		when /^QUIT *(.*)$/i
    			handle_quit($1) #done
    		when /^TOPIC +([^ ]+) *:*(.*)$/i
    			handle_topic($1, $2) #done
    		when /^AWAY +:(.*)$/i
    			handle_away($1)
    		when /^AWAY +(.*)$/i #for opera
    			handle_away($1)
    		when /^:*([^ ])* *AWAY *$/i
    			handle_away(nil)
        when /^AWAY\s*$/i
          handle_away(nil)
    		when /^LIST *(.*)$/i
    			handle_list($1)
    		when /^WHOIS +([^ ]+) +(.+)$/i
    			handle_whois($1,$2)
    		when /^WHOIS +([^ ]+)$/i
    			handle_whois(nil,$1)
    		when /^WHO +([^ ]+) *(.*)$/i
    			handle_who($1, $2)
    		when /^NAMES +([^ ]+) *(.*)$/i
    			handle_names($1, $2)
    		when /^MODE +([^ ]+) *(.*)$/i
    			handle_mode($1, $2)
    		when /^USERHOST +:(.+)$/i
    			#besirc does this (not accourding to RFC 2812)
    			handle_userhost($1)
    		when /^USERHOST +(.+)$/i
    			handle_userhost($1)
    		when /^RELOAD +(.+)$/i
    			handle_reload($1)
    		when /^VERSION *$/i
    			handle_version()
    		when /^EVAL (.*)$/i
    			#strictly for debug
    			handle_eval($1)
    		else
    			handle_unknown(s)
    		end
      end
    end
    
    class Channel < SynchronizedStore
    	attr_reader :name, :topic
    	alias each_user each_value 

    	def initialize(name)
    		super()

    		@topic = "There is no topic"
    		@name = name
    		@oper = []
    		carp "create channel:#{@name}"
    	end

    	def add(client)
    		@oper << client.nick if @oper.empty? and @store.empty?
    		self[client.nick] = client
    	end

    	def remove(client)
    		delete(client.nick)
    	end

    	def join(client)
    		return false if is_member? client
    		add client
    		#send join to each user in the channel
    		each_user {|user|
    			user.reply :join, client.userprefix, @name
    		}
    		return true
    	end

    	def part(client, msg)
    		return false if !is_member? client
    		each_user {|user|
    			user.reply :part, client.userprefix, @name, msg
    		}
    		remove client
    		Server.channel_store.delete(@name) if self.empty?
    		return true
    	end

    	def quit(client, msg)
    		#remove client should happen before sending notification
    		#to others since we dont want a notification to ourselves
    		#after quit.
    		remove client
    		each_user {|user|
    			user.reply :quit, client.userprefix, @name, msg if user!= client
    		}
    		Server.channel_store.delete(@name) if self.empty?
    	end

    	def privatemsg(msg, client)
    		each_user {|user|
    			user.reply :privmsg, client.userprefix, @name, msg if user != client
    		}
    	end

    	def notice(msg, client)
    		each_user {|user|
    			user.reply :notice, client.userprefix, @name, msg if user != client
    		}
    	end

    	def topic(msg=nil,client=nil)
    		return @topic if msg.nil?
    		@topic = msg
    		each_user {|user|
    			user.reply :topic, client.userprefix, @name, msg
    		}
    		return @topic
    	end

    	def nicks
    		return keys
    	end

    	def mode(u)
    		return @oper.include?(u.nick) ? '@' : ''
    	end

    	def is_member?(m)
    		values.include?(m)
    	end

    	alias has_nick? is_member?
    end
        
    class Server < EventMachine::Connection
      @@user_store = SynchronizedStore.new
      class << @@user_store
      	def <<(client)
      		self[client.nick] = client
      	end

      	alias nicks keys
      	alias each_user each_value 
      end
      @@channel_store = SynchronizedStore.new
      class << @@channel_store
      	def add(c)
      		self[c] ||= Channel.new(c)
      	end

      	def remove(c)
      		self.delete[c]
      	end

      	alias each_channel each_value 
      	alias channels keys
      end
      @@config = {
        'version' => '0.04dev',
        'timeout' => 10,
        'port' => 6667,
        'hostname' => Socket.gethostname.split(/\./).shift,
        'starttime' => Time.now.to_s,
        'nick-tries' => 5
      }
      
      def self.user_store
        @@user_store
      end
      
      def self.channel_store
        @@channel_store
      end
      
      def self.config
        @@config
      end
      
      attr_reader :user_store, :channel_store, :config
      
      def initialize
        @user_store = @@user_store
        @channel_store = @@channel_store
        @config = @@config
      end
            
    	def usermodes
    		return "aAbBcCdDeEfFGhHiIjkKlLmMnNopPQrRsStUvVwWxXyYzZ0123459*@"
    	end

    	def channelmodes
    		return "bcdefFhiIklmnoPqstv"
    	end

      def post_init
        @client = ConnectedClient.new(self)
      end
      
      def unbind
        @client.handle_quit("disconnected...")
      end
      
      def receive_data(data)
        data.split(/\n/).each do |line|
          @client.receive_data(line)
        end
      end
    end
  end
end
