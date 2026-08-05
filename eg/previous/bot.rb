#!/usr/bin/env ruby
# frozen_string_literal: true

# %Previous Context Example
# See the accompanying README.md for details.
#
# Run: ruby bot.rb

require "readline"
require_relative "../../lib/rivescript"

rs = RiveScript.new(concat: "newline")
rs.load_file(File.expand_path("previous.rive", __dir__))
rs.sort_replies

nick = "localuser"

puts "Type /quit to quit. Try: explain previous"
puts

loop do
  cmd = Readline.readline("> ", true)
  break if cmd.nil? || cmd == "/quit"

  begin
    reply = rs.reply(nick, cmd)
    puts "Bot> #{reply}"
  rescue StandardError => e
    puts "Err> #{e.message}"
  end
end
