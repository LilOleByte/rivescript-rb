# frozen_string_literal: true

require_relative "helper"

class TestObjects < Minitest::Test
  def test_ruby_objects
    bot = RiveScriptTestCase.new(<<~RIVE)
      > object nolang ruby
        return "Test w/o language."
      < object

      > object wlang ruby
        return "Test w/ language."
      < object

      > object reverse ruby
        msg = args.join(" ")
        return msg.reverse
      < object

      > object foreign perl
        return "Perl checking in!"
      < object

      + test nolang
      - Nolang: <call>nolang</call>

      + test wlang
      - Wlang: <call>wlang</call>

      + reverse *
      - <call>reverse <star></call>

      + test broken
      - Broken: <call>broken</call>

      + test fake
      - Fake: <call>fake</call>

      + test perl
      - Perl: <call>foreign</call>
    RIVE
    bot.assert_reply(self, "Test nolang", "Nolang: Test w/o language.")
    bot.assert_reply(self, "Test wlang", "Wlang: Test w/ language.")
    bot.assert_reply(self, "Reverse hello world.", "dlrow olleh")
    bot.assert_reply(self, "Test broken", "Broken: [ERR: Object Not Found]")
    bot.assert_reply(self, "Test fake", "Fake: [ERR: Object Not Found]")
    bot.assert_reply(self, "Test perl", "Perl: [ERR: Object Not Found]")
  end

  def test_broken_object_source
    skip "Invalid Ruby object source raises SyntaxError during parse"
  end

  def test_disabled_ruby_language
    bot = RiveScriptTestCase.new(<<~RIVE)
      > object test ruby
        return 'Ruby here!'
      < object

      + test
      - Result: <call>test</call>
    RIVE
    bot.assert_reply(self, "test", "Result: Ruby here!")
    bot.rs.set_handler("ruby", nil)
    bot.assert_reply(self, "test", "Result: [ERR: No Object Handler]")
  end

  def test_get_variable
    bot = RiveScriptTestCase.new(<<~RIVE)
      ! var test_var = test

      > object test_get_var ruby
        name = "test_var"
        return rs.get_variable(name)
      < object

      + show me var
      - <call> test_get_var </call>
    RIVE
    bot.assert_reply(self, "show me var", "test")
  end

  def test_uppercase_call
    bot = RiveScriptTestCase.new(<<~RIVE)
      > begin
        + request
        * <bot mood> == happy => {sentence}{ok}{/sentence}
        * <bot mood> == angry => {uppercase}{ok}{/uppercase}
        * <bot mood> == sad   => {lowercase}{ok}{/lowercase}
        - {ok}
      < begin

      > object test ruby
        return "The object result."
      < object

      > object TEST ruby
        return "The object result."
      < object

      + *
      - Hello there. <call>test <star></call>
    RIVE
    bot.assert_reply(self, "hello", "Hello there. The object result.")
    bot.rs.set_variable("mood", "happy")
    bot.assert_reply(self, "hello", "Hello there. The object result.")
    bot.rs.set_variable("mood", "angry")
    bot.assert_reply(self, "hello", "HELLO THERE. THE OBJECT RESULT.")
    bot.rs.set_variable("mood", "sad")
    bot.assert_reply(self, "hello", "hello there. the object result.")
  end

  def test_objects_in_conditions
    bot = RiveScriptTestCase.new(<<~RIVE)
      > object test_condition ruby
        return args[0] == "1" ? "true" : "false"
      < object

      + test sync *
      * <call>test_condition <star></call> == true  => True.
      * <call>test_condition <star></call> == false => False.
      - Call failed.

      + call sync *
      - Result: <call>test_condition <star></call>
    RIVE
    bot.assert_reply(self, "call sync 1", "Result: true")
    bot.assert_reply(self, "call sync 0", "Result: false")
    bot.assert_reply(self, "test sync 1", "True.")
    bot.assert_reply(self, "test sync 2", "False.")
    bot.assert_reply(self, "test sync 0", "False.")
    bot.assert_reply(self, "test sync x", "False.")
  end

  def test_line_breaks_in_call
    bot = RiveScriptTestCase.new(<<~RIVE)
      > object macro ruby
        a = args.join(" ")
        return a
      < object

      ! var name = name with\\nnew line

      + test literal newline
      - <call>macro "argumentwith\\nnewline"</call>

      + test botvar newline
      - <call>macro "<bot name>"</call>
    RIVE
    bot.assert_reply(self, "test literal newline", "argumentwith\nnewline")
    bot.assert_reply(self, "test botvar newline", "name with\\nnew line")
  end

  def test_ruby_string_in_set_subroutine
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello
      - hello <call>helper <star></call>
    RIVE
    bot.rs.set_subroutine("helper", ["return 'person'"])
    bot.assert_reply(self, "hello", "hello person")
  end

  def test_function_in_set_subroutine
    bot = RiveScriptTestCase.new(<<~RIVE)
      + my name is *
      - hello person<call>helper <star></call>
    RIVE
    bot.rs.set_subroutine("helper") do |rs, args|
      assert_equal bot.rs, rs
      assert_equal 1, args.length
      assert_equal "rive", args[0]
      ""
    end
    bot.assert_reply(self, "my name is Rive", "hello person")
  end

  def test_function_in_set_subroutine_return_value
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello
      - hello <call>helper <star></call>
    RIVE
    bot.rs.set_subroutine("helper") do |_rs, _args|
      "person"
    end
    bot.assert_reply(self, "hello", "hello person")
  end

  def test_arguments_in_set_subroutine
    bot = RiveScriptTestCase.new(<<~RIVE)
      + my name is *
      - hello <call>helper "<star>" 12</call>
    RIVE
    bot.rs.set_subroutine("helper") do |_rs, args|
      assert_equal 2, args.length
      assert_equal "thomas edison", args[0]
      assert_equal "12", args[1]
      args[0]
    end
    bot.assert_reply(self, "my name is thomas edison", "hello thomas edison")
  end

  def test_quoted_strings_arguments_in_set_subroutine
    bot = RiveScriptTestCase.new(<<~RIVE)
      + my name is *
      - hello <call>helper "<star>" 12 "another param"</call>
    RIVE
    bot.rs.set_subroutine("helper") do |_rs, args|
      assert_equal 3, args.length
      assert_equal "thomas edison", args[0]
      assert_equal "12", args[1]
      assert_equal "another param", args[2]
      args[0]
    end
    bot.assert_reply(self, "my name is thomas edison", "hello thomas edison")
  end

  def test_arguments_with_funky_spacing_in_set_subroutine
    bot = RiveScriptTestCase.new(<<~RIVE)
      + my name is *
      - hello <call> helper "<star>"   12   "another  param" </call>
    RIVE
    bot.rs.set_subroutine("helper") do |_rs, args|
      assert_equal 3, args.length
      assert_equal "thomas edison", args[0]
      assert_equal "12", args[1]
      assert_equal "another  param", args[2]
      args[0]
    end
    bot.assert_reply(self, "my name is thomas edison", "hello thomas edison")
  end

  def test_stringify_with_objects
    bot = RiveScriptTestCase.new(<<~RIVE)
      > object hello ruby
        return "Hello"
      < object
      + my name is *
      - hello there<call>exclaim</call>
      ^ and i like continues
    RIVE
    bot.rs.set_subroutine("exclaim") do |_rs, _args|
      "!"
    end
    src = bot.rs.stringify
    expect = <<~EXPECTED
      ! version = 2.0
      ! local concat = none

      > object hello ruby
      \treturn "Hello"
      < object

      > object exclaim ruby
      < object

      + my name is *
      - hello there<call>exclaim</call>and i like continues
    EXPECTED
    assert_equal expect, src
  end

  def test_nested_macro_calls
    bot = RiveScriptTestCase.new(<<~RIVE)
      > object wrapper ruby
      return "_" + args[0] + "_"
      < object

      > object add_hello ruby
      return "hello:" + args[0]
      < object

      + *
      - <call>wrapper <call>add_hello <star></call></call>
    RIVE
    bot.assert_reply(self, "test", "_hello:test_")
  end
end
