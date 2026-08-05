# frozen_string_literal: true

require_relative "helper"

class TestUnicode < Minitest::Test
  def test_unicode
    bot = RiveScriptTestCase.new(<<~RIVE, utf8: true)
      ! sub who's = who is

      + äh
      - What's the matter?

      + ブラッキー
      - エーフィ

      + knock knock
      - Who's there?

      + *
      % who is there
      - <sentence> who?

      + *
      % * who
      - Haha! <sentence>!

      + tëll më ä pöëm
      - Thërë öncë wäs ä män nämëd Tïm

      + more
      % thërë öncë wäs ä män nämëd tïm
      - Whö nëvër qüïtë lëärnëd höw tö swïm

      + more
      % whö nëvër qüïtë lëärnëd höw tö swïm
      - Hë fëll öff ä döck, änd sänk lïkë ä röck

      + more
      % hë fëll öff ä döck änd sänk lïkë ä röck
      - Änd thät wäs thë ënd öf hïm.
    RIVE
    bot.assert_reply(self, "äh", "What's the matter?")
    bot.assert_reply(self, "ブラッキー", "エーフィ")
    bot.assert_reply(self, "knock knock", "Who's there?")
    bot.assert_reply(self, "Orange", "Orange who?")
    bot.assert_reply(self, "banana", "Haha! Banana!")
    bot.assert_reply(self, "tëll më ä pöëm", "Thërë öncë wäs ä män nämëd Tïm")
    bot.assert_reply(self, "more", "Whö nëvër qüïtë lëärnëd höw tö swïm")
    bot.assert_reply(self, "more", "Hë fëll öff ä döck, änd sänk lïkë ä röck")
    bot.assert_reply(self, "more", "Änd thät wäs thë ënd öf hïm.")
  end

  def test_wildcards
    bot = RiveScriptTestCase.new(<<~RIVE, utf8: true)
      + my name is _
      - Nice to meet you, <star>.

      + i am # years old
      - A lot of people are <star> years old.

      + *
      - No match.
    RIVE
    bot.assert_reply(self, "My name is Aiden", "Nice to meet you, aiden.")
    bot.assert_reply(self, "My name is Bảo", "Nice to meet you, bảo.")
    bot.assert_reply(self, "My name is 5", "No match.")
    bot.assert_reply(self, "I am five years old", "No match.")
    bot.assert_reply(self, "I am 5 years old", "A lot of people are 5 years old.")
  end

  def test_unicode_keyword
    bot = RiveScriptTestCase.new(<<~RIVE, utf8: true)
      ? 你好
      - Matched 你好 keyword.

      ? пиво
      - Matched пиво keyword.

      ? some ascii
      - Matched some ascii keyword.
    RIVE
    bot.assert_reply(self, "你好", "Matched 你好 keyword.")
    bot.assert_reply(self, "a 你好 b", "Matched 你好 keyword.")
    bot.assert_reply(self, "你好你好你好", "Matched 你好 keyword.")
    bot.assert_reply(self, "пиво", "Matched пиво keyword.")
    bot.assert_reply(self, "x пиво y", "Matched пиво keyword.")
    bot.assert_reply(self, "xпивоy", "Matched пиво keyword.")
    bot.assert_reply(self, "пивопивопиво", "Matched пиво keyword.")
    bot.assert_reply(self, "some ascii", "Matched some ascii keyword.")
    bot.assert_reply(self, "want some ascii?", "Matched some ascii keyword.")
    bot.assert_reply(self, "some ascii is ok", "Matched some ascii keyword.")
    bot.assert_reply(self, "send some ascii to me", "Matched some ascii keyword.")
  end

  def test_punctuation
    bot = RiveScriptTestCase.new(<<~RIVE, utf8: true)
      + hello bot
      - Hello human!
    RIVE
    bot.assert_reply(self, "Hello bot", "Hello human!")
    bot.assert_reply(self, "Hello, bot!", "Hello human!")
    bot.assert_reply(self, "Hello: Bot", "Hello human!")
    bot.assert_reply(self, "Hello... bot?", "Hello human!")
    bot.rs.unicode_punctuation = /xxx/
    bot.assert_reply(self, "Hello bot", "Hello human!")
    bot.assert_reply(self, "Hello, bot!", "ERR: No Reply Matched")
  end
end
