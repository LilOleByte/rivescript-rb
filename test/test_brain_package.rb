# frozen_string_literal: true

require_relative "helper"

class TestBrainPackage < Minitest::Test
  REQUIRED = %w[
    begin.rive clients.rive myself.rive eliza.rive admin.rive rpg.rive
  ].freeze

  def test_brain_path_points_at_shipped_files
    path = RiveScript.brain_path
    assert File.directory?(path), "expected brain directory at #{path}"
    REQUIRED.each do |name|
      assert File.file?(File.join(path, name)), "missing #{name} in bundled brain"
    end
  end

  def test_bundled_brain_loads_and_replies
    bot = RiveScript.new
    bot.load_directory(RiveScript.brain_path)
    bot.sort_replies
    reply = bot.reply("packagetest", "Hello bot")
    refute_equal "ERR: No Reply Matched", reply
    refute reply.to_s.strip.empty?
  end
end
