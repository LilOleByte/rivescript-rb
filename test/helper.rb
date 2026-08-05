# frozen_string_literal: true

require "minitest/autorun"
require "rivescript"

# Shared harness for RiveScript spec unit tests.
class RiveScriptTestCase
  attr_reader :rs, :username

  def initialize(code = "", opts = {})
    @rs = RiveScript.new(opts)
    @username = "localuser"
    extend_code(code) unless code.to_s.strip.empty?
  end

  def extend_code(code, &on_error)
    ok = @rs.stream(code, on_error)
    @rs.sort_replies
    ok
  end

  def assert_reply(test, message, expected)
    reply = @rs.reply(@username, message)
    test.assert_equal expected, reply, "reply(#{message.inspect})"
  end

  def assert_reply_random(test, message, expected_list)
    reply = @rs.reply(@username, message)
    test.assert_includes expected_list, reply,
                         "reply(#{message.inspect})=#{reply.inspect} not in #{expected_list.inspect}"
  end

  def assert_uservar(test, name, expected)
    value = @rs.get_uservar(@username, name)
    test.assert_equal expected, value, "uservar(#{name.inspect})"
  end
end
