#!/usr/bin/env ruby
# frozen_string_literal: true

# RiveScript-RB
#
# Simple TCP / telnet server example.
#
# Run this and then telnet to localhost:2001 and chat with the bot!

require "socket"
require_relative "../../lib/rivescript"

$stdout.sync = true
$stderr.sync = true

PORT = 2001
BRAIN = File.expand_path("../brain", __dir__)

bot = RiveScript.new(debug: false, concat: "newline")

begin
  bot.load_directory(BRAIN)
  bot.sort_replies
  puts "Bot loaded!"
rescue StandardError => e
  warn "Failed to load brain: #{e.message}"
  exit 1
end

server = TCPServer.new("0.0.0.0", PORT)
puts "TCP server running on port #{PORT}."
puts

loop do
  socket = server.accept
  Thread.new(socket) do |client|
    name = "#{client.peeraddr[3]}:#{client.peeraddr[1]}"
    puts "User '#{name}' has connected."
    puts

    client.write(
      "Hello #{name}! This is RiveScript.rb v#{bot.version} running on Ruby!\n" \
      "Type /quit to disconnect.\n\n" \
      "You> "
    )

    begin
      while (line = client.gets)
        message = line.to_s.gsub(/[\r\n]/, "")

        if message.start_with?("/quit")
          puts "User '#{name}' has quit via /quit."
          puts
          client.write("Good-bye!\n")
          break
        end

        reply = bot.reply(name, message)
        client.write("Bot> #{reply}\n")
        client.write("You> ")

        puts "[#{name}] #{message}"
        puts "[Bot] #{reply}"
        puts
      end
    rescue Errno::ECONNRESET, Errno::EPIPE
      # Client disconnected abruptly.
    ensure
      client.close
      puts "User '#{name}' has disconnected."
      puts
    end
  end
end
