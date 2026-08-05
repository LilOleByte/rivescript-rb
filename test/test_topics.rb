# frozen_string_literal: true

require_relative "helper"

class TestTopics < Minitest::Test
  RS_ERR_MATCH = "ERR: No Reply Matched"

  def test_punishment_topic
    bot = RiveScriptTestCase.new(<<~RIVE)
      + hello
      - Hi there!

      + swear word
      - How rude! Apologize or I won't talk to you again.{topic=sorry}

      + *
      - Catch-all.

      > topic sorry
          + sorry
          - It's ok!{topic=random}

          + *
          - Say you're sorry!
      < topic
    RIVE
    bot.assert_reply(self, "hello", "Hi there!")
    bot.assert_reply(self, "How are you?", "Catch-all.")
    bot.assert_reply(self, "Swear word!", "How rude! Apologize or I won't talk to you again.")
    bot.assert_reply(self, "hello", "Say you're sorry!")
    bot.assert_reply(self, "How are you?", "Say you're sorry!")
    bot.assert_reply(self, "Sorry!", "It's ok!")
    bot.assert_reply(self, "hello", "Hi there!")
    bot.assert_reply(self, "How are you?", "Catch-all.")
  end

  def test_topic_inheritance
    bot = RiveScriptTestCase.new(<<~RIVE)
      > topic colors
          + what color is the sky
          - Blue.

          + what color is the sun
          - Yellow.
      < topic

      > topic linux
          + name a red hat distro
          - Fedora.

          + name a debian distro
          - Ubuntu.
      < topic

      > topic stuff includes colors linux
          + say stuff
          - \"Stuff.\"
      < topic

      > topic override inherits colors
          + what color is the sun
          - Purple.
      < topic

      > topic morecolors includes colors
          + what color is grass
          - Green.
      < topic

      > topic evenmore inherits morecolors
          + what color is grass
          - Blue, sometimes.
      < topic
    RIVE
    bot.rs.set_uservar(bot.username, "topic", "colors")
    bot.assert_reply(self, "What color is the sky?", "Blue.")
    bot.assert_reply(self, "What color is the sun?", "Yellow.")
    bot.assert_reply(self, "What color is grass?", RS_ERR_MATCH)
    bot.assert_reply(self, "Name a Red Hat distro.", RS_ERR_MATCH)
    bot.assert_reply(self, "Name a Debian distro.", RS_ERR_MATCH)
    bot.assert_reply(self, "Say stuff.", RS_ERR_MATCH)
    bot.rs.set_uservar(bot.username, "topic", "linux")
    bot.assert_reply(self, "What color is the sky?", RS_ERR_MATCH)
    bot.assert_reply(self, "What color is the sun?", RS_ERR_MATCH)
    bot.assert_reply(self, "What color is grass?", RS_ERR_MATCH)
    bot.assert_reply(self, "Name a Red Hat distro.", "Fedora.")
    bot.assert_reply(self, "Name a Debian distro.", "Ubuntu.")
    bot.assert_reply(self, "Say stuff.", RS_ERR_MATCH)
    bot.rs.set_uservar(bot.username, "topic", "stuff")
    bot.assert_reply(self, "What color is the sky?", "Blue.")
    bot.assert_reply(self, "What color is the sun?", "Yellow.")
    bot.assert_reply(self, "What color is grass?", RS_ERR_MATCH)
    bot.assert_reply(self, "Name a Red Hat distro.", "Fedora.")
    bot.assert_reply(self, "Name a Debian distro.", "Ubuntu.")
    bot.assert_reply(self, 'Say stuff.', '"Stuff."')
    bot.rs.set_uservar(bot.username, "topic", "override")
    bot.assert_reply(self, "What color is the sky?", "Blue.")
    bot.assert_reply(self, "What color is the sun?", "Purple.")
    bot.assert_reply(self, "What color is grass?", RS_ERR_MATCH)
    bot.assert_reply(self, "Name a Red Hat distro.", RS_ERR_MATCH)
    bot.assert_reply(self, "Name a Debian distro.", RS_ERR_MATCH)
    bot.assert_reply(self, "Say stuff.", RS_ERR_MATCH)
    bot.rs.set_uservar(bot.username, "topic", "morecolors")
    bot.assert_reply(self, "What color is the sky?", "Blue.")
    bot.assert_reply(self, "What color is the sun?", "Yellow.")
    bot.assert_reply(self, "What color is grass?", "Green.")
    bot.assert_reply(self, "Name a Red Hat distro.", RS_ERR_MATCH)
    bot.assert_reply(self, "Name a Debian distro.", RS_ERR_MATCH)
    bot.assert_reply(self, "Say stuff.", RS_ERR_MATCH)
    bot.rs.set_uservar(bot.username, "topic", "evenmore")
    bot.assert_reply(self, "What color is the sky?", "Blue.")
    bot.assert_reply(self, "What color is the sun?", "Yellow.")
    bot.assert_reply(self, "What color is grass?", "Blue, sometimes.")
    bot.assert_reply(self, "Name a Red Hat distro.", RS_ERR_MATCH)
    bot.assert_reply(self, "Name a Debian distro.", RS_ERR_MATCH)
    bot.assert_reply(self, "Say stuff.", RS_ERR_MATCH)
  end
end
