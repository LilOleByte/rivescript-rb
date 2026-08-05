#!/usr/bin/env ruby
# frozen_string_literal: true

# Web Client Example (Ruby)
#
# Serves a small chat UI and answers via RiveScript over HTTP.
# The JS web-client ran entirely in the browser; Ruby serves the brain
# from the backend instead.
#
# Run: ruby server.rb
# Then open http://127.0.0.1:8080/

require "json"
require "webrick"
require_relative "../../lib/rivescript"

PORT = Integer(ENV.fetch("PORT", "8080"))
ROOT = __dir__
BRAIN = File.expand_path("../brain", __dir__)

bot = RiveScript.new(concat: "newline")
files = %w[begin.rive admin.rive clients.rive eliza.rive myself.rive rpg.rive]
    .map { |f| File.join(BRAIN, f) }
    .select { |f| File.file?(f) }
bot.load_file(files)
bot.sort_replies

server = WEBrick::HTTPServer.new(
  Port: PORT,
  DocumentRoot: ROOT,
  Logger: WEBrick::Log.new($stderr, WEBrick::Log::INFO),
  AccessLog: []
)

server.mount_proc("/api/reply") do |req, res|
  res["Content-Type"] = "application/json; charset=utf-8"
  res["Access-Control-Allow-Origin"] = "*"

  if req.request_method == "OPTIONS"
    res["Access-Control-Allow-Methods"] = "POST, OPTIONS"
    res["Access-Control-Allow-Headers"] = "Content-Type"
    res.status = 204
    next
  end

  unless req.request_method == "POST"
    res.status = 405
    res.body = JSON.generate(error: "POST required")
    next
  end

  begin
    payload = JSON.parse(req.body.to_s)
    username = payload["username"].to_s
    username = "localuser" if username.empty?
    message = payload["message"].to_s
    reply = bot.reply(username, message)
    res.body = JSON.generate(
      reply: reply,
      version: bot.version
    )
  rescue StandardError => e
    res.status = 500
    res.body = JSON.generate(error: e.message)
  end
end

server.mount_proc("/api/version") do |_req, res|
  res["Content-Type"] = "application/json; charset=utf-8"
  res.body = JSON.generate(version: bot.version)
end

trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }

puts "RiveScript web client on http://127.0.0.1:#{PORT}/"
puts "Open http://127.0.0.1:#{PORT}/chat.html"
server.start
