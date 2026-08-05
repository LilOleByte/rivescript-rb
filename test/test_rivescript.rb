# frozen_string_literal: true

require "minitest/autorun"
require "rivescript"

class TestRiveScript < Minitest::Test
  def setup
    @bot = RiveScript.new
  end

  def stream!(code)
    assert @bot.stream(code), "expected stream to parse successfully"
    @bot.sort_replies
  end

  def test_version
    assert_equal RiveScript::VERSION, @bot.version
  end

  def test_basic_reply
    stream!(<<~RIVE)
      + hello bot
      - Hello human!
    RIVE

    assert_equal "Hello human!", @bot.reply("user", "hello bot")
  end

  def test_wildcard_star
    stream!(<<~RIVE)
      + my name is *
      - Nice to meet you, <star>.
    RIVE

    assert_equal "Nice to meet you, bob.", @bot.reply("user", "my name is Bob")
  end

  def test_catch_all
    stream!(<<~RIVE)
      + hello
      - Hi there.

      + *
      - I do not understand.
    RIVE

    assert_equal "Hi there.", @bot.reply("user", "hello")
    assert_equal "I do not understand.", @bot.reply("user", "asdfgh")
  end

  def test_user_variables
    stream!(<<~RIVE)
      + my name is *
      - <set name=<star>>Nice to meet you, <get name>.

      + who am i
      - Your name is <get name>.
    RIVE

    assert_equal "Nice to meet you, alice.", @bot.reply("u", "my name is Alice")
    assert_equal "Your name is alice.", @bot.reply("u", "who am i")
  end

  def test_bot_variables
    stream!(<<~RIVE)
      ! var name = Aiden

      + what is your name
      - I am <bot name>.
    RIVE

    assert_equal "I am Aiden.", @bot.reply("u", "what is your name")
  end

  def test_substitutions
    stream!(<<~RIVE)
      ! sub what's = what is

      + what is up
      - All good.
    RIVE

    assert_equal "All good.", @bot.reply("u", "what's up")
  end

  def test_ruby_object_macro
    stream!(<<~RIVE)
      > object reverse ruby
        return args.join(" ").reverse
      < object

      + reverse *
      - <call>reverse <star></call>
    RIVE

    assert_equal "cba", @bot.reply("u", "reverse abc")
  end

  def test_set_subroutine
    @bot.set_subroutine("echo") do |_rs, args|
      args.join("-")
    end
    stream!(<<~RIVE)
      + echo *
      - <call>echo <star></call>
    RIVE

    assert_equal "a-b", @bot.reply("u", "echo a b")
  end

  def test_load_directory
    bot = RiveScript.new(concat: "newline")
    bot.load_directory(File.expand_path("../eg/brain", __dir__))
    bot.sort_replies
    reply = bot.reply("localuser", "What is your name?")
    assert_match(/Aiden/i, reply)
  end

  def test_topics
    stream!(<<~RIVE)
      + hang out in school
      - OK then.{topic=school}

      > topic school
        + *
        - You're still in school.

        + leave school
        - OK.{topic=random}
      < topic

      + *
      - Random topic.
    RIVE

    assert_equal "OK then.", @bot.reply("u", "hang out in school")
    assert_equal "You're still in school.", @bot.reply("u", "hello")
    assert_equal "OK.", @bot.reply("u", "leave school")
    assert_equal "Random topic.", @bot.reply("u", "hello")
  end

  def test_memory_session_freeze_thaw
    session = RiveScript::MemorySessionManager.new
    session.set("u", { "name" => "Bob" })
    session.freeze("u")
    session.set("u", { "name" => "Alice" })
    assert_equal "Alice", session.get("u", "name")
    session.thaw("u")
    assert_equal "Bob", session.get("u", "name")
  end
end
