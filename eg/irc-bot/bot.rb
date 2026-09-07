#!/usr/bin/env ruby
# frozen_string_literal: true

# RiveScript-RB
#
# IRC chatbot example.
#
# Connects to an IRC server with stdlib sockets (no extra gems), loads the
# sample brain, and replies when:
#   * someone starts a channel message with the bot nick ("rsbot: hello")
#   * someone @mentions the bot ("@rsbot hello")
#   * someone sends a private message
#
# Run: ruby bot.rb
# Configure with IRC_HOST, IRC_PORT, IRC_NICK, IRC_CHANNEL, IRC_TLS, etc.
# See README.md.

require "socket"
require "openssl"
require_relative "../../lib/rivescript"

$stdout.sync = true
$stderr.sync = true

class IRCChatBot
  # Stay under the RFC 1459 512-byte line limit, including "PRIVMSG target :".
  MAX_PRIVMSG = 400

  attr_reader :host, :port, :nick, :channel, :brain_path, :always, :tls

  def initialize(opts = {})
    @host = opts.fetch(:host, env("IRC_HOST", "127.0.0.1"))
    @port = Integer(opts.fetch(:port, env("IRC_PORT", "6667")))
    @nick = opts.fetch(:nick, env("IRC_NICK", "rsbot"))
    raw_channel = opts.fetch(:channel, env("IRC_CHANNEL", "#rivescript"))
    @channel = normalize_channel(raw_channel)
    @password = opts.key?(:password) ? opts[:password] : ENV["IRC_PASSWORD"]
    @password = nil if @password.to_s.empty?
    @nickserv_password = opts.key?(:nickserv_password) ? opts[:nickserv_password] : ENV["IRC_NICKSERV_PASSWORD"]
    @nickserv_password = nil if @nickserv_password.to_s.empty?
    @always = opts.key?(:always) ? opts[:always] : (ENV["IRC_ALWAYS"].to_s == "1")
    @tls = opts.key?(:tls) ? opts[:tls] : (ENV["IRC_TLS"].to_s == "1")
    @brain_path = opts.fetch(:brain) { ENV["IRC_BRAIN"] }
    @brain_path = File.expand_path("../brain", __dir__) if @brain_path.to_s.empty?
    @realname = opts.fetch(:realname, "RiveScript.rb IRC bot")
    @socket = opts[:socket]
    @rs = opts[:rivescript]
    @logger = opts.fetch(:logger, $stdout)
    @running = false
    @joined = false
    @buf = +""
  end

  def load_brain
    return self if @rs

    @rs = RiveScript.new(debug: false, concat: "newline")
    @rs.load_directory(@brain_path)
    @rs.sort_replies
    log "Loaded brain from #{@brain_path}"
    self
  end

  def run
    load_brain
    connect if @socket.nil?
    register
    @running = true
    while @running
      line = read_line
      break if line.nil?

      handle_line(line)
    end
  ensure
    shutdown
  end

  def stop
    @running = false
    close_socket
  end

  # Parse one IRC protocol line into prefix, command, and params.
  # Trailing parameter (after " :") is the last element of params.
  def self.parse_line(line)
    line = line.to_s.sub(/\r?\n\z/, "")
    prefix = nil
    rest = line
    if rest.start_with?(":")
      prefix, rest = rest[1..].split(" ", 2)
      rest = rest.to_s
    end

    if (idx = rest.index(" :"))
      middle = rest[0...idx]
      trailing = rest[(idx + 2)..]
      params = middle.split(" ")
      command = params.shift
      params << trailing.to_s
    else
      params = rest.split(" ")
      command = params.shift
    end

    {
      prefix: prefix,
      command: command.to_s.upcase,
      params: params
    }
  end

  def self.nick_from_prefix(prefix)
    return nil if prefix.nil? || prefix.empty?
    return nil unless prefix.include?("!")

    prefix.split("!", 2).first
  end

  def addressed?(target, text)
    return true if private_target?(target)
    return true if @always

    stripped = text.to_s.lstrip
    nick_re = Regexp.escape(@nick)
    stripped.match?(/\A@?#{nick_re}\b/i)
  end

  def strip_address(text)
    nick_re = Regexp.escape(@nick)
    text.to_s.sub(/\A\s*@?#{nick_re}\s*[:,-]?\s*/i, "")
  end

  def reply_target(sender, target)
    private_target?(target) ? sender : target
  end

  def handle_line(line)
    log "<<< #{line}" unless line.empty?
    msg = self.class.parse_line(line)
    return if msg[:command].empty?

    case msg[:command]
    when "PING"
      send_raw("PONG :#{msg[:params].last}")
    when "001"
      identify_nickserv
      join_channel
    when "376", "422"
      join_channel unless @joined
    when "433"
      @nick = "#{@nick}_"
      send_raw("NICK #{@nick}")
    when "PRIVMSG"
      handle_privmsg(msg)
    when "ERROR"
      log "Server error: #{msg[:params].join(' ')}"
      stop
    end
  end

  def handle_privmsg(msg)
    sender = self.class.nick_from_prefix(msg[:prefix])
    target = msg[:params][0].to_s
    text = msg[:params][1].to_s
    return if sender.nil? || sender.casecmp?(@nick)
    return if ctcp?(text)
    return unless addressed?(target, text)

    message = strip_address(text)
    return if message.strip.empty?

    dest = reply_target(sender, target)
    begin
      reply = @rs.reply(sender, message)
    rescue StandardError => e
      log "RiveScript error: #{e.message}"
      send_privmsg(dest, "Sorry, I had trouble answering that.")
      return
    end

    send_privmsg(dest, reply)
  end

  def send_privmsg(target, text)
    text.to_s.split(/\r?\n/).each do |line|
      next if line.strip.empty?

      wrap_line(line, MAX_PRIVMSG).each do |chunk|
        send_raw("PRIVMSG #{target} :#{chunk}")
      end
    end
  end

  def send_raw(command)
    return if @socket.nil? || @socket.closed?

    @socket.write("#{command}\r\n")
    log ">>> #{redact(command)}"
  end

  private

  def env(name, default)
    value = ENV[name]
    value.nil? || value.empty? ? default : value
  end

  def normalize_channel(name)
    name = name.to_s
    name.start_with?("#", "&") ? name : "##{name}"
  end

  def private_target?(target)
    !target.start_with?("#", "&")
  end

  def ctcp?(text)
    text.start_with?("\x01")
  end

  def wrap_line(text, max)
    return [text] if text.length <= max

    chunks = []
    remaining = text
    until remaining.empty?
      if remaining.length <= max
        chunks << remaining
        break
      end
      window = remaining[0, max]
      break_at = window.rindex(" ") || max
      chunk = remaining[0, break_at].strip
      chunks << chunk unless chunk.empty?
      remaining = remaining[break_at..].to_s.lstrip
    end
    chunks
  end

  def connect
    tcp = TCPSocket.new(@host, @port)
    if @tls
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
      ssl = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
      ssl.hostname = @host
      ssl.sync_close = true
      ssl.connect
      @socket = ssl
    else
      @socket = tcp
    end
    log "Connected to #{@host}:#{@port}#{' (TLS)' if @tls}"
  end

  def register
    send_raw("PASS #{@password}") if @password
    send_raw("NICK #{@nick}")
    send_raw("USER #{@nick} 0 * :#{@realname}")
  end

  def identify_nickserv
    return unless @nickserv_password

    send_raw("PRIVMSG NickServ :IDENTIFY #{@nickserv_password}")
  end

  def join_channel
    return if @joined

    send_raw("JOIN #{@channel}")
    @joined = true
    log "Joining #{@channel} as #{@nick}"
  end

  def read_line
    loop do
      if (idx = @buf.index("\n"))
        line = @buf.slice!(0..idx)
        return line.sub(/\r?\n\z/, "")
      end

      chunk = @socket.readpartial(4096)
      @buf << chunk
    rescue EOFError, IOError, Errno::ECONNRESET, Errno::EPIPE
      return nil
    end
  end

  def redact(command)
    case command
    when /\APASS /i
      "PASS ********"
    when /\APRIVMSG NickServ :IDENTIFY /i
      "PRIVMSG NickServ :IDENTIFY ********"
    else
      command
    end
  end

  def log(message)
    @logger.puts(message) if @logger
  end

  def close_socket
    @socket.close unless @socket.nil? || @socket.closed?
  rescue IOError, Errno::EBADF
    # already closed
  end

  def shutdown
    return if @socket.nil? || @socket.closed?

    send_raw("QUIT :RiveScript.rb")
    close_socket
  rescue IOError, Errno::EPIPE, Errno::ECONNRESET
    close_socket
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.include?("-h") || ARGV.include?("--help")
    puts <<~HELP
      RiveScript IRC chatbot

      Usage:
        ruby #{File.basename($PROGRAM_NAME)}

      Environment:
        IRC_HOST               server hostname (default: 127.0.0.1)
        IRC_PORT               server port (default: 6667)
        IRC_NICK               bot nickname (default: rsbot)
        IRC_CHANNEL            channel to join (default: #rivescript)
        IRC_PASSWORD           optional server password
        IRC_NICKSERV_PASSWORD  optional NickServ password
        IRC_TLS                set to 1 to use TLS (typically port 6697)
        IRC_ALWAYS             set to 1 to reply to every channel message
        IRC_BRAIN              path to a RiveScript brain (default: ../brain)

      Example:
        IRC_HOST=irc.libera.chat IRC_PORT=6697 IRC_TLS=1 \\
          IRC_NICK=rsbot IRC_CHANNEL=#botters-test ruby bot.rb

      In a channel, address the bot:
        rsbot: hello
        @rsbot what is your name?
    HELP
    exit 0
  end

  bot = IRCChatBot.new
  %w[INT TERM].each do |sig|
    trap(sig) { bot.stop }
  end

  begin
    bot.run
  rescue StandardError => e
    warn "Failed: #{e.message}"
    exit 1
  end
end
