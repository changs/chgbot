#!/usr/bin/ruby

require "socket"

$SAFE=1

class IRC
  def initialize(server, port, nick, channel)
    @server = server
    @port = port
    @nick = nick
    @channel = channel
    @nicks = Array.new
    @counter = 0
    @vle = rand(30)+20
    @ignore = false
  end
  def send(s)
    puts "\e[31m-->\e[0m #{s}"
    @irc.send "#{s}\n", 0 
  end
  def connect()
    @irc = TCPSocket.open(@server, @port)
    send "NICK #{@nick}"
    send "USER Matka Polka Matka :Matka Polka"
    send "JOIN #{@channel}"
    send "PRIVMSG #{@channel} :Czesc wszystkim"
  end
  def evaluate(s)
    if s =~ /^[-+*\/\d\s\eE.()]*$/ then
      begin
        s.untaint
        return eval(s).to_s
      rescue Exception => detail
        puts detail.message()
      end
    end
    return "Error"
  end
  def logl(s)
    puts "\033[1m#LOG: \033[0m"+s
  end
  def log_rcv(s)
    puts "\e[32m<--\e[0m " + s
  end
  def handle_server_input(s)
        case s.strip
        when /^PING :(.+)$/i
          log_rcv "[ Server ping ]"
          send_rand
          send "PONG :#{$1}"
        when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING (.+)[\001]$/i
          log_rcv "[ CTCP PING from #{$1}!#{$2}@#{$3} ]"
          send "NOTICE #{$1} :\001PING #{$4}\001"
        when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]VERSION[\001]$/i
          log_rcv "[ CTCP VERSION from #{$1}!#{$2}@#{$3} ]"
          send "NOTICE #{$1} :\001VERSION chglab IRC v.0.1\001"
        when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+)\s:EVAL (.+)$/i
          log_rcv "[ EVAL #{$5} from #{$1}!#{$2}@#{$3} ]"
          send "PRIVMSG #{(($4==@nick)?$1:$4)} :#{evaluate($5)}"
        else
          @counter += 1
          send_rand if @counter == @vle
          log_rcv s
        end
  end

  def parse(s)
    return s
  end
  
  def send_rand
    @vle = rand(30)+20
    @counter = 0
    people = nicks_on_channel
    people.delete("Stary")
    people.delete("Kurator")
    send "PRIVMSG #{@channel} :#{people[rand(people.length)]}: #{random_quote}"
  end

  def nicks_on_channel
    @nicks = @nicks.uniq
    @nicks.delete(@nick)
    return @nicks
  end
  def parse_irc(s)
    if s.include? "PRIVMSG #Specgrupen :#{@nick}:"
      log_rcv s
      idx = s.index("!") - 1
      username = s[1, idx]
      idx = s.rindex("#{@nick}:") + @nick.length + 2
      command = s[idx, s.length]
      command.strip!
      logl "Command: #{command}"
      if command[0..1] == "!k"
        File.open("cytaty.txt", "a+") do |file|
          file.puts command.slice!(3..command.length)
        end
        message = "Dodane szefie"
      elsif command[0..1] == "!d"
        a = nicks_on_channel
        log_rcv a.join(", ");
        #send_rand
        #data = Time.now
        #message = "Godzina: #{data.hour}:#{data.min}. "
        #message += "Do studiow zostalo: #{25-data.day} dni."
      elsif command[0..1] == "!l"
        @ignore = (@ignore == true) ? false : true
        logl "Wartoss @ignore: #{@ignore}"
        message = false
      elsif ((s.include? ":Stary!") || (s.include? ":Kurator!"))
        unless @ignore
          sleep(6)
          message = random_quote
        else
          logl "Ignoruje boty"
          message = false
        end
      else
        message = random_quote
      end

      send "PRIVMSG #Specgrupen :#{username}: #{message}" if message
    elsif s.include? "NICK"
      idx = s.index("!") - 1
      username = s[1, idx]
      idx = s.rindex(":") + 1
      new_username = s[idx, s.length]
      new_username.chop!
      logl "#{username} zmienil nicka na #{new_username}"
      @nicks.delete(username)
      @nicks.push(new_username)
    elsif s.include? "JOIN :#"
      log_rcv s
      idx = s.index("!") - 1
      username = s[1, idx]
      @nicks.push(username)
      send "PRIVMSG #Specgrupen :Czolem #{username}" unless s.include? "#{@nick}"
    
    elsif ((s.include? "PART :#Specgrupen") || (s.include? "QUIT"))
      log_rcv s
      idx = s.index("!") - 1
      username = s[1, idx]
      @nicks.delete(username)
   
    elsif s.include? "353"
      log_rcv s
      tmp = s.rindex(":")+1
      stmp = s[tmp..s.length]
      @nicks.delete(@nick)
      @nicks = stmp.split
      @nicks = @nicks.collect { |x| x.delete("@") }
    
    else
        handle_server_input(s)
    end
  end

  def main_loop()
    while true
      ready = select([@irc, $stdin], nil, nil, nil)
      next if !ready
      for s in ready[0]
        if s == $stdin then
          return if $stdin.eof
          s = $stdin.gets
          message = parse(s)
          send message
        elsif s == @irc then
          return if @irc.eof
          s = @irc.gets
          parse_irc(s)
        end
      end
    end
  end
end

def random_quote
  quotes = Array.new
  File.open("cytaty.txt", "r") do |file|
    while line = file.gets
      quotes.push(line)
    end
  end
  return quotes[rand(quotes.length)]
end

irc = IRC.new('irc.freenode.net', 6667, 'Stara', '#Specgrupen')
irc.connect()
begin
  irc.main_loop()
rescue Interrupt
rescue Exception => detail
  print detail.message()
  print detail.backtrace.join("\n")
  retry
end

