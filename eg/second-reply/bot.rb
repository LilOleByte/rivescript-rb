#!/usr/bin/env ruby
# frozen_string_literal: true

# Asynchronous Second Reply Example
# See the accompanying README.md for details.
#
# Run: ruby bot.rb

require "readline"
require_relative "../../lib/rivescript"

class MyBot
  def initialize
    @rs = RiveScript.new
    @rs.load_file(File.expand_path("second-reply.rive", __dir__))
    @rs.sort_replies
  end

  # Deliver a message to a user (IRC / chat adapter would send here).
  def send_message(username, message)
    puts "[Bot] @#{username}: #{message}"
  end

  def get_reply(username, message)
    # Pass self as scope so object macros can call send_message.
    @rs.reply(username, message, self)
  end
end

bot = MyBot.new
nick = "Soandso"

puts "Type /quit to quit. Try: reply test"
puts

loop do
  cmd = Readline.readline("> ", true)
  break if cmd.nil? || cmd == "/quit"

  puts "[#{nick}] #{cmd}"

  begin
    reply = bot.get_reply(nick, cmd)
    bot.send_message(nick, reply) unless reply.to_s.strip.empty?
  rescue StandardError => e
    bot.send_message(nick, "Error: #{e.message}")
  end
end
