#!/usr/bin/env ruby
# frozen_string_literal: true

# Persistence example.
# See the accompanying README.md for details.
#
# Run: ruby bot.rb

require "json"
require "readline"
require_relative "../../lib/rivescript"

BRAIN = File.expand_path("../brain", __dir__)

# Fetch a reply and persist user variables to "./$USERNAME.json".
def get_reply(bot, username, message)
  filename = File.join(__dir__, "#{username}.json")

  user_data = bot.get_uservars(username)
  if user_data.nil? && File.file?(filename)
    user_data = JSON.parse(File.read(filename))
    bot.set_uservars(username, user_data)
  end

  reply = bot.reply(username, message)

  user_data = bot.get_uservars(username)
  File.write(filename, JSON.pretty_generate(user_data))

  reply
end

bot = RiveScript.new(concat: "newline")
bot.load_directory(BRAIN)
bot.sort_replies

username = Readline.readline("Enter your username [default: soandso]: ", true)
username = "soandso" if username.nil? || username.strip.empty?
username = username.strip

puts "Hello #{username}"
puts "Type /quit to quit."
puts

loop do
  cmd = Readline.readline("> ", true)
  break if cmd.nil? || cmd == "/quit"

  begin
    reply = get_reply(bot, username, cmd)
    puts "Bot> #{reply}"
  rescue StandardError => e
    puts "Err> #{e.message}"
  end
end
