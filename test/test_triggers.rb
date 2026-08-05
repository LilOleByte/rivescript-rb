# frozen_string_literal: true

require_relative "helper"

class TestTriggers < Minitest::Test
  def test_atomic_triggers
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello bot
      - Hello human.

      + what are you
      - I am a RiveScript bot.
    RIVE
    bot.assert_reply(self, "Hello bot", "Hello human.")
    bot.assert_reply(self, "What are you?", "I am a RiveScript bot.")
  end

  def test_wildcard_triggers
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello bot
      - Hello there, human!

      + my name is *
      - Nice to meet you, <star>.

      + * told me to say *
      - Why did <star1> tell you to say <star2>?

      + i am # years old
      - A lot of people are <star>.

      + i am _ years old
      - Say that with numbers.

      + i am * years old
      - Say that with fewer words.

      + <reply>
      - Is there an owl in here?
    RIVE
    bot.assert_reply(self, "Hello bot", "Hello there, human!")
    bot.assert_reply(self, "Hello there human", "Is there an owl in here?")
    bot.assert_reply(self, "my name is Bob", "Nice to meet you, bob.")
    bot.assert_reply(self, "bob told me to say hi", "Why did bob tell you to say hi?")
    bot.assert_reply(self, "i am 5 years old", "A lot of people are 5.")
    bot.assert_reply(self, "i am five years old", "Say that with numbers.")
    bot.assert_reply(self, "say that with numbers", "Is there an owl in here?")
    bot.assert_reply(self, "i am twenty five years old", "Say that with fewer words.")
  end

  def test_alternatives_and_optionals
    bot = RiveScriptTestCase.new(<<~RIVE)
      + what (are|is) you
      - I am a robot.

      + what is your (home|office|cell) [phone] number
      - It is 555-1234.

      + [please|can you] ask me a question
      - Why is the sky blue?

      + (aa|bb|cc) [bogus]
      - Matched.

      + (yo|hi) [computer|bot] *
      - Matched.
    RIVE
    bot.assert_reply(self, "What are you?", "I am a robot.")
    bot.assert_reply(self, "What is you?", "I am a robot.")
    bot.assert_reply(self, "What is your home phone number?", "It is 555-1234.")
    bot.assert_reply(self, "What is your home number?", "It is 555-1234.")
    bot.assert_reply(self, "What is your cell phone number?", "It is 555-1234.")
    bot.assert_reply(self, "What is your office number?", "It is 555-1234.")
    bot.assert_reply(self, "Can you ask me a question?", "Why is the sky blue?")
    bot.assert_reply(self, "Please ask me a question?", "Why is the sky blue?")
    bot.assert_reply(self, "Ask me a question.", "Why is the sky blue?")
    bot.assert_reply(self, "aa", "Matched.")
    bot.assert_reply(self, "bb", "Matched.")
    bot.assert_reply(self, "aa bogus", "Matched.")
    bot.assert_reply(self, "aabogus", "ERR: No Reply Matched")
    bot.assert_reply(self, "bogus", "ERR: No Reply Matched")
    bot.assert_reply(self, "hi Aiden", "Matched.")
    bot.assert_reply(self, "hi bot how are you?", "Matched.")
    bot.assert_reply(self, "yo computer what time is it?", "Matched.")
    bot.assert_reply(self, "yoghurt is yummy", "ERR: No Reply Matched")
    bot.assert_reply(self, "hide and seek is fun", "ERR: No Reply Matched")
    bot.assert_reply(self, "hip hip hurrah", "ERR: No Reply Matched")
  end

  def test_trigger_arrays
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! array colors = red blue green yellow white
        ^ dark blue|light blue

      + what color is my (@colors) *
      - Your <star2> is <star1>.

      + what color was * (@colors) *
      - It was <star2>.

      + i have a @colors *
      - Tell me more about your <star>.
    RIVE
    bot.assert_reply(self, "What color is my red shirt?", "Your shirt is red.")
    bot.assert_reply(self, "What color is my blue car?", "Your car is blue.")
    bot.assert_reply(self, "What color is my pink house?", "ERR: No Reply Matched")
    bot.assert_reply(self, "What color is my dark blue jacket?", "Your jacket is dark blue.")
    bot.assert_reply(self, "What color was Napoleoan's white horse?", "It was white.")
    bot.assert_reply(self, "What color was my red shirt?", "It was red.")
    bot.assert_reply(self, "I have a blue car.", "Tell me more about your car.")
    bot.assert_reply(self, "I have a cyan car.", "ERR: No Reply Matched")
  end

  def test_weighted_triggers
    bot = RiveScriptTestCase.new(<<~RIVE)
      + * or something{weight=10}
      - Or something. <@>

      + can you run a google search for *
      - Sure!

      + hello *{weight=20}
      - Hi there!

      + something{weight=100}
      - Weighted something

      + something
      - Unweighted something

      + nothing {weight=100}
      - Weighted nothing

      + nothing
      - Unweighted nothing

      + {weight=100}everything
      - Weighted everything

      + everything
      - Unweighted everything

      + {weight=100}   blank
      - Weighted blank

      + blank
      - Unweighted blank
    RIVE
    bot.assert_reply(self, "Hello robot.", "Hi there!")
    bot.assert_reply(self, "Hello or something.", "Hi there!")
    bot.assert_reply(self, "Can you run a Google search for Node", "Sure!")
    bot.assert_reply(self, "Can you run a Google search for Node or something", "Or something. Sure!")
    bot.assert_reply(self, "something", "Weighted something")
    bot.assert_reply(self, "nothing", "Weighted nothing")
    bot.assert_reply(self, "everything", "Weighted everything")
    bot.assert_reply(self, "blank", "Weighted blank")
  end

  def test_empty_piped_arrays
    bot = RiveScriptTestCase.new("")

    errors = []
    expected_errors = [
      "Syntax error: Piped arrays can't begin or end with a | at stream() line 1 near ! array hello = hi|hey|sup|yo|",
      "Syntax error: Piped arrays can't begin or end with a | at stream() line 2 near ! array something = |something|some thing",
      "Syntax error: Piped arrays can't include blank entries at stream() line 3 near ! array nothing = nothing||not a thing"
    ]
    bot.extend_code(<<~RIVE) do |err, *_|
      ! array hello = hi|hey|sup|yo|
      ! array something = |something|some thing
      ! array nothing = nothing||not a thing

      + [*] @hello [*]
      - Oh hello there.

      + *
      - Anything else?
    RIVE
      errors << err
    end

    assert_equal expected_errors, errors
    bot.assert_reply(self, "Hey!", "Oh hello there.")
    bot.assert_reply(self, "sup", "Oh hello there.")
    bot.assert_reply(self, "Bye!", "Anything else?")
    bot.assert_reply(self, "Love you", "Anything else?")
  end

  def test_empty_piped_alternations
    bot = RiveScriptTestCase.new("")

    errors = []
    expected_errors = [
      "Syntax error: Piped alternations can't begin or end with a | at stream() line 1 near + [*] (hi|hey|sup|yo|) [*]",
      "Syntax error: Piped alternations can't begin or end with a | at stream() line 4 near + [*] (|good|great|nice) [*]",
      "Syntax error: Piped alternations can't include blank entries at stream() line 7 near + [*] (mild|warm||hot) [*]"
    ]
    bot.extend_code(<<~RIVE) do |err, *_|
      + [*] (hi|hey|sup|yo|) [*]
      - Oh hello there.

      + [*] (|good|great|nice) [*]
      - Oh nice!

      + [*] (mild|warm||hot) [*]
      - Purrfect.

      + *
      - Anything else?
    RIVE
      errors << err
    end

    assert_equal expected_errors, errors
    bot.assert_reply(self, "Hey!", "Oh hello there.")
    bot.assert_reply(self, "sup", "Oh hello there.")
    bot.assert_reply(self, "that's nice to hear", "Oh nice!")
    bot.assert_reply(self, "so good", "Oh nice!")
    bot.assert_reply(self, "You're hot!", "Purrfect.")
    bot.assert_reply(self, "Bye!", "Anything else?")
    bot.assert_reply(self, "Love you", "Anything else?")
  end

  def test_empty_piped_optionals
    bot = RiveScriptTestCase.new("")

    errors = []
    expected_errors = [
      "Syntax error: Piped optionals can't begin or end with a | at stream() line 1 near + bot [*] [hi|hey|sup|yo|] [*] to me",
      "Syntax error: Piped optionals can't begin or end with a | at stream() line 4 near + dog [*] [|good|great|nice] [*] to me",
      "Syntax error: Piped optionals can't include blank entries at stream() line 7 near + cat [*] [mild|warm||hot] [*] to me"
    ]
    bot.extend_code(<<~RIVE) do |err, *_|
      + bot [*] [hi|hey|sup|yo|] [*] to me
      - Oh hello there.

      + dog [*] [|good|great|nice] [*] to me
      - Oh nice!

      + cat [*] [mild|warm||hot] [*] to me
      - Purrfect.

      + *
      - Anything else?
    RIVE
      errors << err
    end

    assert_equal expected_errors, errors
    bot.assert_reply(self, "Bot say hey to me", "Oh hello there.")
    bot.assert_reply(self, "bot w hi to me", "Oh hello there.")
    bot.assert_reply(self, "dog be nice to me", "Oh nice!")
    bot.assert_reply(self, "Dog don't be good to me", "Oh nice!")
    bot.assert_reply(self, "Cat should not feel warm to me", "Purrfect.")
    bot.assert_reply(self, "Bye!", "Anything else?")
    bot.assert_reply(self, "Love you", "Anything else?")
  end

  def test_empty_piped_missing_arrays
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! array test1 = hi|hey|sup|yo
      ! array test2 = yes|yeah|yep
      ! array test3 = bye|goodbye||byebye

      + [*] (@test2|@test4|@test3) [*]
      - Multi-array match

      + [*] (@test1) [*]
      - Test1 array match
    RIVE
    bot.assert_reply(self, "Test One: hi", "Test1 array match")
    bot.assert_reply(self, "Test Two: yeah", "Multi-array match")
  end
end
