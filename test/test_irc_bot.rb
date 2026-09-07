# frozen_string_literal: true

require "socket"
require "stringio"
require "timeout"
require_relative "helper"
require_relative "../eg/irc-bot/bot"

class TestIrcBot < Minitest::Test
  def test_parse_line_with_prefix_and_trailing
    msg = IRCChatBot.parse_line(":alice!a@host PRIVMSG #rivescript :rsbot: hello there")
    assert_equal "alice!a@host", msg[:prefix]
    assert_equal "PRIVMSG", msg[:command]
    assert_equal ["#rivescript", "rsbot: hello there"], msg[:params]
  end

  def test_parse_line_ping
    msg = IRCChatBot.parse_line("PING :irc.example.net")
    assert_nil msg[:prefix]
    assert_equal "PING", msg[:command]
    assert_equal ["irc.example.net"], msg[:params]
  end

  def test_parse_line_strips_crlf
    msg = IRCChatBot.parse_line(":server 001 rsbot :Welcome\r\n")
    assert_equal "001", msg[:command]
    assert_equal ["rsbot", "Welcome"], msg[:params]
  end

  def test_nick_from_prefix
    assert_equal "alice", IRCChatBot.nick_from_prefix("alice!user@host")
    assert_nil IRCChatBot.nick_from_prefix("irc.example.net")
    assert_nil IRCChatBot.nick_from_prefix(nil)
  end

  def test_addressed_channel_mentions_and_private_messages
    bot = IRCChatBot.new(nick: "rsbot", channel: "#test", rivescript: :unused, logger: nil)

    assert bot.addressed?("rsbot", "hello")
    assert bot.addressed?("#test", "rsbot: hello")
    assert bot.addressed?("#test", "RsBot, hello")
    assert bot.addressed?("#test", "@rsbot hello")
    refute bot.addressed?("#test", "hello everyone")
    refute bot.addressed?("#test", "notabot: hi")
  end

  def test_always_replies_in_channel
    bot = IRCChatBot.new(nick: "rsbot", channel: "#test", always: true, rivescript: :unused, logger: nil)
    assert bot.addressed?("#test", "hello everyone")
  end

  def test_strip_address
    bot = IRCChatBot.new(nick: "rsbot", rivescript: :unused, logger: nil)
    assert_equal "hello", bot.strip_address("rsbot: hello")
    assert_equal "hello", bot.strip_address("@rsbot hello")
    assert_equal "hello", bot.strip_address("RsBot, hello")
    assert_equal "hello everyone", bot.strip_address("hello everyone")
  end

  def test_reply_target_private_vs_channel
    bot = IRCChatBot.new(nick: "rsbot", rivescript: :unused, logger: nil)
    assert_equal "alice", bot.reply_target("alice", "rsbot")
    assert_equal "#test", bot.reply_target("alice", "#test")
  end

  def test_redacts_passwords_in_logs
    logs = StringIO.new
    rs = RiveScript.new
    rs.stream("+ hello\n- Hi human.\n")
    rs.sort_replies
    client, server = UNIXSocket.pair
    bot = IRCChatBot.new(
      nick: "rsbot",
      channel: "#test",
      password: "s3cret",
      nickserv_password: "nickpass",
      rivescript: rs,
      socket: client,
      logger: logs
    )

    bot.send(:register)
    bot.send(:identify_nickserv)

    output = logs.string
    refute_includes output, "s3cret"
    refute_includes output, "nickpass"
    assert_match(/PASS \*+/, output)
    assert_match(/IDENTIFY \*+/, output)

    from_bot = server.readpartial(4096)
    assert_includes from_bot, "PASS s3cret"
    assert_includes from_bot, "IDENTIFY nickpass"
  ensure
    client&.close
    server&.close
  end

  def test_welcome_triggers_join
    logs = StringIO.new
    rs = stub_brain
    client, server = UNIXSocket.pair
    bot = IRCChatBot.new(nick: "rsbot", channel: "#rivescript", rivescript: rs, socket: client, logger: logs)

    bot.handle_line(":irc.example 001 rsbot :Welcome")
    assert_equal "JOIN #rivescript\r\n", server.readpartial(64)
  ensure
    client&.close
    server&.close
  end

  def test_ping_gets_pong
    logs = StringIO.new
    rs = stub_brain
    client, server = UNIXSocket.pair
    bot = IRCChatBot.new(nick: "rsbot", rivescript: rs, socket: client, logger: logs)

    bot.handle_line("PING :irc.example.net")
    assert_equal "PONG :irc.example.net\r\n", server.readpartial(64)
  ensure
    client&.close
    server&.close
  end

  def test_channel_mention_gets_rivescript_reply
    logs = StringIO.new
    rs = stub_brain
    client, server = UNIXSocket.pair
    bot = IRCChatBot.new(nick: "rsbot", channel: "#test", rivescript: rs, socket: client, logger: logs)

    bot.handle_line(":alice!a@host PRIVMSG #test :rsbot: hello")
    reply = server.readpartial(256)
    assert_match(/\APRIVMSG #test :Hi human\.\r\n\z/, reply)
  ensure
    client&.close
    server&.close
  end

  def test_unaddressed_channel_message_is_ignored
    logs = StringIO.new
    rs = stub_brain
    client, server = UNIXSocket.pair
    bot = IRCChatBot.new(nick: "rsbot", channel: "#test", rivescript: rs, socket: client, logger: logs)

    bot.handle_line(":alice!a@host PRIVMSG #test :hello everyone")
    assert_nil IO.select([server], nil, nil, 0.05)
  ensure
    client&.close
    server&.close
  end

  def test_private_message_gets_reply_without_prefix
    logs = StringIO.new
    rs = stub_brain
    client, server = UNIXSocket.pair
    bot = IRCChatBot.new(nick: "rsbot", rivescript: rs, socket: client, logger: logs)

    bot.handle_line(":alice!a@host PRIVMSG rsbot :hello")
    reply = server.readpartial(256)
    assert_match(/\APRIVMSG alice :Hi human\.\r\n\z/, reply)
  ensure
    client&.close
    server&.close
  end

  def test_ignores_own_messages_and_ctcp
    logs = StringIO.new
    rs = stub_brain
    client, server = UNIXSocket.pair
    bot = IRCChatBot.new(nick: "rsbot", channel: "#test", rivescript: rs, socket: client, logger: logs)

    bot.handle_line(":rsbot!b@host PRIVMSG #test :rsbot: hello")
    bot.handle_line(":alice!a@host PRIVMSG #test :\x01VERSION\x01")
    assert_nil IO.select([server], nil, nil, 0.05)
  ensure
    client&.close
    server&.close
  end

  def test_multiline_reply_is_split
    logs = StringIO.new
    rs = RiveScript.new
    rs.stream("+ hello\n- line one\\nline two\n")
    rs.sort_replies
    client, server = UNIXSocket.pair
    bot = IRCChatBot.new(nick: "rsbot", rivescript: rs, socket: client, logger: logs)

    bot.handle_line(":alice!a@host PRIVMSG rsbot :hello")
    body = read_available(server)
    assert_includes body, "PRIVMSG alice :line one\r\n"
    assert_includes body, "PRIVMSG alice :line two\r\n"
  ensure
    client&.close
    server&.close
  end

  def test_live_handshake_against_fake_irc_server
    rs = stub_brain
    server = TCPServer.new("127.0.0.1", 0)
    port = server.local_address.ip_port
    seen = Queue.new

    server_thread = Thread.new do
      client = server.accept
      client.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if defined?(Socket::IPPROTO_TCP)
      buf = +""
      Timeout.timeout(5) do
        loop do
          buf << client.readpartial(4096)
          while (idx = buf.index("\n"))
            line = buf.slice!(0..idx).sub(/\r?\n\z/, "")
            seen << line
            parsed = IRCChatBot.parse_line(line)
            case parsed[:command]
            when "NICK"
              client.write(":irc.example 001 rsbot :Welcome\r\n")
            when "JOIN"
              client.write(":alice!a@host PRIVMSG #rivescript :rsbot: hello\r\n")
            when "PRIVMSG"
              Thread.exit
            end
          end
        end
      end
    ensure
      client&.close
    end

    logs = StringIO.new
    bot = IRCChatBot.new(
      host: "127.0.0.1",
      port: port,
      nick: "rsbot",
      channel: "#rivescript",
      rivescript: rs,
      logger: logs
    )
    bot_thread = Thread.new { bot.run }

    commands = []
    Timeout.timeout(5) do
      loop do
        line = seen.pop
        commands << line
        break if line.start_with?("PRIVMSG #rivescript :Hi human.")
      end
    end

    assert commands.any? { |l| l.start_with?("NICK ") }
    assert commands.any? { |l| l.start_with?("USER ") }
    assert commands.any? { |l| l.start_with?("JOIN #rivescript") }
    assert commands.any? { |l| l.start_with?("PRIVMSG #rivescript :Hi human.") }
  ensure
    bot&.stop
    begin
      server&.close
    rescue IOError
      nil
    end
    bot_thread&.join(1)
    server_thread&.join(1)
  end

  private

  def stub_brain
    rs = RiveScript.new
    rs.stream("+ hello\n- Hi human.\n")
    rs.sort_replies
    rs
  end

  def read_available(socket, wait = 0.2)
    chunks = []
    chunks << socket.readpartial(4096) while IO.select([socket], nil, nil, wait)
    chunks.join
  end

end
