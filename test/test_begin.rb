# frozen_string_literal: true

require_relative "helper"

class TestBegin < Minitest::Test
  def test_no_begin_block
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello bot
      - Hello human.
    RIVE
    bot.assert_reply(self, "Hello bot", "Hello human.")
  end

  def test_simple_begin_block
    bot = RiveScriptTestCase.new(<<~RIVE)
      > begin
        + request
        - {ok}
      < begin

      + hello bot
      - Hello human.
    RIVE
    bot.assert_reply(self, "Hello bot.", "Hello human.")
  end

  def test_blocked_begin_block
    bot = RiveScriptTestCase.new(<<~RIVE)
      > begin
        + request
        - Nope.
      < begin

      + hello bot
      - Hello human.
    RIVE
    bot.assert_reply(self, "Hello bot.", "Nope.")
  end

  def test_conditional_begin_block
    bot = RiveScriptTestCase.new(<<~RIVE)
      > begin
        + request
        * <get met> == undefined => <set met=true>{ok}
        * <get name> != undefined => <get name>: {ok}
        - {ok}
      < begin

      + hello bot
      - Hello human.

      + my name is *
      - <set name=<formal>>Hello, <get name>.
    RIVE
    bot.assert_reply(self, "Hello bot.", "Hello human.")
    bot.rs.set_uservar(bot.username, "met", "true")
    bot.rs.set_uservar(bot.username, "name", "undefined")
    bot.assert_reply(self, "My name is bob", "Hello, Bob.")
    bot.rs.set_uservar(bot.username, "name", "Bob")
    bot.assert_reply(self, "Hello Bot", "Bob: Hello human.")
  end
end
