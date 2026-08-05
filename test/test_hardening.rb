# frozen_string_literal: true

require_relative "helper"

# Regression tests for hardening fixes (original rivescript-js brain flaws).
class TestHardening < Minitest::Test
  def test_get_in_trigger_treats_metacharacters_literally
    bot = RiveScriptTestCase.new(<<~RIVE, utf8: true)
      + my name is *
      - <set name=<star>>ok

      + hello <get name>
      - matched

      + *
      - no
    RIVE

    # Parentheses survive UTF-8 punctuation stripping; without quotemeta
    # they would become a capturing group and match "hello bob".
    bot.assert_reply(self, "my name is (bob)", "ok")
    bot.assert_reply(self, "hello (bob)", "matched")
    bot.assert_reply(self, "hello bob", "no")
  end

  def test_array_metacharacters_are_literal
    bot = RiveScriptTestCase.new(<<~RIVE, utf8: true)
      ! array evil = (foo)|bar

      + say (@evil)
      - got <star>

      + *
      - no
    RIVE

    bot.assert_reply(self, "say (foo)", "got (foo)")
    bot.assert_reply(self, "say bar", "got bar")
    bot.assert_reply(self, "say foo", "no")
  end

  def test_set_without_equals_is_noop
    bot = RiveScriptTestCase.new(<<~RIVE)
      + t
      - <set foo>done <get foo>
    RIVE

    bot.assert_reply(self, "t", "done undefined")
  end

  def test_set_keeps_value_after_first_equals
    bot = RiveScriptTestCase.new(<<~RIVE)
      + t
      - <set data=a=b>ok

      + show
      - <get data>
    RIVE

    bot.assert_reply(self, "t", "ok")
    bot.assert_reply(self, "show", "a=b")
  end

  def test_weight_is_capped
    bot = RiveScriptTestCase.new(<<~RIVE)
      + w
      - {weight=999999999}ok
    RIVE

    bot.assert_reply(self, "w", "ok")
  end

  def test_div_uses_float_division
    bot = RiveScriptTestCase.new(<<~RIVE)
      + start
      - <set n=5><div n=2>done

      + show
      - <get n>
    RIVE

    bot.assert_reply(self, "start", "done")
    bot.assert_reply(self, "show", "2.5")
  end

  def test_enable_object_macros_false
    bot = RiveScript.new(enable_object_macros: false)
    bot.stream(<<~RIVE)
      > object x ruby
        return "hi"
      < object

      + call it
      - <call>x</call>
    RIVE
    bot.sort_replies
    assert_equal "[ERR: Object Not Found]", bot.reply("u", "call it")
  end

  def test_redirect_is_formatted_like_user_input
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello
      - Hi there!

      + greet
      @ Hello!
    RIVE

    bot.assert_reply(self, "greet", "Hi there!")
  end

  def test_substitute_without_sort_leaves_message
    bot = RiveScript.new
    bot.stream("+ hello\n- hi\n")
    # Intentionally do not sort_replies — substitute should not wipe input.
    # reply will warn about unsorted, but format_message/substitute must not blank msg first.
    brain = bot.brain
    assert_equal "hello there", brain.substitute("hello there", "sub")
  end
end
