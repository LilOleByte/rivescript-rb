# RiveScript Ruby port, https://jvmlab.org/, MIT License

require_relative "utils"

class RiveScript
  # The version of the RiveScript language we support.
  RS_VERSION = "2.0"

  # Parser for RiveScript syntax.
  class Parser
    CONCAT_MODES = {
      "none" => "",
      "newline" => "\n",
      "space" => " "
    }.freeze

    def initialize(master)
      @master = master
      @strict = master._strict
      @utf8 = master._utf8
    end

    # Proxy functions
    def say(message)
      @master.say(message)
    end

    def warn(message, filename = nil, lineno = nil)
      @master.warn(message, filename, lineno)
    end

    # Read and parse a RiveScript document.
    def parse(filename, code, on_error = nil)
      on_error ||= lambda { |err, fname, lineno| warn(err, fname, lineno) }

      ast = {
        "begin" => {
          "global" => {},
          "var" => {},
          "sub" => {},
          "person" => {},
          "array" => {}
        },
        "topics" => {},
        "objects" => []
      }

      topic = "random"
      comment = false
      inobj = false
      obj_name = ""
      obj_lang = ""
      obj_buf = []
      cur_trig = nil
      is_that = nil

      local_options = {
        "concat" => @master._concat.nil? ? "none" : @master._concat
      }

      lines = code.split("\n")
      lines.each_with_index do |raw_line, lp|
        line = Utils.strip(raw_line)
        lineno = lp + 1

        next if line.empty?

        if inobj
          if line.include?("< object") || line.include?("<object")
            if !obj_name.empty?
              ast["objects"] << {
                "name" => obj_name,
                "language" => obj_lang,
                "code" => obj_buf
              }
            end
            obj_name = ""
            obj_lang = ""
            obj_buf = []
            inobj = false
          else
            obj_buf << line
          end
          next
        end

        if line.start_with?("//")
          next
        elsif line.start_with?("#")
          warn("Using the # symbol for comments is deprecated", filename, lineno)
          next
        elsif line.start_with?("/*")
          if line.include?("*/")
            next
          end

          comment = true
          next
        elsif line.include?("*/")
          comment = false
          next
        end
        next if comment

        if line.length < 2
          warn("Weird single-character line '#{line}' found (in topic #{topic})", filename, lineno)
          next
        end

        cmd = line[0]
        line = Utils.strip(line[1..])

        if line.include?(" //")
          line = Utils.strip(line.split(" //", 2)[0])
        end

        if cmd == "?"
          variants = [
            line,
            "[*]#{line}[*]",
            "*#{line}*",
            "[*]#{line}*",
            "*#{line}[*]",
            "#{line}*",
            "*#{line}"
          ]
          cmd = "+"
          line = "(#{variants.join('|')})"
          say("Rewrote ?Keyword as +Trigger: #{line}")
        end

        if @master._forceCase == true && cmd == "+"
          line = line.downcase
        end

        syntax_error = check_syntax(cmd, line)
        unless syntax_error.empty?
          if @strict
            on_error.call("Syntax error: #{syntax_error} at #{filename} line #{lineno} near #{cmd} #{line}", filename, lineno)
          else
            warn("Syntax error: #{syntax_error} at #{filename} line #{lineno} near #{cmd} #{line} (in topic #{topic})", filename, lineno)
          end
        end

        is_that = nil if cmd == "+"

        say("Cmd: #{cmd}; line: #{line}")

        ((lp + 1)...lines.length).each do |li|
          lookahead = Utils.strip(lines[li])
          next if lookahead.length < 2

          look_cmd = lookahead[0]
          lookahead = Utils.strip(lookahead[1..])

          break unless ["%", "^"].include?(look_cmd)
          break if lookahead.empty?

          say("\tLookahead #{li}: #{look_cmd} #{lookahead}")

          if cmd == "+"
            if look_cmd == "%"
              is_that = lookahead
              break
            else
              is_that = nil
            end
          end

          if cmd == "!"
            if look_cmd == "^"
              line += "<crlf>#{lookahead}"
            end
            next
          end

          if cmd != "^" && look_cmd != "%"
            if look_cmd == "^"
              if CONCAT_MODES.key?(local_options["concat"])
                line += CONCAT_MODES[local_options["concat"]] + lookahead
              else
                line += lookahead
              end
            else
              break
            end
          end
        end

        type = ""
        name = ""

        case cmd
        when "!"
          halves = line.split("=", 2)
          left = Utils.strip(halves[0]).split(" ")
          value = ""
          name = ""
          type = ""
          value = Utils.strip(halves[1]) if halves.length == 2

          if left.length >= 1
            type = Utils.strip(left[0])
            if left.length >= 2
              left.shift
              name = Utils.strip(left.join(" "))
            end
          end

          value = value.gsub("<crlf>", "") unless type == "array"

          if type == "version"
            if value.to_f > RS_VERSION.to_f
              on_error.call("Unsupported RiveScript version. We only support #{RS_VERSION} at #{filename} line #{lineno}", filename, lineno)
              return ast
            end
            next
          end

          if name.empty?
            warn("Undefined variable name", filename, lineno)
            next
          end
          if value.empty?
            warn("Undefined variable value", filename, lineno)
            next
          end

          case type
          when "local"
            say("\tSet local parser option #{name} = #{value}")
            local_options[name] = value
          when "global"
            say("\tSet global #{name} = #{value}")
            ast["begin"]["global"][name] = value
          when "var"
            say("\tSet bot variable #{name} = #{value}")
            ast["begin"]["var"][name] = value
          when "array"
            if value == "<undef>"
              ast["begin"]["array"][name] = "<undef>"
              next
            end

            parts = value.split("<crlf>")
            fields = []
            parts.each do |val|
              if val.include?("|")
                fields.concat(val.split("|"))
              else
                fields.concat(val.split(" "))
              end
            end

            fields.map! { |field| field.gsub(/\\s/i, " ") }
            fields.reject!(&:empty?)

            say("\tSet array #{name} = #{fields.inspect}")
            ast["begin"]["array"][name] = fields
          when "sub"
            say("\tSet substitution #{name} = #{value}")
            ast["begin"]["sub"][name] = value
          when "person"
            say("\tSet person substitution #{name} = #{value}")
            ast["begin"]["person"][name] = value
          else
            warn("Unknown definition type #{type}", filename, lineno)
          end
        when ">"
          temp = Utils.strip(line).split(" ")
          type = temp.shift
          name = ""
          fields = []
          name = temp.shift if temp.length > 0
          fields = temp if temp.length > 0

          case type
          when "begin", "topic"
            if type == "begin"
              say("Found the BEGIN block.")
              type = "topic"
              name = "__begin__"
            end

            name = name.downcase if @master._forceCase == true

            say("Set topic to #{name}")
            cur_trig = nil
            topic = name

            init_topic(ast["topics"], topic)

            mode = ""
            if fields.length >= 2
              fields.each do |field|
                if ["includes", "inherits"].include?(field)
                  mode = field
                elsif !mode.empty?
                  ast["topics"][topic][mode][field] = 1
                end
              end
            end
          when "object"
            lang = ""
            lang = fields[0].downcase if fields.length > 0

            if lang.empty?
              warn("Trying to parse unknown programming language", filename, lineno)
              lang = "ruby"
            end

            obj_name = name
            obj_lang = lang
            obj_buf = []
            inobj = true
          else
            warn("Unknown label type #{type}", filename, lineno)
          end
        when "<"
          type = line
          if ["begin", "topic"].include?(type)
            say("\tEnd the topic label.")
            topic = "random"
          elsif type == "object"
            say("\tEnd the object label.")
            inobj = false
          end
        when "+"
          say("\tTrigger pattern: #{line}")

          init_topic(ast["topics"], topic)
          cur_trig = {
            "trigger" => line,
            "reply" => [],
            "condition" => [],
            "redirect" => nil,
            "previous" => is_that
          }
          ast["topics"][topic]["triggers"] << cur_trig
        when "-"
          if cur_trig.nil?
            warn("Response found before trigger", filename, lineno)
            next
          end

          if !cur_trig["redirect"].nil?
            warn("You can't mix @Redirects with -Replies", filename, lineno)
          end

          say("\tResponse: #{line}")
          cur_trig["reply"] << line
        when "*"
          if cur_trig.nil?
            warn("Condition found before trigger", filename, lineno)
            next
          end

          if !cur_trig["redirect"].nil?
            warn("You can't mix @Redirects with *Conditions", filename, lineno)
          end

          say("\tCondition: #{line}")
          cur_trig["condition"] << line
        when "%", "^"
          next
        when "@"
          if cur_trig["reply"].length > 0 || cur_trig["condition"].length > 0
            warn("You can't mix @Redirects with -Replies or *Conditions", filename, lineno)
          end
          say("\tRedirect response to: #{line}")
          cur_trig["redirect"] = Utils.strip(line)
        else
          warn("Unknown command '#{cmd}' (in topic #{topic})", filename, lineno)
        end
      end

      ast
    end

    # Translate deparsed data into the source code of a RiveScript document.
    def stringify(deparsed = nil)
      deparsed = @master.deparse if deparsed.nil?

      write_triggers = lambda do |triggers, indent|
        id = indent ? "\t" : ""
        output = []
        triggers.each do |t|
          output << "#{id}+ #{t['trigger']}"
          output << "#{id}% #{t['previous']}" if t["previous"]
          t["condition"]&.each do |c|
            output << "#{id}* #{c.gsub("\n", "\\n")}"
          end
          output << "#{id}@ #{t['redirect']}" if t["redirect"]
          t["reply"]&.each do |r|
            output << "#{id}- #{r.gsub("\n", "\\n")}" if r
          end
          output << ""
        end
        output
      end

      source = ["! version = 2.0", "! local concat = none", ""]
      ref = ["global", "var", "sub", "person", "array"]

      ref.each do |begin_type|
        next if deparsed["begin"][begin_type].nil? || deparsed["begin"][begin_type].empty?

        deparsed["begin"][begin_type].each do |key, value|
          if begin_type != "array"
            source << "! #{begin_type} #{key} = #{value}"
          else
            pipes = " "
            value.each do |test|
              if test.match?(/\s+/)
                pipes = "|"
                break
              end
            end
            source << "! #{begin_type} #{key} = #{value.join(pipes)}"
          end
        end
        source << ""
      end

      if deparsed["objects"]
        deparsed["objects"].each do |lang, lang_objects|
          next unless lang_objects && lang_objects["_objects"]

          sources = lang_objects["_sources"] || {}
          lang_objects["_objects"].each do |func, code|
            source << "> object #{func} #{lang}"
            if sources[func]
              source << sources[func].to_s.split("\n").map { |ln| "\t#{ln}" }.join("\n")
            elsif code.is_a?(String)
              body = code.to_s.match(/function[^{]+\{\n*([\s\S]*)\};?\s*$/m)
              source << body[1].strip.split("\n").map { |ln| "\t#{ln}" }.join("\n") if body
            elsif code.respond_to?(:source)
              # no-op for procs without source
            end
            source << "< object\n"
          end
        end
      end

      if deparsed["begin"]["triggers"] && deparsed["begin"]["triggers"].length > 0
        source << "> begin\n"
        source.concat(write_triggers.call(deparsed["begin"]["triggers"], "indent"))
        source << "< begin\n"
      end

      topics = deparsed["topics"].keys.sort
      topics.unshift("random")
      done_random = false

      topics.each do |topic_name|
        next unless deparsed["topics"].key?(topic_name)
        next if topic_name == "random" && done_random

        done_random = true if topic_name == "random"

        tagged = false
        tagline = []
        if topic_name != "random" ||
           (!(deparsed["inherits"][topic_name] || {}).empty? || !(deparsed["includes"][topic_name] || {}).empty?)
          tagged = true if topic_name != "random"

          inherits = (deparsed["inherits"][topic_name] || {}).keys
          includes = (deparsed["includes"][topic_name] || {}).keys

          if includes.length > 0
            tagline.concat(["includes"] + includes)
            tagged = true
          end
          if inherits.length > 0
            tagline.concat(["inherits"] + inherits)
            tagged = true
          end
        end

        if tagged
          source << ("> topic #{topic_name} " + tagline.join(" ")).strip + "\n"
        end

        source.concat(write_triggers.call(deparsed["topics"][topic_name], tagged))

        source << "< topic\n" if tagged
      end

      source.join("\n")
    end

    # Check the syntax of a RiveScript command.
    def check_syntax(cmd, line)
      case cmd
      when "!"
        unless line.match?(/\A.+(?:\s+.+|)\s*=\s*.+?\z/)
          return "Invalid format for !Definition line: must be '! type name = value' OR '! type = value'"
        end

        if line.match?(/^array/)
          if line.match?(/=\s?\||\|\s?$/)
            return "Piped arrays can't begin or end with a |"
          elsif line.match?(/\|\|/)
            return "Piped arrays can't include blank entries"
          end
        end
      when ">"
        parts = line.split(/\s+/)
        if parts[0] == "begin" && parts.length > 1
          return "The 'begin' label takes no additional arguments"
        elsif parts[0] == "topic"
          if !@master._forceCase && line.match?(/[^a-z0-9_\-\s]/)
            return "Topics should be lowercased and contain only letters and numbers"
          elsif line.match?(/[^A-Za-z0-9_\-\s]/)
            return "Topics should contain only letters and numbers in forceCase mode"
          end
        elsif parts[0] == "object"
          if line.match?(/[^A-Za-z0-9_\-\s]/)
            return "Objects can only contain numbers and letters"
          end
        end
      when "+", "%", "@"
        parens = 0
        square = 0
        curly = 0
        angle = 0

        if @utf8
          if line.match?(/[A-Z\\.]/)
            return "Triggers can't contain uppercase letters, backslashes or dots in UTF-8 mode"
          end
        elsif line.match?(/[^a-z0-9(|)\[\]*_#@{}<>=\/\s]/)
          return "Triggers may only contain lowercase letters, numbers, and these symbols: ( | ) [ ] * _ # { } < > = /"
        elsif line.match?(/\(\||\|\)/)
          return "Piped alternations can't begin or end with a |"
        elsif line.match?(/\([^\)].+\|\|.+\)/)
          return "Piped alternations can't include blank entries"
        elsif line.match?(/\[\||\|\]/)
          return "Piped optionals can't begin or end with a |"
        elsif line.match?(/\[[^\]].+\|\|.+\]/)
          return "Piped optionals can't include blank entries"
        end

        line.each_char do |char|
          case char
          when "(" then parens += 1
          when ")" then parens -= 1
          when "[" then square += 1
          when "]" then square -= 1
          when "{" then curly += 1
          when "}" then curly -= 1
          when "<" then angle += 1
          when ">" then angle -= 1
          end
        end

        return "Unmatched parenthesis brackets" if parens != 0
        return "Unmatched square brackets" if square != 0
        return "Unmatched curly brackets" if curly != 0
        return "Unmatched angle brackets" if angle != 0
      when "*"
        unless line.match?(/\A.+?\s*(?:==|eq|!=|ne|<>|<|<=|>|>=)\s*.+?=>.+?\z/)
          return "Invalid format for !Condition: should be like '* value symbol value => response'"
        end
      end

      ""
    end

    # Initialize the topic tree for the parsing phase.
    def init_topic(topics, name)
      return unless topics[name].nil?

      topics[name] = {
        "includes" => {},
        "inherits" => {},
        "triggers" => []
      }
    end
  end
end
