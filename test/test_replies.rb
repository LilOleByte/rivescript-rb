# frozen_string_literal: true

require_relative "helper"

class TestReplies < Minitest::Test
  def test_previous
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! sub who's  = who is
      ! sub it's   = it is
      ! sub didn't = did not
      ! array colors = red blue green black white

      + knock knock
      - Who's there?

      + *
      % who is there
      - <sentence> who?

      + *
      % * who
      - Haha! <sentence>!

      + ask me a question
      - How many arms do I have?

      + [*] # [*]
      % how many arms do i have
      * <star> == 2 => Yes!
      - No!

      + *
      % how many arms do i have
      - That isn't a number.

      + i bought a new *
      - What color is your new <star>?

      + (@colors)
      % what color is your new *
      - <sentence> is a pretty color for a <botstar1>.

      + *
      - I don't know.
    RIVE
    bot.assert_reply(self, "knock knock", "Who's there?")
    bot.assert_reply(self, "Canoe", "Canoe who?")
    bot.assert_reply(self, "Canoe help me with my homework?", "Haha! Canoe help me with my homework!")
    bot.assert_reply(self, "hello", "I don't know.")
    bot.assert_reply(self, "Ask me a question", "How many arms do I have?")
    bot.assert_reply(self, "1", "No!")
    bot.assert_reply(self, "Ask me a question", "How many arms do I have?")
    bot.assert_reply(self, "2", "Yes!")
    bot.assert_reply(self, "Ask me a question", "How many arms do I have?")
    bot.assert_reply(self, "lol", "That isn't a number.")
    bot.assert_reply(self, "I bought a new car", "What color is your new car?")
    bot.assert_reply(self, "red", "Red is a pretty color for a car.")
  end

  def test_random
    bot = RiveScriptTestCase.new(<<~RIVE)
      + test random response
      - One.
      - Two.

      + test random tag
      - This sentence has a random {random}word|bit{/random}.
    RIVE
    bot.assert_reply_random(self, "test random response", ["One.", "Two."])
    bot.assert_reply_random(self, "test random tag", ["This sentence has a random word.", "This sentence has a random bit."])
  end

  def test_continuations
    bot = RiveScriptTestCase.new(<<~RIVE)
      + tell me a poem
      - There once was a man named Tim,\\s
      ^ who never quite learned how to swim.\\s
      ^ He fell off a dock, and sank like a rock,\\s
      ^ and that was the end of him.
    RIVE
    bot.assert_reply(self, "Tell me a poem.", "There once was a man named Tim, who never quite learned how to swim. He fell off a dock, and sank like a rock, and that was the end of him.")
  end

  def test_redirects
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello
      - Hi there!

      + hey
      @ hello

      + hi there
      - {@hello}

      + howdy
      - {@ hello}

      + hola
      - {@ hello }
    RIVE
    bot.assert_reply(self, "hello", "Hi there!")
    bot.assert_reply(self, "hey", "Hi there!")
    bot.assert_reply(self, "hi there", "Hi there!")
    bot.assert_reply(self, "howdy", "Hi there!")
    bot.assert_reply(self, "hola", "Hi there!")
  end

  def test_conditionals
    bot = RiveScriptTestCase.new(<<~RIVE)
      + i am # years old
      - <set age=<star>>OK.

      + what can i do
      * <get age> == undefined => I don't know.
      * <get age> >  25 => Anything you want.
      * <get age> == 25 => Rent a car for cheap.
      * <get age> >= 21 => Drink.
      * <get age> >= 18 => Vote.
      * <get age> <  18 => Not much of anything.

      + am i your master
      * <get master> == true => Yes.
      - No.
    RIVE
    age_q = "What can I do?"
    bot.assert_reply(self, age_q, "I don't know.")
    ages = {
      "16" => "Not much of anything.",
      "18" => "Vote.",
      "20" => "Vote.",
      "22" => "Drink.",
      "24" => "Drink.",
      "25" => "Rent a car for cheap.",
      "27" => "Anything you want."
    }
    ages.each do |age, expected|
      bot.assert_reply(self, "I am #{age} years old.", "OK.")
      bot.assert_reply(self, age_q, expected)
    end
    bot.assert_reply(self, "Am I your master?", "No.")
    bot.rs.set_uservar(bot.username, "master", "true")
    bot.assert_reply(self, "Am I your master?", "Yes.")
  end

  def test_embedded_tags
    bot = RiveScriptTestCase.new(<<~RIVE)
      + my name is *
      * <get name> != undefined => <set oldname=<get name>>I thought\\s
        ^ your name was <get oldname>?
        ^ <set name=<formal>>
      - <set name=<formal>>OK.

      + what is my name
      - Your name is <get name>, right?

      + html test
      - <set name=<b>Name</b>>This has some non-RS <em>tags</em> in it.
    RIVE
    bot.assert_reply(self, "What is my name?", "Your name is undefined, right?")
    bot.assert_reply(self, "My name is Alice.", "OK.")
    bot.assert_reply(self, "My name is Bob.", "I thought your name was Alice?")
    bot.assert_reply(self, "What is my name?", "Your name is Bob, right?")
    bot.assert_reply(self, "HTML Test", "This has some non-RS <em>tags</em> in it.")
  end

  def test_set_uservars
    bot = RiveScriptTestCase.new(<<~RIVE)
      + what is my name
      - Your name is <get name>.

      + how old am i
      - You are <get age>.
    RIVE
    bot.rs.set_uservars(bot.username, {
      "name" => "Aiden",
      "age" => "5"
    })
    bot.assert_reply(self, "What is my name?", "Your name is Aiden.")
    bot.assert_reply(self, "How old am I?", "You are 5.")
  end

  def test_questionmark
    bot = RiveScriptTestCase.new(<<~RIVE)
      + google *
      - <a href=\"https://www.google.com/search?q=<star>\">Results are here</a>
    RIVE
    bot.assert_reply(self, "google coffeescript", '<a href="https://www.google.com/search?q=coffeescript">Results are here</a>')
  end

  def test_repeat
    bot = RiveScriptTestCase.new(<<~RIVE)
      + <input>
      * <input1> == <input4> => You're starting to get annoying.
      * <input1> == <input3> => You don't have to keep repeating yourself.
      * <input1> == <input2> => I heard you the first time.
      - Didn't you just say that?

      + hello
      - Hi there.
    RIVE
    bot.assert_reply(self, "hello", "Hi there.")
    bot.assert_reply(self, "hello", "Didn't you just say that?")
    bot.assert_reply(self, "hello", "I heard you the first time.")
    bot.assert_reply(self, "hello", "You don't have to keep repeating yourself.")
    bot.assert_reply(self, "hello", "You're starting to get annoying.")
    bot.assert_reply(self, "hello", "You're starting to get annoying.")
    bot.assert_reply(self, "hello", "You're starting to get annoying.")
  end

  def test_reply_arrays
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! array greek = alpha beta gamma
      ! array test = testing trying
      ! array format = <uppercase>|<lowercase>|<formal>|<sentence>

      + test random array
      - Testing (@greek) array.

      + test two random arrays
      - {formal}(@test){/formal} another (@greek) array.

      + test nonexistant array
      - This (@array) does not exist.

      + test more arrays
      - I'm (@test) more (@greek) (@arrays).

      + test weird syntax
      - This (@ greek) shouldn't work, and neither should this @test.

      + random format *
      - (@format)
    RIVE
    bot.assert_reply_random(self, "test random array", ["Testing alpha array.", "Testing beta array.", "Testing gamma array."])
    bot.assert_reply_random(self, "test two random arrays", [
      "Testing another alpha array.", "Testing another beta array.", "Testing another gamma array.",
      "Trying another alpha array.", "Trying another beta array.", "Trying another gamma array."
    ])
    bot.assert_reply(self, "test nonexistant array", "This (@array) does not exist.")
    bot.assert_reply_random(self, "test more arrays", [
      "I'm testing more alpha (@arrays).", "I'm testing more beta (@arrays).", "I'm testing more gamma (@arrays).",
      "I'm trying more alpha (@arrays).", "I'm trying more beta (@arrays).", "I'm trying more gamma (@arrays)."
    ])
    bot.assert_reply(self, "test weird syntax", "This (@ greek) shouldn't work, and neither should this @test.")
    bot.assert_reply_random(self, "random format hello world", ["HELLO WORLD", "hello world", "Hello World", "Hello world"])
  end
end
