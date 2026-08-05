# frozen_string_literal: true

require_relative "helper"

# Thorough coverage for eg/brain/{begin,myself,clients,admin}.rive
# Eliza is covered in test_eliza_brain.rb; RPG in test_rpg_brain.rb.
class TestEgBrain < Minitest::Test
  def setup
    @bot = RiveScript.new(concat: "newline")
    @bot.load_directory(RiveScript.brain_path)
    @bot.sort_replies
    @user = "localuser" # matches ! var master in begin.rive
  end

  def reply(message, user = @user)
    @bot.reply(user, message)
  end

  def assert_one_of(message, expected_list, user = @user)
    text = reply(message, user)
    assert_includes expected_list, text,
                    "reply(#{message.inspect})=#{text.inspect} not in #{expected_list.inspect}"
    text
  end

  def assert_matched(message, pattern = nil, user = @user)
    text = reply(message, user)
    refute_equal "ERR: No Reply Matched", text, message
    refute text.to_s.strip.empty?, message
    assert_match(pattern, text, message) if pattern
    text
  end

  # --- inventory of brain files --------------------------------------------

  def test_all_brain_files_are_present
    %w[begin.rive clients.rive myself.rive eliza.rive admin.rive rpg.rive].each do |name|
      assert File.file?(File.join(RiveScript.brain_path, name)), "missing #{name}"
    end
  end

  # --- begin.rive -----------------------------------------------------------

  def test_begin_allows_normal_replies
    assert_matched("Hello")
  end

  def test_begin_bot_variables_are_loaded
    {
      "name" => "Aiden",
      "fullname" => "Aiden Rive",
      "age" => "5",
      "birthday" => "October 12",
      "sex" => "male",
      "location" => "Michigan",
      "city" => "Detroit",
      "eyes" => "blue",
      "hair" => "light brown",
      "hairlen" => "short",
      "color" => "blue",
      "band" => "Nickelback",
      "book" => "Myst",
      "author" => "Stephen King",
      "job" => "robot",
      "website" => "www.rivescript.com",
      "master" => "localuser"
    }.each do |name, expected|
      assert_equal expected, @bot.get_variable(name).to_s, name
    end
  end

  def test_begin_arrays_are_loaded
    arrays = @bot._array
    assert_includes arrays["malenoun"], "man"
    assert_includes arrays["femalenoun"], "woman"
    assert_includes arrays["colors"], "blue"
    assert_includes arrays["yes"], "yeah"
    assert_includes arrays["no"], "nope"
  end

  def test_begin_substitutions_and_person_maps
    assert_equal "what is", @bot._sub["what's"]
    assert_equal "i am", @bot._sub["i'm"]
    assert_equal "you are", @bot._person["i am"]
    assert_equal "my", @bot._person["your"]

    assert_match(/Aiden/, reply("What's your name?"))
    assert_match(/Aiden/, reply("Who are you?"))
    assert_match(/Aiden/, reply("Who is this?"))
  end

  # --- myself.rive ----------------------------------------------------------

  def test_myself_name_aliases_and_redirect
    assert_one_of("What is your name?", ["I am Aiden.", "You can call me Aiden."])
    assert_equal "5/male/Michigan", reply("asl")
    assert_equal "Yes?", reply("Aiden")
    # <bot name> * redirects the remainder through the brain
    assert_equal "Yes? 5/male/Michigan", reply("Aiden asl")
  end

  def test_myself_every_profile_trigger
    assert_one_of("How old are you?", ["I'm 5 years old.", "I'm 5."])
    assert_equal "I'm a male.", reply("Are you a man or a woman?")
    assert_equal "I'm a male.", reply("Are you male or female?")
    assert_equal "I'm from Michigan.", reply("Where are you?")
    assert_equal "I'm from Michigan.", reply("Where are you from?")
    assert_equal "I'm from Michigan.", reply("Where do you live?")
    assert_equal "I'm in Detroit.", reply("What city are you from?")
    assert_equal "I'm in Detroit.", reply("What town do you live in?")
    assert_equal "Definitely blue.", reply("What is your favorite color?")
    assert_equal "I like Nickelback the most.", reply("What is your favorite band?")
    assert_equal "The best book I've read was Myst.", reply("What is your favorite book?")
    assert_equal "I'm a robot.", reply("What is your occupation?")
    assert_equal "I'm a robot.", reply("What do you do?")
    assert_equal "www.rivescript.com", reply("Where is your website?")
    assert_equal "www.rivescript.com", reply("Where is your web site?")
    assert_equal "www.rivescript.com", reply("Where is your site?")
    assert_one_of("What color are your eyes?", ["I have blue eyes.", "Blue.", "blue."])
    assert_equal "I have blue eyes and short light brown hair.", reply("What do you look like?")
    assert_equal "Stephen King.", reply("Who is your favorite author?")
    assert_equal "localuser.", reply("Who is your master?")
  end

  # --- clients.rive ---------------------------------------------------------

  def test_clients_name_variants
    text = reply("My name is Alice")
    assert_match(/Alice/, text)
    assert_match(/nice to meet you/i, text)
    assert_equal "Alice", @bot.get_uservar(@user, "name")
    assert_match(/Alice/, reply("What is my name?"))
    assert_match(/Alice/, reply("Who am I?"))
    assert_match(/Alice/, reply("Do you know my name?"))
    assert_match(/Alice/, reply("Do you know who I am?"))

    called = reply("Call me Bob")
    assert_equal "Bob, I will call you that from now on.", called
    assert_equal "Bob", @bot.get_uservar(@user, "name")
  end

  def test_clients_master_and_bot_name
    master = reply("My name is localuser")
    assert_equal "That's my master's name too.", master
    assert_equal "localuser", @bot.get_uservar(@user, "name")

    # fresh user for bot-name coincidence
    text = reply("My name is Aiden", "someone")
    assert_match(/my name too/i, text)
    assert_equal "Aiden", @bot.get_uservar("someone", "name")
  end

  def test_clients_age_sex_location_favorites
    age_set = reply("I am 30 years old")
    assert_match(/30|I'm 5 myself/, age_set)
    assert_equal "30", @bot.get_uservar(@user, "age").to_s
    assert_match(/\b30\b/, reply("How old am I?"))
    assert_match(/\b30\b/, reply("Do you know how old I am?"))
    assert_match(/\b30\b/, reply("Do you know my age?"))

    assert_equal "Alright, you're a man.", reply("I am a man")
    assert_equal "male", @bot.get_uservar(@user, "sex")
    assert_equal "You're a male.", reply("Am I a man or a woman?")
    assert_equal "You're a male.", reply("Am I male or female?")

    assert_equal "Alright, you're female.", reply("I am a woman", "her")
    assert_equal "female", @bot.get_uservar("her", "sex")

    assert_equal "I've spoken to people from Tokyo before.", reply("I live in tokyo")
    assert_equal "Tokyo", @bot.get_uservar(@user, "location")
    assert_equal "I've spoken to people from Paris before.", reply("I am from paris", "traveler")
    assert_equal "Paris", @bot.get_uservar("traveler", "location")

    assert_equal "Why is it your favorite?", reply("My favorite color is red")
    assert_equal "Your favorite color is red", reply("What is my favorite color?")
  end

  def test_clients_relationship_paths
    assert_equal "I am too.", reply("I am single")
    assert_equal "nobody", @bot.get_uservar(@user, "spouse")
    assert_equal "single", @bot.get_uservar(@user, "status")

    assert_equal "What's her name?", reply("I have a girlfriend", "g1")
    assert_equal "That's a pretty name.", reply("Betty", "g1")
    assert_equal "Betty", @bot.get_uservar("g1", "spouse")
    assert_equal "Betty", reply("Who is my girlfriend?", "g1")
    assert_equal "Betty", reply("Who is my spouse?", "g1")

    assert_equal "What's his name?", reply("I have a boyfriend", "b1")
    assert_equal "That's a cool name.", reply("Tom", "b1")
    assert_equal "Tom", @bot.get_uservar("b1", "spouse")
    assert_equal "Tom", reply("Who is my boyfriend?", "b1")

    # Trigger is: my (girlfriend|boyfriend)* name is *
    # <set spouse=<formal>> uses the first star (role word), as authored.
    assert_equal "That's a nice name.", reply("My girlfriend x name is Sue", "g2")
    assert_equal "Girlfriend", @bot.get_uservar("g2", "spouse")
    assert_equal "That's a nice name.", reply("My boyfriend x name is Dan", "b2")
    assert_equal "Boyfriend", @bot.get_uservar("b2", "spouse")
  end

  # --- admin.rive -----------------------------------------------------------

  def test_admin_shutdown_and_botmaster_only
    master = reply("shutdown", "localuser")
    assert_match(/Shutting down/, master)
    assert_match(/Object Not Found/, master)

    other = reply("shutdown", "stranger")
    assert_equal(
      "This command can only be used by my botmaster. stranger != localuser",
      other
    )

    assert_equal(
      "This command can only be used by my botmaster. stranger != localuser",
      reply("botmaster only", "stranger")
    )
  end
end
