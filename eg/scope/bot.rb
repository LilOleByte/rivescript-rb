#!/usr/bin/env ruby
# frozen_string_literal: true

# Scope Example
# See the accompanying README.md for details.
#
# Run: ruby bot.rb

require "readline"
require_relative "../../lib/rivescript"

class ScopedBot
  def initialize
    @rs = RiveScript.new
    @hello = "Hello world"
    @counter = 0

    @rs.load_file(File.expand_path("scope.rive", __dir__))
    @rs.sort_replies
  end

  def get_reply(username, message)
    # Pass self as scope so object macros execute in this object's context.
    @rs.reply(username, message, self)
  end

  # Available to object macros via scope (self).
  def private_function
    "It works!"
  end
end

bot = ScopedBot.new

puts "Type /quit to quit. Try: scope test"
puts

loop do
  cmd = Readline.readline("> ", true)
  break if cmd.nil? || cmd == "/quit"

  begin
    reply = bot.get_reply("soandso", cmd)
    puts "Bot> #{reply}"
  rescue StandardError => e
    puts "Err> #{e.message}"
  end
end
