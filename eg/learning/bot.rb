#!/usr/bin/env ruby
# frozen_string_literal: true

# Learning Example
# See the accompanying README.md for details.
#
# Run: ruby bot.rb

require "readline"
require_relative "../../lib/rivescript"

class MyBot
  attr_reader :rs, :learned_path

  def initialize
    @rs = RiveScript.new(utf8: true, concat: "newline")
    @learned_path = File.expand_path("learned.rive", __dir__)

    files = [
      File.expand_path("../brain/begin.rive", __dir__),
      File.expand_path("../brain/clients.rive", __dir__),
      File.expand_path("../brain/myself.rive", __dir__),
      File.expand_path("macro.rive", __dir__),
      File.expand_path("star.rive", __dir__)
    ]
    @rs.load_file(files)
    @rs.load_file(@learned_path) if File.file?(@learned_path)
    @rs.sort_replies
  end

  def send_message(_username, message)
    puts "[Bot] #{message}"
  end

  def get_reply(username, message)
    # Pass self as scope so object macros can call send_message if needed.
    @rs.reply(username, message, self)
  end
end

bot = MyBot.new
nick = "Soandso"

puts "Type /quit to quit."
puts

loop do
  cmd = Readline.readline("> ", true)
  break if cmd.nil? || cmd == "/quit"

  puts "[#{nick}] #{cmd}"

  begin
    # Preserve original formatting for the learn macro.
    bot.rs.set_uservar(nick, "origMessage", cmd)
    reply = bot.get_reply(nick, cmd)
    bot.send_message(nick, reply)
  rescue StandardError => e
    bot.send_message(nick, "Error: #{e.message}")
  end
end
