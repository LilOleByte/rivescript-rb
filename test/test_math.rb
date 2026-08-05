# frozen_string_literal: true

require_relative "helper"

class TestMath < Minitest::Test
  def test_addition
    bot = RiveScriptTestCase.new(<<~RIVE)
      + test counter
      - counter set

      + show
      - counter = <get counter>

      + add
      - <add counter=1>adding

      + sub
      - <sub counter=1>subbing

      + div
      - <set counter=10>
      ^ <div counter=2>
      ^ divving

      + mult
      - <set counter=10>
      ^ <mult counter=2>
      ^ multing

      + subtractor
      - <sub subtractor=1>Subtractor is now: <get subtractor>

      + multiplier
      - <mult multiplier=2>Multiplier is now: <get multiplier>

      + diviser
      - <div diviser=2>Diviser is now: <get diviser>
    RIVE
    bot.assert_reply(self, "test counter", "counter set")
    bot.assert_reply(self, "show", "counter = undefined")
    bot.assert_reply(self, "add", "adding")
    bot.assert_reply(self, "show", "counter = 1")
    bot.assert_reply(self, "sub", "subbing")
    bot.assert_reply(self, "show", "counter = 0")
    bot.assert_reply(self, "div", "divving")
    bot.assert_reply(self, "show", "counter = 5")
    bot.assert_reply(self, "mult", "multing")
    bot.assert_reply(self, "show", "counter = 20")
    bot.assert_reply(self, "subtractor", "Subtractor is now: -1")
    bot.assert_reply(self, "subtractor", "Subtractor is now: -2")
    bot.assert_reply(self, "multiplier", "Multiplier is now: 0")
    bot.assert_reply(self, "diviser", "Diviser is now: 0")
    bot.rs.set_uservar("localuser", "multiplier", "4")
    bot.rs.set_uservar("localuser", "diviser", "128")
    bot.assert_reply(self, "multiplier", "Multiplier is now: 8")
    bot.assert_reply(self, "diviser", "Diviser is now: 64")
  end
end
