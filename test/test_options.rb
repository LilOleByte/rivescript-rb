# frozen_string_literal: true

require_relative "helper"

class TestOptions < Minitest::Test
  def test_concat
    bot = RiveScriptTestCase.new(<<~RIVE)
      + test concat default
      - Hello
      ^ world!

      ! local concat = space
      + test concat space
      - Hello
      ^ world!

      ! local concat = none
      + test concat none
      - Hello
      ^ world!

      ! local concat = newline
      + test concat newline
      - Hello
      ^ world!

      ! local concat = foobar
      + test concat foobar
      - Hello
      ^ world!

      ! local concat = newline
    RIVE
    bot.extend_code(<<~RIVE)
      + test concat second file
      - Hello
      ^ world!
    RIVE
    bot.assert_reply(self, "test concat default", "Helloworld!")
    bot.assert_reply(self, "test concat space", "Hello world!")
    bot.assert_reply(self, "test concat none", "Helloworld!")
    bot.assert_reply(self, "test concat newline", "Hello\nworld!")
    bot.assert_reply(self, "test concat foobar", "Helloworld!")
    bot.assert_reply(self, "test concat second file", "Helloworld!")
  end

  def test_concat_with_conditionals
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! local concat = newline

      + test *
      * <star1> == a => First A line
      ^ Second A line
      ^ Third A line
      - First B line
      ^ Second B line
      ^ Third B line
    RIVE
    bot.assert_reply(self, "test a", "First A line\nSecond A line\nThird A line")
    bot.assert_reply(self, "test b", "First B line\nSecond B line\nThird B line")

    bot = RiveScriptTestCase.new(<<~RIVE)
      ! local concat = space

      + test *
      * <star1> == a => First A line
      ^ Second A line
      ^ Third A line
      - First B line
      ^ Second B line
      ^ Third B line
    RIVE
    bot.assert_reply(self, "test a", "First A line Second A line Third A line")
    bot.assert_reply(self, "test b", "First B line Second B line Third B line")

    bot = RiveScriptTestCase.new(<<~RIVE)
      + test *
      * <star1> == a => First A line
      ^ Second A line
      ^ Third A line
      - First B line
      ^ Second B line
      ^ Third B line
    RIVE
    bot.assert_reply(self, "test a", "First A lineSecond A lineThird A line")
    bot.assert_reply(self, "test b", "First B lineSecond B lineThird B line")
  end

  def test_concat_space_with_conditionals
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! local concat = newline

      + test *
      * <star1> == a => First A line
      ^ Second A line
      ^ Third A line
      - First B line
      ^ Second B line
      ^ Third B line
    RIVE
    bot.assert_reply(self, "test a", "First A line\nSecond A line\nThird A line")
    bot.assert_reply(self, "test b", "First B line\nSecond B line\nThird B line")
  end

  def test_concat_newline_stringify
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! local concat = newline

      + test *
      - First B line
      ^ Second B line
      ^ Third B line

      + status is *
      * <star1> == good => All good!
      ^ Congrats!
      ^ Have fun!
      * <star1> == bad => Oh no.
      ^ That sucks.
      ^ Try again.
      - I didn't get that.
      ^ What did you say?

      > topic a_cool_topic
        + hello
        - Oh hi there.
        ^ Do you liek turtles?
      < topic
    RIVE
    src = bot.rs.stringify
    expect = <<~EXPECTED
      ! version = 2.0
      ! local concat = none

      + test *
      - First B line\\nSecond B line\\nThird B line

      + status is *
      * <star1> == good => All good!\\nCongrats!\\nHave fun!
      * <star1> == bad => Oh no.\\nThat sucks.\\nTry again.
      - I didn't get that.\\nWhat did you say?

      > topic a_cool_topic

      \t+ hello
      \t- Oh hi there.\\nDo you liek turtles?

      < topic
    EXPECTED
    assert_equal expect, src
  end

  def test_force_case
    bot = RiveScriptTestCase.new(<<~RIVE, force_case: true)
      + hello bot
      - Hello human!

      + I am # years old
      - <set age=<star>>A lot of people are <get age>.

      + enter topic
      - Enter topic via topic tag.{topic=CapsTopic}

      > topic CapsTopic
          + *
          - The topic worked!{topic=random}
      < topic
    RIVE
    bot.assert_reply(self, "hello bot", "Hello human!")
    bot.assert_reply(self, "i am 5 years old", "A lot of people are 5.")
    bot.assert_reply(self, "I am 6 years old", "A lot of people are 6.")
    bot.rs.set_uservar("localuser", "topic", "CapsTopic")
    bot.assert_reply(self, "hello", "The topic worked!")
    bot.assert_reply(self, "enter topic", "Enter topic via topic tag.")
    bot.assert_reply(self, "hello", "The topic worked!")
  end

  def test_no_force_case
    bot = RiveScriptTestCase.new("")
    errors = []
    bot.extend_code(<<~RIVE) do |err, *_|
      + I am # years old
      - <set age=<star>>A lot of people are <get age>.
    RIVE
      errors << err
    end
    expected = "Syntax error: Triggers may only contain lowercase letters, numbers, and these symbols: ( | ) [ ] * _ # { } < > = / at stream() line 1 near + I am # years old"
    assert_includes errors, expected
  end

  def test_case_sensitive
    bot = RiveScriptTestCase.new(<<~RIVE, case_sensitive: true, utf8: true, unicode_punctuation: /~/)
      + js *
      - <call>repl <star></call>

      + say *
      - Hmm.. <star>

      > object repl ruby
        result = eval(args.join(""))
        result = result.to_i if result.is_a?(Float) && result == result.to_i
        return result.to_s
      < object
    RIVE
    bot.assert_reply(self, "js Math.cos(0)", "1")
    bot.assert_reply(self, "say Bojack Horseman", "Hmm.. Bojack Horseman")
    bot.assert_reply(self, "say hello HELLO", "Hmm.. hello HELLO")
  end

  def test_no_case_sensitive
    bot = RiveScriptTestCase.new(<<~RIVE, case_sensitive: false, utf8: true)
      + say *
      - Hmm.. <star>
    RIVE
    bot.assert_reply(self, "say Rick and Morty", "Hmm.. rick and morty")
  end
end
