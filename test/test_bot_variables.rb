# frozen_string_literal: true

require_relative "helper"

class TestBotVariables < Minitest::Test
  def test_bot_variables
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! var name = Aiden
      ! var age = 5

      + what is your name
      - My name is <bot name>.

      + how old are you
      - I am <bot age>.

      + what are you
      - I'm <bot gender>.

      + happy birthday
      - <bot age=6>Thanks!
    RIVE
    bot.assert_reply(self, "What is your name?", "My name is Aiden.")
    bot.assert_reply(self, "How old are you?", "I am 5.")
    bot.assert_reply(self, "What are you?", "I'm undefined.")
    bot.assert_reply(self, "Happy birthday!", "Thanks!")
    bot.assert_reply(self, "How old are you?", "I am 6.")
  end

  def test_global_variables
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! global debug = false

      + debug mode
      - Debug mode is: <env debug>

      + set debug mode *
      - <env debug=<star>>Switched to <star>.
    RIVE
    bot.assert_reply(self, "Debug mode.", "Debug mode is: false")
    bot.assert_reply(self, "Set debug mode true", "Switched to true.")
    bot.assert_reply(self, "Debug mode?", "Debug mode is: true")
  end

  def test_global_variables_set_by
    bot = RiveScriptTestCase.new(<<~RIVE)
      + get mode
      - Debug mode is: <env myMode>

      + set debug mode *
      - <env debug=<star>>Switched to <star>.
    RIVE
    bot.assert_reply(self, "Get mode.", "Debug mode is: undefined")
    bot.rs._global["myMode"] = "0"
    bot.assert_reply(self, "Get mode.", "Debug mode is: 0")
  end

  def test_bot_variables_utf8
    bot = RiveScriptTestCase.new(<<~RIVE, utf8: true)
      ! var 名 = 小小
      ! var 年龄 = 5

      + what is your name
      - My name is <bot 名>.

      + how old are you
      - I am <bot 年龄>.

      + what are you
      - I'm <bot 性别>.

      + happy birthday
      - <bot 年龄=6>Thanks!
    RIVE
    bot.assert_reply(self, "What is your name?", "My name is 小小.")
    bot.assert_reply(self, "How old are you?", "I am 5.")
    bot.assert_reply(self, "What are you?", "I'm undefined.")
    bot.assert_reply(self, "Happy birthday!", "Thanks!")
    bot.assert_reply(self, "How old are you?", "I am 6.")
  end

  def test_global_variables_utf8
    bot = RiveScriptTestCase.new(<<~RIVE, utf8: true)
      ! global 测试 = 禁用

      + debug mode
      - Debug mode is: <env 测试>

      + set debug mode *
      - <env 测试=<star>>Switched to <star>.
    RIVE
    bot.assert_reply(self, "Debug mode.", "Debug mode is: 禁用")
    bot.assert_reply(self, "Set debug mode 启用", "Switched to 启用.")
    bot.assert_reply(self, "Debug mode?", "Debug mode is: 启用")
  end
end
