# frozen_string_literal: true

# RiveScript Ruby port
# Byte <byte@jvmlab.org>, https://jvmlab.org/
# MIT License

require_relative "rivescript/version"
require_relative "rivescript/utils"
require_relative "rivescript/sessions"
require_relative "rivescript/parser"
require_relative "rivescript/brain"
require_relative "rivescript/sorting"
require_relative "rivescript/inheritance"
require_relative "rivescript/lang/ruby"

# RiveScript interpreter for Ruby.
#
# Create a new instance with optional configuration:
#
#   bot = RiveScript.new(debug: true, utf8: true)
#   bot.load_directory("brain")
#   bot.sort_replies
#   reply = bot.reply("user", "hello")
class RiveScript
  attr_accessor :unicode_punctuation, :errors
  attr_reader :_strict, :_utf8, :_depth, :_force_case, :_concat, :_case_sensitive,
              :_global, :_var, :_sub, :_submax, :_person, :_personmax, :_array,
              :_session, :_includes, :_inherits, :_handlers, :_objlangs, :_topics,
              :_thats, :_sorted, :parser, :brain

  alias _forceCase _force_case

  # Gem / checkout root (directory that contains lib/ and eg/).
  def self.root
    File.expand_path("..", __dir__)
  end

  # Path to the bundled sample brain shipped with the gem.
  #
  #   bot = RiveScript.new
  #   bot.load_directory(RiveScript.brain_path)
  #   bot.sort_replies
  def self.brain_path
    File.join(root, "eg", "brain")
  end

  # @param opts [Hash] configuration options
  # @option opts [Boolean] :debug debug mode (default false)
  # @option opts [Integer] :depth recursion depth limit (default 50)
  # @option opts [Boolean] :strict strict mode (default true)
  # @option opts [Boolean] :utf8 enable UTF-8 mode (default false)
  # @option opts [Boolean] :force_case force-lowercase triggers (default false)
  # @option opts [Proc] :on_debug custom debug log handler
  # @option opts [String] :concat global concatenation mode override
  # @option opts [RiveScript::SessionManager] :session_manager custom session store
  # @option opts [Boolean] :case_sensitive preserve user message capitalization
  # @option opts [Boolean] :enable_object_macros register the default Ruby object
  #   macro handler (default true). Set to +false+ to disable executing Ruby
  #   object macros defined in RiveScript source.
  # @option opts [Regexp] :unicode_punctuation punctuation regexp for UTF-8 mode
  # @option opts [Hash] :errors customized error messages
  def initialize(opts = {})
    opts = {} if opts.nil?

    @_debug = opts.fetch(:debug, false)
    @_strict = opts.fetch(:strict, true)
    @_depth = opts.key?(:depth) ? opts[:depth].to_i : 50
    @_utf8 = opts.fetch(:utf8, false)
    @_force_case = opts.fetch(:force_case, false)
    @on_debug = opts[:on_debug]
    @_concat = opts[:concat]
    @_case_sensitive = opts.fetch(:case_sensitive, false)

    @unicode_punctuation = opts.fetch(:unicode_punctuation, /[.,!?;:]/)

    @errors = {
      "replyNotMatched" => "ERR: No Reply Matched",
      "replyNotFound" => "ERR: No Reply Found",
      "objectNotFound" => "[ERR: Object Not Found]",
      "deepRecursion" => "ERR: Deep Recursion Detected"
    }
    if opts[:errors].is_a?(Hash)
      opts[:errors].each do |key, value|
        @errors[key.to_s] = value
      end
    end

    @runtime = runtime

    @parser = Parser.new(self)
    @brain = Brain.new(self)

    @_pending = []
    @_load_count = 0

    @_global = {}
    @_var = {}
    @_sub = {}
    @_submax = 1
    @_person = {}
    @_personmax = 1
    @_array = {}
    @_session = opts[:session_manager]
    @_includes = {}
    @_inherits = {}
    @_handlers = {}
    @_objlangs = {}
    @_topics = {}
    @_thats = {}
    @_sorted = {}

    @_session = MemorySessionManager.new if @_session.nil?

    @_handlers["ruby"] = Lang::RubyHandler.new(self) unless opts[:enable_object_macros] == false
    say("RiveScript Interpreter v#{VERSION} Initialized.")
    say("Runtime Environment: #{@runtime}")
  end

  # Returns the version number of the RiveScript Ruby library.
  def version
    VERSION
  end

  # Load a RiveScript document from one or more files.
  def load_file(path)
    paths = path.is_a?(Array) ? path : [path]

    paths.each do |file|
      say("Request to load file: #{file}")
      data = File.read(file)
      ok = parse(file, data)
      raise "parser error" unless ok
    end

    true
  end

  # Load RiveScript documents from a directory recursively.
  def load_directory(path)
    raise "#{path} is not a directory" unless File.directory?(path)

    say("Loading from directory #{path}")
    files = Dir.glob(File.join(path, "**", "*.{rive,rs}"), File::FNM_CASEFOLD)
    load_file(files)
  end

  # Load RiveScript source code from a string.
  # Returns true if the code parsed with no error.
  def stream(code, on_error = nil)
    parse("stream()", code, on_error)
  end

  # Parse RiveScript code and load it into memory.
  def parse(filename, code, on_error = nil)
    say("Parsing code!")

    ok = true
    error_handler = lambda do |err, fn, ln|
      on_error&.call(err, fn, ln)
      ok = false
    end
    ast = @parser.parse(filename, code, error_handler)

    ast["begin"].each do |type, vars|
      internal = :"@_#{type}"
      max_key = :"@_#{type}max"

      vars.each do |name, value|
        if %w[sub person].include?(type)
          instance_variable_set(max_key, [instance_variable_get(max_key), name.split(" ").length].max)
        end

        target = instance_variable_get(internal)
        if value == "<undef>"
          target.delete(name)
        else
          target[name] = value
        end
      end
    end

    @_debug = @_global["debug"] == "true" if @_global.key?("debug")
    if @_global.key?("depth")
      parsed_depth = @_global["depth"].to_i
      @_depth = parsed_depth.zero? ? 50 : parsed_depth
    end

    ast["topics"].each do |topic, data|
      @_includes[topic] ||= {}
      @_inherits[topic] ||= {}
      Utils.extend(@_includes[topic], data["includes"])
      Utils.extend(@_inherits[topic], data["inherits"])

      @_topics[topic] ||= []
      data["triggers"].each do |trigger|
        @_topics[topic] << trigger

        next if trigger["previous"].nil?

        @_thats[topic] ||= {}
        @_thats[topic][trigger["trigger"]] ||= {}
        @_thats[topic][trigger["trigger"]][trigger["previous"]] = trigger
      end
    end

    ast["objects"].each do |object|
      language = object["language"]
      next unless @_handlers[language]

      @_objlangs[object["name"]] = language
      @_handlers[language].load(object["name"], object["code"])
    end

    ok
  end

  # Populate sort buffers after loading RiveScript code.
  def sort_replies
    @_sorted = { "topics" => {}, "thats" => {} }
    say("Sorting triggers...")

    @_topics.each_key do |topic|
      say("Analyzing topic #{topic}...")

      all_triggers = Inheritance.get_topic_triggers(self, topic)
      @_sorted["topics"][topic] = Sorting.sort_trigger_set(all_triggers, true)

      that_triggers = Inheritance.get_topic_triggers(self, topic, true)
      @_sorted["thats"][topic] = Sorting.sort_trigger_set(that_triggers, false)
    end

    @_sorted["sub"] = Sorting.sort_list(@_sub.keys)
    @_sorted["person"] = Sorting.sort_list(@_person.keys)
    @_sorted
  end

  # Translate the in-memory brain into a JSON-serializable structure.
  def deparse
    result = {
      "begin" => {
        "global" => Utils.clone(@_global),
        "var" => Utils.clone(@_var),
        "sub" => Utils.clone(@_sub),
        "person" => Utils.clone(@_person),
        "array" => Utils.clone(@_array),
        "triggers" => []
      },
      "topics" => Utils.clone(@_topics),
      "inherits" => Utils.clone(@_inherits),
      "includes" => Utils.clone(@_includes),
      "objects" => {}
    }

    @_handlers.each do |key, handler|
      next unless handler.respond_to?(:objects)

      entry = { "_objects" => Utils.clone(handler.objects) }
      entry["_sources"] = Utils.clone(handler.sources) if handler.respond_to?(:sources)
      result["objects"][key] = entry
    end

    if result["topics"]["__begin__"]
      result["begin"]["triggers"] = result["topics"].delete("__begin__")
    end

    result["begin"]["global"]["debug"] = @_debug if @_debug
    result["begin"]["global"]["depth"] = @_depth if @_depth != 50

    result
  end

  # Translate the in-memory brain back into RiveScript source code.
  def stringify(deparsed = nil)
    @parser.stringify(deparsed || deparse)
  end

  # Write the in-memory RiveScript data into a text file.
  def write(filename, deparsed = nil)
    File.write(filename, stringify(deparsed))
  end

  # Set a custom language handler for object macros.
  # Omit +obj+ to remove the handler; pass +nil+ to disable it explicitly.
  def set_handler(lang, obj = :__unset__)
    if obj == :__unset__
      @_handlers.delete(lang)
    else
      @_handlers[lang] = obj
    end
  end

  # Define a Ruby object macro from your program.
  def set_subroutine(name, code = nil, &block)
    code ||= block
    return unless @_handlers["ruby"]
    return if code.nil?

    @_objlangs[name] = "ruby"
    @_handlers["ruby"].load(name, code)
  end

  # Set a global variable (! global).
  def set_global(name, value = :__unset__)
    if value == :__unset__
      @_global.delete(name)
    else
      @_global[name] = value
    end
  end

  # Set a bot variable (! var).
  def set_variable(name, value = :__unset__)
    if value == :__unset__
      @_var.delete(name)
    else
      @_var[name] = value
    end
  end

  # Set a substitution (! sub).
  def set_substitution(name, value = :__unset__)
    if value == :__unset__
      @_sub.delete(name)
    else
      @_submax = [name.split(" ").length, @_submax].max
      @_sub[name] = value
    end
  end

  # Set a person substitution (! person).
  def set_person(name, value = :__unset__)
    if value == :__unset__
      @_person.delete(name)
    else
      @_personmax = [name.split(" ").length, @_personmax].max
      @_person[name] = value
    end
  end

  # Set a user variable.
  def set_uservar(user, name, value)
    value = value.downcase if name == "topic" && @_force_case

    @_session.set(user, { name => value })
  end

  # Set multiple user variables at once.
  def set_uservars(user, data)
    @_session.set(user, data)
  end

  # Get a bot variable (<bot name>).
  def get_variable(name)
    @_var.key?(name) ? @_var[name] : "undefined"
  end

  # Get a user variable.
  def get_uservar(user, name)
    @_session.get(user, name)
  end

  # Get all variables about a user, or all users if +user+ is omitted.
  def get_uservars(user = nil)
    if user.nil?
      @_session.get_all
    else
      @_session.get_any(user)
    end
  end

  # Clear user variables for one user, or all users if +user+ is omitted.
  def clear_uservars(user = nil)
    if user.nil?
      @_session.reset_all
    else
      @_session.reset(user)
    end
  end

  # Freeze the variable state of a user.
  def freeze_uservars(user)
    @_session.freeze(user)
  end

  # Thaw a user's frozen variables.
  def thaw_uservars(user, action = "thaw")
    @_session.thaw(user, action)
  end

  # Retrieve the trigger the user matched most recently.
  def last_match(user)
    @_session.get(user, "__lastmatch__")
  end

  # Retrieve the trigger the user matched initially for the last reply.
  def initial_match(user)
    @_session.get(user, "__initialmatch__")
  end

  # Retrieve all triggers matched for the last reply.
  def last_triggers(user)
    @_session.get(user, "__last_triggers__")
  end

  # Retrieve triggers in the current topic for the specified user.
  def get_user_topic_triggers(user)
    topic = @_session.get(user, "topic")
    Inheritance.get_topic_triggers(self, topic)
  end

  # Retrieve the current user's ID (only valid inside object macros).
  def current_user
    if @brain.current_user.nil?
      warn("currentUser() is intended to be called from within a Ruby object macro!")
    end
    @brain.current_user
  end

  # Fetch a reply from the RiveScript brain.
  def reply(user, msg, scope = nil)
    @brain.reply(user, msg, scope)
  end

  # Deprecated alias for reply.
  def reply_async(user, msg, scope = nil, &block)
    warn("DEPRECATED FUNCTION: RiveScript#reply_async is deprecated; use reply instead")
    result = reply(user, msg, scope)
    block&.call(nil, result)
    result
  end

  # Debug logger.
  def say(message)
    return unless @_debug

    if @on_debug
      @on_debug.call(message)
    else
      $stdout.puts(message)
    end
  end

  # Warning/error logger.
  def warn(message, filename = nil, lineno = nil)
    message = "#{message} at #{filename} line #{lineno}" if filename && lineno
    formatted = "[WARNING] #{message}"

    if @on_debug
      @on_debug.call(formatted)
    else
      $stderr.puts(formatted)
    end
  end

  private

  def runtime
    "ruby"
  end
end
