# frozen_string_literal: true

require_relative "helper"

# Thorough trigger coverage for eg/brain/eliza.rive via __lastmatch__.
class TestElizaBrain < Minitest::Test
  def setup
    @bot = RiveScript.new(concat: "newline")
    brain = RiveScript.brain_path
    @bot.load_file([
      File.join(brain, "begin.rive"),
      File.join(brain, "eliza.rive")
    ])
    @bot.sort_replies
    @user = "elizauser"
  end

  def reply(message)
    @bot.reply(@user, message)
  end

  def last_match
    @bot.last_match(@user)
  end

  def assert_trigger(message, expected_trigger)
    text = reply(message)
    refute_equal "ERR: No Reply Matched", text, message
    assert_equal expected_trigger, last_match,
                 "message=#{message.inspect} reply=#{text.inspect}"
    text
  end

  def test_eliza_file_present
    assert File.file?(File.join(RiveScript.brain_path, "eliza.rive"))
  end

  def test_all_primary_eliza_triggers
    {
      "I remember cats" => "i remember *",
      "Do you remember cats" => "do you remember *",
      "I forget cats" => "i forget *",
      "Did you forget cats" => "did you forget *",
      "If rain falls" => "[*] if *",
      "I dreamed of flying" => "[*] i dreamed *",
      "Perhaps later" => "[*] perhaps [*]",
      "Hello" => "(hello|hi|hey|howdy|hola|hai|yo) [*]",
      "Hi" => "(hello|hi|hey|howdy|hola|hai|yo) [*]",
      "Hey" => "(hello|hi|hey|howdy|hola|hai|yo) [*]",
      "computer room" => "[*] computer [*]",
      "Am I tall" => "am i *",
      "Birds are loud" => "* are *",
      "Your hat is red" => "[*] your *",
      "Was I late" => "was i *",
      "I was late" => "i was *",
      "Was you late" => "[*] was you *",
      "I want cake" => "i (desire|want|need) *",
      "I need cake" => "i (desire|want|need) *",
      "I desire cake" => "i (desire|want|need) *",
      "I am sad" => "i am (sad|unhappy|mad|angry|pissed|depressed) [*]",
      "I am unhappy" => "i am (sad|unhappy|mad|angry|pissed|depressed) [*]",
      "I am angry" => "i am (sad|unhappy|mad|angry|pissed|depressed) [*]",
      "I am happy" => "i am (happy|excited|glad) [*]",
      "I am glad" => "i am (happy|excited|glad) [*]",
      "I am excited" => "i am (happy|excited|glad) [*]",
      "I think so" => "i (believe|think) *",
      "I believe so" => "i (believe|think) *",
      "I am tired" => "i am *",
      "I can not swim" => "i can not *",
      "I do not care" => "i do not *",
      "I feel bad" => "i feel *",
      "I love you" => "i * you",
      "Yes" => "[*] (yes|yeah|yep|yup) [*]",
      "Yeah" => "[*] (yes|yeah|yep|yup) [*]",
      "No" => "[*] (nope|nah) [*]", # redirected from + no
      "Nope" => "[*] (nope|nah) [*]",
      "Nah" => "[*] (nope|nah) [*]",
      "No one cares" => "no one *",
      "My mother cooks" => "[*] my (mom|dad|mother|father|bro|brother|sis|sister|cousin|aunt|uncle) *",
      "My father left" => "[*] my (mom|dad|mother|father|bro|brother|sis|sister|cousin|aunt|uncle) *",
      "Can I swim" => "can i *",
      "What time" => "(what|who|when|where|how) [*]",
      "Who cares" => "(what|who|when|where|how) [*]",
      "Because reasons" => "[*] because [*]",
      "Why do not you care" => "why do not you *",
      "Why can not I fly" => "why can not i *",
      "Everyone left" => "everyone *",
      "damn it" => "[*] (fuck|fucker|shit|damn|shut up|bitch) [*]",
      "this is shit" => "[*] (fuck|fucker|shit|damn|shut up|bitch) [*]",
      "I am sorry" => "[*] (sorry|apologize|apology) [*]",
      "qwerty asdf" => "*"
    }.each do |message, trigger|
      assert_trigger(message, trigger)
    end
  end

  # These more-specific triggers are shadowed by "[*] you *" in sort order
  # (same behavior as rivescript-js). Still exercise the winning pattern.
  def test_you_star_shadow_group
    [
      "You remember cats",
      "Are you tall",
      "You are tall",
      "You hate me",
      "Can you swim"
    ].each do |message|
      assert_trigger(message, "[*] you *")
    end
  end

  def test_star_capture_appears_in_common_replies
    text = reply("I remember childhood")
    assert_match(/childhood/i, text)

    text = reply("I want a vacation")
    assert_match(/vacation/i, text)

    text = reply("I am sad")
    assert_match(/sad/i, text)
  end
end
