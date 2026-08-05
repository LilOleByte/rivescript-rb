# frozen_string_literal: true

require_relative "helper"

class TestApi < Minitest::Test
  def test_load_directory_recursively
    bot = RiveScriptTestCase.new(<<~RIVE)
      + *
      - No, this failed.
    RIVE
    bot.rs.load_directory(File.expand_path("fixtures", __dir__))
    bot.rs.sort_replies
    bot.assert_reply(self, "Did the root directory rivescript load?", "Yes, the root directory rivescript loaded.")
    bot.assert_reply(self, "Did the recursive directory rivescript load?", "Yes, the recursive directory rivescript loaded.")
  end

  def test_default_error_messages
    bot = RiveScriptTestCase.new(<<~RIVE)
      + condition only
      * <get name> == Aiden => Your name is Aiden!

      + recursion
      - {@recursion}

      + impossible object
      - Here we go: <call>unhandled</call>

      > object unhandled rust
        return \"Hello world\"
      < object
    RIVE
    def_not_found = "ERR: No Reply Found"
    def_not_match = "ERR: No Reply Matched"
    def_no_object = "[ERR: Object Not Found]"
    def_recursion = "ERR: Deep Recursion Detected"
    bot.assert_reply(self, "condition only", def_not_found)
    bot.assert_reply(self, "hello bot", def_not_match)
    bot.assert_reply(self, "impossible object", "Here we go: #{def_no_object}")
    bot.assert_reply(self, "recursion", def_recursion)
    bot.rs.errors["replyNotFound"] = "I didn't find a reply!"
    bot.assert_reply(self, "condition only", "I didn't find a reply!")
    bot.assert_reply(self, "hello bot", def_not_match)
    bot.assert_reply(self, "impossible object", "Here we go: #{def_no_object}")
    bot.assert_reply(self, "recursion", def_recursion)
    bot.rs.errors["replyNotMatched"] = "I don't even know what to say to that!"
    bot.assert_reply(self, "condition only", "I didn't find a reply!")
    bot.assert_reply(self, "hello bot", "I don't even know what to say to that!")
    bot.assert_reply(self, "impossible object", "Here we go: #{def_no_object}")
    bot.assert_reply(self, "recursion", def_recursion)
    bot.rs.errors["objectNotFound"] = "I can't handle this object!"
    bot.assert_reply(self, "condition only", "I didn't find a reply!")
    bot.assert_reply(self, "hello bot", "I don't even know what to say to that!")
    bot.assert_reply(self, "impossible object", "Here we go: I can't handle this object!")
    bot.assert_reply(self, "recursion", def_recursion)
    bot.rs.errors["deepRecursion"] = "I'm going too far down the rabbit hole."
    bot.assert_reply(self, "condition only", "I didn't find a reply!")
    bot.assert_reply(self, "hello bot", "I don't even know what to say to that!")
    bot.assert_reply(self, "impossible object", "Here we go: I can't handle this object!")
    bot.assert_reply(self, "recursion", "I'm going too far down the rabbit hole.")
  end

  def test_error_constructor_configuration
    opts = {
      errors: {
        replyNotFound: "I didn't find a reply!",
        replyNotMatched: "I don't even know what to say to that!",
        objectNotFound: "I can't handle this object!",
        deepRecursion: "I'm going too far down the rabbit hole."
      }
    }
    bot = RiveScriptTestCase.new(<<~RIVE, opts)
      + condition only
      * <get name> == Aiden => Your name is Aiden!

      + recursion
      - {@recursion}

      + impossible object
      - Here we go: <call>unhandled</call>

      > object unhandled rust
        return \"Hello world\"
      < object
    RIVE
    bot.assert_reply(self, "condition only", "I didn't find a reply!")
    bot.assert_reply(self, "hello bot", "I don't even know what to say to that!")
    bot.assert_reply(self, "impossible object", "Here we go: I can't handle this object!")
    bot.assert_reply(self, "recursion", "I'm going too far down the rabbit hole.")
  end

  def test_redirect_with_undefined_input
    bot = RiveScriptTestCase.new(<<~RIVE)
      + test
      - {topic=test}{@hi}

      > topic test
        + hi
        - hello

        + *
        - {topic=random}<@>
      < topic

      + *
      - Wildcard \"<star>\"!
    RIVE
    bot.assert_reply(self, "test", "hello")
    bot.assert_reply(self, "?", 'Wildcard ""!')

    bot = RiveScriptTestCase.new(<<~RIVE)
      ! var globaltest = set test name test

      + test
      - {topic=test}{@<get test_name>}

      + test without redirect
      - {topic=test}<get test_name>

      + set test name *
      - <set test_name=<star>>{@test}

      + get global test
      @ <bot globaltest>

      + get bad global test
      @ <bot badglobaltest>

      > topic test
        + test
        - hello <get test_name>!{topic=random}

        + *
        - {topic=random}<@>
      < topic

      + *
      - Wildcard \"<star>\"!
    RIVE
    bot.assert_reply(self, "test", 'Wildcard "undefined"!')
    bot.assert_reply(self, "test without redirect", "undefined")
    bot.assert_reply(self, "set test name test", "hello test!")
    bot.assert_reply(self, "set test name newtest", 'Wildcard "newtest"!')
    bot.assert_reply(self, "get global test", "hello test!")
    bot.assert_reply(self, "get bad global test", 'Wildcard "undefined"!')
  end

  def test_initialmatch
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! array thanks = thanks|thank you

      + (hello|ni hao)
      @ hi

      + hi
      - Oh hi. {@phrase}

      + phrase
      - How are you?

      + good
      - That's great.

      + @thanks{weight=2}
      - No problem. {@phrase}

      + *
      - I don't know.
    RIVE
    bot.assert_reply(self, "Hello?", "Oh hi. How are you?")
    bot.rs.set_uservar(bot.username, "__lastmatch__", "phrase")
    bot.rs.set_uservar(bot.username, "__initialmatch__", "(hello|ni hao)")
    bot.assert_reply(self, "Good!", "That's great.")
    bot.rs.set_uservar(bot.username, "__lastmatch__", "good")
    bot.rs.set_uservar(bot.username, "__initialmatch__", "good")
    bot.assert_reply(self, "Thanks!", "No problem. How are you?")
    bot.rs.set_uservar(bot.username, "__lastmatch__", "phrase")
    bot.rs.set_uservar(bot.username, "__initialmatch__", "@thanks{weight=2}")
  end

  def test_valid_history
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello
      - Hi!

      + bye
      - Goodbye!
    RIVE
    bot.assert_reply(self, "Hello", "Hi!")
    bot.rs.set_uservar(bot.username, "__history__", {
      "input" => ["Hello"]
    })
    bot.assert_reply(self, "Bye!", "Goodbye!")
  end
end
