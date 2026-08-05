# frozen_string_literal: true

require_relative "helper"

class TestSubstitutions < Minitest::Test
  def test_substitutions
    bot = RiveScriptTestCase.new(<<~RIVE)
      + whats up
      - nm.

      + what is up
      - Not much.
    RIVE
    bot.assert_reply(self, "whats up", "nm.")
    bot.assert_reply(self, "what's up?", "nm.")
    bot.assert_reply(self, "what is up?", "Not much.")
    bot.extend_code(<<~RIVE)
      ! sub whats  = what is
      ! sub what's = what is
    RIVE
    bot.assert_reply(self, "whats up", "Not much.")
    bot.assert_reply(self, "what's up?", "Not much.")
    bot.assert_reply(self, "What is up?", "Not much.")
  end

  def test_person_substitutions
    bot = RiveScriptTestCase.new(<<~RIVE)
      + say *
      - <person>
    RIVE
    bot.assert_reply(self, "say I am cool", "i am cool")
    bot.assert_reply(self, "say You are dumb", "you are dumb")
    bot.extend_code(<<~RIVE)
      ! person i am    = you are
      ! person you are = I am
    RIVE
    bot.assert_reply(self, "say I am cool", "you are cool")
    bot.assert_reply(self, "say You are dumb", "I am dumb")
  end
end
