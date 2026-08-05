# frozen_string_literal: true

require_relative "helper"

# Thorough integration coverage for eg/brain/rpg.rive
class TestRpgBrain < Minitest::Test
  def setup
    @bot = RiveScript.new(concat: "newline")
    @bot.load_file(File.join(RiveScript.brain_path, "rpg.rive"))
    @bot.sort_replies
    @user = "rpguser"
  end

  def reply(message)
    @bot.reply(@user, message)
  end

  def topic
    @bot.get_uservar(@user, "topic")
  end

  def start_game!
    reply("rpg demo")
  end

  def go_to_mars!
    start_game!
    reply("n")
    reply("up")
    reply("north")
    reply("push button")
  end

  def go_to_crashsite!
    go_to_mars!
    reply("take spacesuit")
    reply("open door")
  end

  def test_rpg_file_is_present
    assert File.file?(File.join(RiveScript.brain_path, "rpg.rive"))
  end

  def test_enter_lobby_and_earth_world_triggers
    text = start_game!
    assert_includes text, "You're now playing the game"
    assert_includes text, "NASA launch base on Earth"
    assert_includes text, "elevator to the north"
    assert_equal "nasa_lobby", topic

    assert_includes reply("look"), "NASA launch base on Earth"
    assert_includes reply("exits"), "elevator to the north"
    assert_equal "There is plenty of oxygen here so breathing is easy!", reply("breathe")
    assert_equal "You are on planet Earth right now.", reply("what world am i on")
    assert_equal "You are on planet Earth right now.", reply("what world is this")
  end

  def test_global_help_inventory_and_unknown
    start_game!
    help = reply("help")
    assert_includes help, "look:"
    assert_includes help, "inventory:"
    assert_includes help, "exit:"

    assert_equal "Your inventory: undefined", reply("inventory")
    assert_equal "I'm not sure what you're trying to do.", reply("xyzzy")
    assert_equal 'You don\'t need to use the word "the" in this game.', reply("the key")
  end

  def test_blocked_directions_fall_back_to_global
    start_game!
    %w[south east west up down].each do |dir|
      assert_equal "You can't go in that direction.", reply(dir), dir
    end
  end

  def test_north_substitution_alias
    start_game!
    assert_includes reply("n"), "elevator that leads to the rocket"
    assert_equal "elevator", topic
  end

  def test_earth_path_elevator_walkway_rocket_and_back
    start_game!

    elev = reply("north")
    assert_includes elev, "elevator that leads to the rocket"
    assert_equal "elevator", topic
    assert_includes reply("look"), "elevator that leads to the rocket"
    exits = reply("exits")
    assert_includes exits, "Up: the path to the rocket"
    assert_includes exits, "Down: the NASA lobby"

    lobby = reply("down")
    assert_includes lobby, "NASA launch base"
    assert_equal "nasa_lobby", topic

    reply("north")
    walk = reply("up")
    assert_includes walk, "walkway that leads to the rocket"
    assert_equal "walkway", topic
    assert_includes reply("exits"), "rocket is to the north"

    elev2 = reply("south")
    assert_equal "elevator", topic
    assert_includes elev2, "elevator that leads to the rocket"

    reply("up")
    rocket = reply("north")
    assert_includes rocket, "You are on the rocket"
    assert_equal "rocket", topic
    assert_includes reply("exits"), "walkway back to the NASA base"

    walk2 = reply("south")
    assert_equal "walkway", topic
    assert_includes walk2, "walkway that leads to the rocket"
  end

  def test_press_button_lands_on_mars
    start_game!
    reply("north")
    reply("up")
    reply("north")

    mars = reply("press button")
    assert_includes mars, "crash-landed"
    assert_equal "crashed", topic
    assert_equal(
      "Thanks to your space suit you can breathe. There's no oxygen on this planet.",
      reply("breathe")
    )
    assert_equal "You are on planet Mars right now.", reply("what world am i on")
  end

  def test_spacesuit_gate_and_duplicate_wear
    go_to_mars!

    assert_includes reply("look"), "space suit"
    assert_includes reply("exits"), "door that leads outside"
    assert_includes reply("open door"), "you'll die"

    suit = reply("put on space suit")
    assert_includes suit, "You put on the space suit"
    assert_equal "1", @bot.get_uservar(@user, "spacesuit").to_s
    assert_equal "spacesuit", @bot.get_uservar(@user, "inventory")
    assert_equal "Your inventory: spacesuit", reply("inventory")

    assert_equal "You are already wearing the space suit.", reply("take suit")

    outside = reply("open door")
    assert_includes outside, "red Martian surface"
    assert_includes outside, "red dirt ground on Mars"
    assert_equal "crashsite", topic
  end

  def test_crashsite_desert_and_puzzle_solution_to_colony
    go_to_crashsite!
    assert_equal "crashsite", topic

    assert_includes reply("look"), "red dirt ground on Mars"
    assert_includes reply("exits"), "any direction"

    # east/west/south re-look via @ look
    assert_includes reply("east"), "red dirt ground on Mars"
    assert_equal "crashsite", topic
    assert_includes reply("west"), "red dirt ground on Mars"
    assert_includes reply("south"), "red dirt ground on Mars"

    # Puzzle: north, west, west, north
    p1 = reply("north")
    assert_includes p1, "looks different"
    assert_equal "puzzle1", topic
    assert_includes reply("look"), "looks different"

    # Wrong direction returns to crashsite via puzzle inheritance
    wrong = reply("east")
    assert_includes wrong, "red dirt ground on Mars"
    assert_equal "crashsite", topic

    reply("north")
    p2 = reply("west")
    assert_includes p2, "even more different"
    assert_equal "puzzle2", topic

    p3 = reply("west")
    assert_includes p3, "space colony nearby"
    assert_equal "puzzle3", topic

    entrance = reply("north")
    assert_includes entrance, "entrance to a space colony"
    assert_equal "entrance", topic
    assert_includes reply("exits"), "entrance to the space colony is to the north"

    airlock = reply("north")
    assert_includes airlock, "air lock"
    assert_equal "vaccuum", topic
    assert_includes reply("exits"), "inner part of the space colony"

    # south from airlock stays in airlock (as authored)
    assert_includes reply("south"), "air lock"
    assert_equal "vaccuum", topic

    colony = reply("north")
    assert_includes colony, "safely to the space colony"
    assert_equal "colony", topic
    assert_equal "There are no exits here.", reply("exits")
    assert_equal "This is the end of the game. There's nothing more to do.", reply("xyzzy")
    assert_includes reply("look"), "concludes the game"
  end

  def test_exit_resets_topic_and_inventory
    go_to_mars!
    reply("take spacesuit")
    logout = reply("exit")
    assert_includes logout, "Logging out of the game"
    assert_equal "random", topic
    assert_equal "undefined", @bot.get_uservar(@user, "inventory")
    assert_equal "0", @bot.get_uservar(@user, "spacesuit").to_s
  end

  def test_rpg_loads_with_full_bundled_brain
    bot = RiveScript.new(concat: "newline")
    bot.load_directory(RiveScript.brain_path)
    bot.sort_replies

    text = bot.reply("fullbrain", "rpg demo")
    assert_includes text, "You're now playing the game"
    assert_includes text, "NASA launch base on Earth"
    assert_equal "nasa_lobby", bot.get_uservar("fullbrain", "topic")
  end
end
