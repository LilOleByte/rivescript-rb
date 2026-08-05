# RiveScript Ruby port, https://jvmlab.org/, MIT License

# Brain logic for RiveScript

require_relative "utils"
require_relative "inheritance"

class RiveScript
  class Brain
    # Reply weights above this are clamped to prevent trivially-crafted
    # {weight=N} tags from ballooning the random-choice bucket.
    MAX_REPLY_WEIGHT = 10_000

    # Private-use-area token used to shield a fully-processed inner reply
    # from being tag-processed a second time when substituted into a BEGIN
    # block's {ok} placeholder.
    BEGIN_OK_TOKEN = "\uE000RIVE_OK\uE000"

    # Simple text-transform tags that are allowed to wrap {ok} in a BEGIN
    # block (e.g. "{uppercase}{ok}{/uppercase}"). These are resolved against
    # the already-processed inner reply directly (bypassing the tag engine)
    # so the wrapping author's intent is preserved without re-running the
    # full tag processor (with its side-effecting tags) over user-influenced
    # reply text a second time.
    BEGIN_OK_FORMAT_TAGS = %w[person formal sentence uppercase lowercase].freeze

    def self.parse_int_js(str)
      m = str.to_s.strip.match(/\A[-+]?\d+/)
      m ? m[0].to_i : nil
    end

    # Splits "name=value" assignment data on the first "=" only, so that
    # values which themselves contain "=" are preserved intact.
    def self.split_assignment(data)
      data.to_s.split("=", 2)
    end

    TAGS = {
      "bot" => {
        "self_closing" => true,
        "handle" => lambda { |rive, data, _user, _scope|
          vars = rive._var
          split = Brain.split_assignment(data)
          if split.length > 1
            vars[split[0].strip] = split[1]
            ""
          elsif split.length == 1
            val = vars[split[0].strip]
            val = "undefined" if val.nil?
            val
          else
            "undefined"
          end
        }
      },
      "env" => {
        "self_closing" => true,
        "handle" => lambda { |rive, data, _user, _scope|
          globals = rive._global
          split = Brain.split_assignment(data)
          if split.length > 1
            globals[split[0].strip] = split[1]
            ""
          elsif split.length == 1
            val = globals[split[0].strip]
            val = "undefined" if val.nil?
            val
          else
            "undefined"
          end
        }
      },
      "set" => {
        "self_closing" => true,
        "handle" => lambda { |rive, data, user, _scope|
          split = Brain.split_assignment(data)
          rive.set_uservar(user, split[0].strip, split[1]) if split.length > 1
          ""
        }
      },
      "get" => {
        "self_closing" => true,
        "handle" => lambda { |rive, data, user, _scope|
          rive.get_uservar(user, data.strip)
        }
      },
      "add" => {
        "self_closing" => true,
        "handle" => lambda { |rive, data, user, _scope|
          split = Brain.split_assignment(data)
          name = split[0].strip
          raw_value = split[1]
          existing_value = rive.get_uservar(user, name) || 0
          existing_value = 0 if existing_value == "undefined"
          value = raw_value.nil? ? nil : Brain.parse_int_js(raw_value.strip)
          existing_number = Brain.parse_int_js(existing_value.to_s)
          if value.nil?
            return "[ERR: Math can't 'add' non-numeric value '#{raw_value}']"
          elsif existing_number.nil?
            return "[ERR: Math can't 'add' non-numeric user variable '#{name}']"
          else
            result = existing_number + value
            rive.set_uservar(user, name, result)
          end
          ""
        }
      },
      "sub" => {
        "self_closing" => true,
        "handle" => lambda { |rive, data, user, _scope|
          split = Brain.split_assignment(data)
          name = split[0].strip
          raw_value = split[1]
          existing_value = rive.get_uservar(user, name) || 0
          value = raw_value.nil? ? nil : Brain.parse_int_js(raw_value.strip)
          existing_value = 0 if existing_value == "undefined"
          existing_number = Brain.parse_int_js(existing_value.to_s)
          if value.nil?
            return "[ERR: Math can't 'sub' non-numeric value '#{raw_value}']"
          elsif existing_number.nil?
            return "[ERR: Math can't 'sub' non-numeric user variable '#{name}']"
          else
            result = existing_number - value
            rive.set_uservar(user, name, result)
          end
          ""
        }
      },
      "mult" => {
        "self_closing" => true,
        "handle" => lambda { |rive, data, user, _scope|
          split = Brain.split_assignment(data)
          name = split[0].strip
          raw_value = split[1]
          existing_value = rive.get_uservar(user, name) || 0
          value = raw_value.nil? ? nil : Brain.parse_int_js(raw_value.strip)
          existing_value = 0 if existing_value == "undefined"
          existing_number = Brain.parse_int_js(existing_value.to_s)
          if value.nil?
            return "[ERR: Math can't 'mult' non-numeric value '#{raw_value}']"
          elsif existing_number.nil?
            return "[ERR: Math can't 'mult' non-numeric user variable '#{name}']"
          else
            result = existing_number * value
            rive.set_uservar(user, name, result)
          end
          ""
        }
      },
      "div" => {
        "self_closing" => true,
        "handle" => lambda { |rive, data, user, _scope|
          split = Brain.split_assignment(data)
          name = split[0].strip
          raw_value = split[1]
          existing_value = rive.get_uservar(user, name) || 0
          value = raw_value.nil? ? nil : Brain.parse_int_js(raw_value.strip)
          existing_value = 0 if existing_value == "undefined"
          existing_number = Brain.parse_int_js(existing_value.to_s)
          if value.nil?
            return "[ERR: Math can't 'div' non-numeric value '#{raw_value}']"
          elsif existing_number.nil?
            return "[ERR: Math can't 'div' non-numeric user variable '#{name}']"
          elsif value == 0
            return "[ERR: Can't Divide By Zero]"
          else
            result = existing_number.fdiv(value)
            result = result.to_i if result == result.to_i
            rive.set_uservar(user, name, result)
          end
          ""
        }
      },
      "call" => {
        "self_closing" => false,
        "handle" => lambda { |rive, data, _user, scope|
          trimmed = Utils.trim(data)
          m = trimmed.match(/\A(\S+)(?:\s+(.*))?\z/m)
          output = rive.errors["objectNotFound"]
          return output unless m

          obj = m[1]
          args = m[2] ? Utils.parse_call_args(m[2]) : []
          objlangs = rive._objlangs
          handlers = rive._handlers

          if objlangs.key?(obj)
            lang = objlangs[obj]
            if handlers[lang]
              begin
                output = handlers[lang].call(rive, obj, args, scope)
              rescue StandardError => e
                rive.brain.warn(e.message) unless e.nil?
                output = "[ERR: Error raised by object macro: #{e.message}]"
              end
            else
              output = "[ERR: No Object Handler]"
            end
          end
          output
        }
      }
    }.freeze

    def initialize(master)
      @master = master
      @strict = master._strict
      @utf8 = master._utf8
      @mutex = Mutex.new
    end

    # The user ID currently being processed by #reply (only meaningful from
    # within object macros invoked during a reply). Stored per-thread so
    # concurrent calls to #reply from different threads don't clobber
    # each other's notion of "the current user".
    def current_user
      Thread.current[:rivescript_current_user]
    end

    def say(message)
      @master.send(:say, message)
    end

    def warn(message, filename = nil, lineno = nil)
      @master.warn(message, filename, lineno)
    end

    def reply(user, msg, scope = nil)
      @mutex.synchronize do
        say("Asked to reply to [#{user}] #{msg}")

        Thread.current[:rivescript_current_user] = user
        msg = format_message(msg)
        reply = ""

        bot_session.set(user, { "__initialmatch__" => nil })

        if bot_topics["__begin__"]
          begin_reply = get_reply(user, "request", "begin", 0, scope)

          if begin_reply.include?("{ok}")
            inner_reply = get_reply(user, msg, "normal", 0, scope)
            ok_replacement = inner_reply

            BEGIN_OK_FORMAT_TAGS.each do |type|
              wrap_pattern = /\{#{type}\}\{ok\}\{\/#{type}\}/i
              next unless begin_reply.match?(wrap_pattern)

              ok_replacement = type == "person" ? substitute(inner_reply, "person") : Utils.string_format(type, inner_reply)
              begin_reply = begin_reply.gsub(wrap_pattern, BEGIN_OK_TOKEN)
            end

            begin_reply = begin_reply.gsub("{ok}", BEGIN_OK_TOKEN)
            reply = process_tags(user, msg, begin_reply, [], [], 0, scope)
            reply = reply.gsub(BEGIN_OK_TOKEN, ok_replacement)
          else
            reply = process_tags(user, msg, begin_reply, [], [], 0, scope)
          end
        else
          reply = get_reply(user, msg, "normal", 0, scope)
        end

        history = bot_session.get(user, "__history__")
        history = new_history if history == "undefined"
        begin
          history["input"].pop
          history["input"].unshift(msg)
          # Keep %previous intact when nothing matched / no reply was found.
          # Otherwise ERR strings overwrite history.reply[0] and short
          # conversations cannot continue (aichaos/rivescript-js#411).
          unless error_reply?(reply)
            history["reply"].pop
            history["reply"].unshift(reply)
          end
        rescue StandardError
          history = new_history
        end
        bot_session.set(user, { "__history__" => history })

        reply
      end
    ensure
      Thread.current[:rivescript_current_user] = nil
    end

    def format_message(msg, botreply = nil)
      msg = msg.to_s
      msg = msg.downcase unless case_sensitive?

      msg = substitute(msg, "sub")

      if @utf8
        msg = msg.gsub(/[\\<>]+/, "")

        if !@master.unicode_punctuation.nil?
          msg = msg.gsub(@master.unicode_punctuation, "")
        end

        if !botreply.nil?
          msg = msg.gsub(/[.?,!;:@#$%^&*()]/, "")
        end
      else
        msg = Utils.strip_nasties(msg, @utf8)
      end

      msg.strip.gsub(/\s+/, " ")
    end

    def trigger_regexp(user, regexp)
      regexp = regexp.gsub(/^\*$/, "<zerowidthstar>")
      regexp = regexp.gsub("*", "(.+?)")
      regexp = regexp.gsub("#", "(\\d+?)")
      regexp = regexp.gsub("_", "(\\w+?)")
      regexp = regexp.gsub(/\s*\{weight=\d+\}\s*/i, "")
      regexp = regexp.gsub("<zerowidthstar>", "(.*?)")
      regexp = regexp.gsub(/\|{2,}/, "|")
      regexp = regexp.gsub(/(\(|\[)\|/, '\1')
      regexp = regexp.gsub(/\|(\)|\])/, '\1')

      if @utf8
        regexp = regexp.gsub("\\@", "\\u0040")
      end

      giveup = 0
      while (match = regexp.match(/\[(.+?)\]/))
        if (giveup += 1) > 50
          warn("Infinite loop when trying to process optionals in a trigger!")
          return ""
        end

        parts = match[1].split("|")
        opts = parts.map { |p| "(?:\\s|\\b)+#{p}(?:\\s|\\b)+" }

        pipes = opts.join("|")
        pipes = pipes.gsub(Regexp.new(Regexp.escape("(.+?)")), "(?:.+?)")
        pipes = pipes.gsub(Regexp.new(Regexp.escape("(\\d+?)")), "(?:\\d+?)")
        pipes = pipes.gsub(Regexp.new(Regexp.escape("(\\w+?)")), "(?:\\w+?)")
        pipes = pipes.gsub("[", "__lb__").gsub("]", "__rb__")
        regexp = regexp.sub(
          Regexp.new("\\s*\\[#{Regexp.escape(match[1])}\\]\\s*"),
          "(?:#{pipes}|(?:\\b|\\s)+)"
        )
      end

      regexp = regexp.gsub("__lb__", "[").gsub("__rb__", "]")
      regexp = regexp.gsub("\\w", "[^\\s\\d]")

      giveup = 0
      while regexp.include?("@")
        if (giveup += 1) > 50
          break
        end
        if (match = regexp.match(/@(.+?)\b/))
          name = match[1]
          rep = ""
          arrays = bot_array
          if arrays[name] && !arrays[name].empty?
            rep = "(?:" + arrays[name].map { |item| Utils.quotemeta(item) }.join("|") + ")"
          end
          regexp = regexp.sub(/@#{Regexp.escape(name)}\b/, rep)
        end
      end

      giveup = 0
      while regexp.include?("<bot")
        if (giveup += 1) > 50
          break
        end
        if (match = regexp.match(/<bot (.+?)>/i))
          name = match[1]
          rep = ""
          vars = bot_var
          rep = Utils.quotemeta(Utils.strip_nasties(vars[name], @utf8).downcase) if vars[name]
          regexp = regexp.sub(/<bot #{Regexp.escape(name)}>/i, rep)
        end
      end

      giveup = 0
      while regexp.include?("<get")
        if (giveup += 1) > 50
          break
        end
        if (match = regexp.match(/<get (.+?)>/i))
          name = match[1]
          rep = @master.get_uservar(user, name)
          regexp = regexp.sub(/<get #{Regexp.escape(name)}>/i, Utils.quotemeta(rep.to_s.downcase))
        end
      end

      giveup = 0
      regexp = regexp.gsub(/<input>/i, "<input1>")
      regexp = regexp.gsub(/<reply>/i, "<reply1>")
      history = bot_session.get(user, "__history__")
      history = new_history if history == "undefined"
      while regexp.include?("<input") || regexp.include?("<reply")
        if (giveup += 1) > 50
          break
        end
        %w[input reply].each do |type|
          (1..9).each do |i|
            tag = "<#{type}#{i}>"
            next unless regexp.include?(tag)

            value = Utils.quotemeta(format_message(history[type][i - 1], type == "reply"))
            regexp = regexp.gsub(tag, value)
          end
        end
      end

      if @utf8 && regexp.include?("\\u")
        regexp = regexp.gsub(/\\u([A-Fa-f0-9]{4})/) { Regexp.last_match(1).to_i(16).chr(Encoding::UTF_8) }
      end

      regexp.gsub(/\|{2,}/m, "|")
    end

    def handle_tag(rive, user, content, scope, depth)
      tag = ""
      reminder = ""
      i = 0
      while i < content.length
        if TAGS.key?(tag)
          reminder = content[(i + 1)..]
          break
        elsif content[i] == " "
          reminder = content[(i + 1)..]
          break
        elsif content[i] == ">"
          reminder = content[(i + 1)..]
          return { "response" => "<#{tag}>", "reminder" => reminder }
        end
        tag += content[i]
        i += 1
      end

      tag_def = TAGS[tag]
      self_closing = tag_def ? tag_def["self_closing"] : true
      end_tag = self_closing ? ">" : "</#{tag}>"
      result = parse_complex_tags(rive, user, reminder, scope, depth, end_tag)
      reminder = result["reminder"]

      response = if tag_def && tag_def["handle"]
                   tag_def["handle"].call(rive, result["response"], user, scope)
                 else
                   "<#{tag} #{result["response"]}>"
                 end
      { "response" => response, "reminder" => reminder }
    end

    def parse_complex_tags(rive, user, content, scope, depth, end_tag = "")
      return { "response" => content, "reminder" => "" } if depth > 50

      response = ""
      reminder = content
      next_tag = reminder.index("<")
      next_end = end_tag.empty? ? reminder.length : (reminder.index(end_tag) || reminder.length)

      while !reminder.empty? && next_tag && next_tag < next_end
        response += reminder[0...next_tag]
        reminder = reminder[(next_tag + 1)..]
        result = handle_tag(rive, user, reminder, scope, depth + 1)
        response += result["response"].to_s
        reminder = result["reminder"].to_s
        next_tag = reminder.index("<")
        next_end = end_tag.empty? ? reminder.length : (reminder.index(end_tag) || reminder.length)
      end

      response += reminder[0...next_end].to_s
      reminder = reminder[(next_end + end_tag.length)..] || ""

      { "response" => response, "reminder" => reminder }
    end

    def process_tags(user, msg, reply, st, bst, step, scope)
      stars = [""]
      stars.concat(st)
      botstars = [""]
      botstars.concat(bst)
      stars.push("undefined") if stars.length == 1
      botstars.push("undefined") if botstars.length == 1

      giveup = 0
      while (match = reply.match(/\(@([A-Za-z0-9_]+)\)/i))
        if (giveup += 1) > bot_depth
          warn("Infinite loop looking for arrays in reply!")
          break
        end

        name = match[1]
        arrays = bot_array
        result = if arrays[name]
                   "{random}#{arrays[name].join("|")}{/random}"
                 else
                   "\x00@#{name}\x00"
                 end

        reply = reply.sub(/\(@#{Regexp.escape(name)}\)/i, result)
      end

      reply = reply.gsub(/\x00@([A-Za-z0-9_]+)\x00/, '(@\1)')

      reply = reply.gsub(/<person>/i, "{person}<star>{/person}")
      reply = reply.gsub(/<@>/i, "{@<star>}")
      reply = reply.gsub(/<formal>/i, "{formal}<star>{/formal}")
      reply = reply.gsub(/<sentence>/i, "{sentence}<star>{/sentence}")
      reply = reply.gsub(/<uppercase>/i, "{uppercase}<star>{/uppercase}")
      reply = reply.gsub(/<lowercase>/i, "{lowercase}<star>{/lowercase}")

      reply = reply.gsub(/\{weight=\d+\}/i, "")
      reply = reply.gsub(/<star>/i, stars[1].to_s)
      reply = reply.gsub(/<botstar>/i, botstars[1].to_s)
      (1...stars.length).each do |i|
        reply = reply.gsub(/<star#{i}>/i, stars[i].to_s)
      end
      (1...botstars.length).each do |i|
        reply = reply.gsub(/<botstar#{i}>/i, botstars[i].to_s)
      end

      history = bot_session.get(user, "__history__")
      history = new_history if history == "undefined"
      reply = reply.gsub(/<input>/i, history["input"] ? history["input"][0] : "undefined")
      reply = reply.gsub(/<reply>/i, history["reply"] ? history["reply"][0] : "undefined")
      (1..9).each do |i|
        reply = reply.gsub(/<input#{i}>/i, history["input"][i - 1]) if reply.include?("<input#{i}>")
        reply = reply.gsub(/<reply#{i}>/i, history["reply"][i - 1]) if reply.include?("<reply#{i}>")
      end

      reply = reply.gsub(/<id>/i, user)
      reply = reply.gsub(/\\s/i, " ")
      reply = reply.gsub(/\\n/i, "\n")
      reply = reply.gsub(/\\#/i, "#")

      giveup = 0
      while (match = reply.match(/\{random\}(.+?)\{\/random\}/i))
        if (giveup += 1) > bot_depth
          warn("Infinite loop looking for random tag!")
          break
        end

        text = match[1]
        random = text.include?("|") ? text.split("|") : text.split(" ")
        output = random[(rand * random.length).floor]
        reply = reply.sub(/\{random\}#{Regexp.escape(text)}\{\/random\}/i, output)
      end

      %w[person formal sentence uppercase lowercase].each do |type|
        giveup = 0
        while (match = reply.match(/\{#{type}\}(.+?)\{\/#{type}\}/i))
          giveup += 1
          if giveup >= 50
            warn("Infinite loop looking for #{type} tag!")
            break
          end

          content = match[1]
          replace = if type == "person"
                      substitute(content, "person")
                    else
                      Utils.string_format(type, content)
                    end

          reply = reply.sub(/\{#{type}\}#{Regexp.escape(content)}\{\/#{type}\}/i, replace)
        end
      end

      reply = parse_complex_tags(@master, user, reply, scope, 0)["response"]

      giveup = 0
      while (match = reply.match(/\{topic=(.+?)\}/i))
        giveup += 1
        if giveup >= 50
          warn("Infinite loop looking for topic tag!")
          break
        end

        name = match[1]
        @master.set_uservar(user, "topic", name)
        reply = reply.sub(/\{topic=#{Regexp.escape(name)}\}/i, "")
      end

      giveup = 0
      while (match = reply.match(/\{@([^\}]*?)\}/))
        giveup += 1
        if giveup >= 50
          warn("Infinite loop looking for redirect tag!")
          break
        end

        target = format_message(Utils.strip(match[1]))
        say("Inline redirection to: #{target}")

        subreply = get_reply(user, target, "normal", step + 1, scope)
        reply = reply.sub(/\{@#{Regexp.escape(match[1])}\}/i, subreply)
      end

      reply
    end

    def substitute(msg, type)
      sort_key = type == "sub" ? "sub" : "person"
      unless bot_sorted && bot_sorted[sort_key]
        @master.warn("You forgot to call sortReplies()!")
        return msg
      end

      subs = type == "sub" ? bot_sub : bot_person
      maxwords = type == "sub" ? bot_submax : bot_personmax
      result = ""

      pattern = if !@master.unicode_punctuation.nil?
                  msg.gsub(@master.unicode_punctuation, "")
                else
                  msg.gsub(/[.,!?;:]/, "")
                end

      giveup = 0
      subgiveup = 0

      while pattern.include?(" ")
        giveup += 1
        if giveup >= 1000
          warn("Too many loops when handling substitutions!")
          break
        end

        li = Utils.n_index_of(pattern, " ", maxwords)
        subpattern = pattern[0...li]

        result = subs[subpattern]
        if !result.nil?
          msg = msg.sub(subpattern, result)
        else
          while subpattern.include?(" ")
            subgiveup += 1
            if subgiveup >= 1000
              warn("Too many loops when handling substitutions!")
              break
            end

            li = subpattern.rindex(" ")
            subpattern = subpattern[0...li]

            result = subs[subpattern]
            if !result.nil?
              msg = msg.sub(subpattern, result)
              break
            end
          end
        end

        fi = pattern.index(" ")
        pattern = pattern[(fi + 1)..]
      end

      result = subs[pattern]
      msg = msg.sub(pattern, result) if !result.nil?

      msg
    end

    private

    def bot_session
      @master._session
    end

    def bot_sorted
      @master._sorted
    end

    def bot_topics
      @master._topics
    end

    def bot_thats
      @master._thats
    end

    def bot_var
      @master._var
    end

    def bot_array
      @master._array
    end

    def bot_sub
      @master._sub
    end

    def bot_person
      @master._person
    end

    def bot_submax
      @master._submax
    end

    def bot_personmax
      @master._personmax
    end

    def bot_depth
      @master._depth
    end

    def bot_includes
      @master._includes
    end

    def bot_inherits
      @master._inherits
    end

    def case_sensitive?
      @master._case_sensitive == true
    end

    # Attempts to match +subject+ against +regexp+ (the compiled form of
    # +pattern+). Atomic triggers are compared with plain string equality;
    # non-atomic triggers are matched case-insensitively unless the bot is
    # running in case-sensitive mode.
    #
    # Returns an array of captured stars on success (empty for an atomic
    # match), or +nil+ if there was no match.
    def trigger_match(subject, pattern, regexp)
      if Utils.is_atomic(pattern)
        subject == regexp ? [] : nil
      else
        m = subject.match(match_regexp(regexp))
        m ? m.to_a.drop(1) : nil
      end
    end

    def match_regexp(regexp)
      case_sensitive? ? /\A#{regexp}\z/ : /\A#{regexp}\z/i
    end

    def get_reply(user, msg, context, step, scope)
      unless bot_sorted["topics"]
        warn("You forgot to call sortReplies()!")
        return "ERR: Replies Not Sorted"
      end

      topic = @master.get_uservar(user, "topic")
      topic = "random" if topic.nil? || topic == "undefined"

      stars = []
      thatstars = []
      reply = ""

      if !bot_topics[topic]
        warn("User #{user} was in an empty topic named '#{topic}'")
        topic = "random"
        @master.set_uservar(user, "topic", topic)
      end

      return @master.errors["deepRecursion"] if step > bot_depth

      topic = "__begin__" if context == "begin"

      history = bot_session.get(user, "__history__")
      if history == "undefined"
        history = new_history
        bot_session.set(user, { "__history__" => history })
      end

      unless bot_topics[topic]
        return "ERR: No default topic 'random' was found!"
      end

      matched = nil
      matched_trigger = nil
      found_match = false

      if step == 0
        all_topics = [topic]
        includes = bot_includes[topic] || {}
        inherits = bot_inherits[topic] || {}
        if includes.any? || inherits.any?
          all_topics = Inheritance.get_topic_tree(@master, topic)
        end

        all_topics.each do |top|
          say("Checking topic #{top} for any %Previous's")
          thats_list = bot_sorted["thats"][top] || []
          if !thats_list.empty?
            say("There's a %Previous in this topic!")

            last_reply = history["reply"] ? history["reply"][0] : "undefined"
            last_reply = format_message(last_reply, true)
            say("Last reply: #{last_reply}")

            thats_list.each do |trig|
              pattern = trig[1]["previous"]
              botside = trigger_regexp(user, pattern)

              say("Try to match lastReply (#{last_reply}) to #{botside}")

              botstars_captured = trigger_match(last_reply, pattern, botside)
              if botstars_captured
                say("Bot side matched!")
                thatstars = botstars_captured

                user_side = trig[1]
                regexp = trigger_regexp(user, user_side["trigger"])
                say("Try to match \"#{msg}\" against #{user_side["trigger"]} (#{regexp})")

                stars_captured = trigger_match(msg, user_side["trigger"], regexp)

                if stars_captured
                  stars = stars_captured
                  matched = user_side
                  found_match = true
                  matched_trigger = user_side["trigger"]
                  break
                end
              end
            end
          else
            say("No %Previous in this topic!")
          end
          break if found_match
        end
      end

      unless found_match
        say("Searching their topic for a match...")
        (bot_sorted["topics"][topic] || []).each do |trig|
          pattern = trig[0]
          regexp = trigger_regexp(user, pattern)

          say("Try to match \"#{msg}\" against #{pattern} (#{regexp})")

          stars_captured = trigger_match(msg, pattern, regexp)

          if stars_captured
            say("Found a match!")
            stars = stars_captured
            matched = trig[1]
            found_match = true
            matched_trigger = pattern
            break
          end
        end
      end

      bot_session.set(user, { "__lastmatch__" => matched_trigger })
      if step == 0
        bot_session.set(user, {
          "__initialmatch__" => matched_trigger,
          "__last_triggers__" => []
        })
      end

      if matched
        existing_triggers = bot_session.get(user, "__last_triggers__")
        existing_triggers = [] unless existing_triggers.is_a?(Array)
        last_triggers = existing_triggers.dup
        last_triggers.push(matched)
        bot_session.set(user, { "__last_triggers__" => last_triggers })

        if !matched["redirect"].nil?
          say("Redirecting us to #{matched["redirect"]}")
          redirect = process_tags(user, msg, matched["redirect"], stars, thatstars, step, scope)
          redirect = format_message(redirect)

          say("Pretend user said: #{redirect}")
          reply = get_reply(user, redirect, context, step + 1, scope)
        else
          matched["condition"].each do |row|
            halves = row.split(/\s*=>\s*/)
            next unless halves && halves.length == 2

            condition = halves[0].match(/^(.+?)\s+(==|eq|!=|ne|<>|<|<=|>|>=)\s+(.*?)$/)
            next unless condition

            left = Utils.strip(condition[1])
            eq = condition[2]
            right = Utils.strip(condition[3])
            potreply = halves[1].strip

            left = process_tags(user, msg, left, stars, thatstars, step, scope)
            right = process_tags(user, msg, right, stars, thatstars, step, scope)

            left = "undefined" if left.empty?
            right = "undefined" if right.empty?

            say("Check if #{left} #{eq} #{right}")

            passed = false
            if %w[eq ==].include?(eq)
              passed = (left == right)
            elsif %w[ne != <>].include?(eq)
              passed = (left != right)
            else
              begin
                left_num = left.to_i
                right_num = right.to_i
                passed = case eq
                         when "<" then left_num < right_num
                         when "<=" then left_num <= right_num
                         when ">" then left_num > right_num
                         when ">=" then left_num >= right_num
                         else false
                         end
              rescue StandardError
                warn("Failed to evaluate numeric condition!")
              end
            end

            if passed
              reply = potreply
              break
            end
          end

          if reply.nil? || reply.empty?
            bucket = []
            matched["reply"].each do |rep|
              weight = 1
              if (wmatch = rep.match(/\{weight=(\d+?)\}/i))
                weight = wmatch[1].to_i
                if weight <= 0
                  warn("Can't have a weight <= 0!")
                  weight = 1
                elsif weight > MAX_REPLY_WEIGHT
                  warn("Reply weight #{weight} exceeds maximum of #{MAX_REPLY_WEIGHT}, clamping!")
                  weight = MAX_REPLY_WEIGHT
                end
              end

              weight.times { bucket.push(rep) }
            end

            choice = (rand * bucket.length).floor
            reply = bucket[choice]
          end
        end
      end

      if !found_match
        reply = @master.errors["replyNotMatched"]
      elsif reply.nil? || reply.empty?
        reply = @master.errors["replyNotFound"]
      end

      say("Reply: #{reply}")

      if context == "begin"
        giveup = 0
        while (match = reply.match(/\{topic=(.+?)\}/i))
          giveup += 1
          if giveup >= 50
            warn("Infinite loop looking for topic tag!")
            break
          end

          name = match[1]
          @master.set_uservar(user, "topic", name)
          reply = reply.sub(/\{topic=#{Regexp.escape(name)}\}/i, "")
        end

        giveup = 0
        while (match = reply.match(/<set (.+?)=(.+?)>/i))
          giveup += 1
          if giveup >= 50
            warn("Infinite loop looking for set tag!")
            break
          end

          name = match[1]
          value = match[2]
          @master.set_uservar(user, name, value)
          reply = reply.sub(/<set #{Regexp.escape(name)}=#{Regexp.escape(value)}>/i, "")
        end
      else
        reply = process_tags(user, msg, reply, stars, thatstars, step, scope)
      end

      reply
    end

    def new_history
      {
        "input" => Array.new(10, "undefined"),
        "reply" => Array.new(10, "undefined")
      }
    end

    def error_reply?(reply)
      reply == @master.errors["replyNotMatched"] ||
        reply == @master.errors["replyNotFound"]
    end
  end
end
