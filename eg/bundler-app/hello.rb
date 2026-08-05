# frozen_string_literal: true

require "rivescript"

bot = RiveScript.new
bot.load_directory(RiveScript.brain_path)
bot.sort_replies

user = "localuser"
message = ARGV.join(" ")
message = "Hello bot" if message.empty?

puts "You> #{message}"
puts "Bot> #{bot.reply(user, message)}"
