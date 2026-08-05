# RiveScript Ruby port, https://jvmlab.org/, MIT License

# Miscellaneous utility functions.

class RiveScript
  module Utils
    module_function

    def strip(text)
      text.gsub(/^[\s\t]+/, "").gsub(/[\s\t]+$/, "").gsub(/[\x0D\x0A]+/, "")
    end

    def trim(text)
      text.gsub(/^[\x0D\x0A\s\t]+/, "").gsub(/[\x0D\x0A\s\t]+$/, "")
    end

    def extend(a, b)
      b.each do |attr, value|
        a[attr] = value
      end
    end

    def word_count(trigger, all = false)
      words = if all
                trigger.split(/\s+/)
              else
                trigger.split(/[\s\*#_\|]+/)
              end
      words.count { |word| !word.empty? }
    end

    def strip_nasties(string, utf8)
      if utf8
        string.gsub(/[\\<>]+/, "")
      else
        string.gsub(/[^A-Za-z0-9 ]/, "")
      end
    end

    def quotemeta(string)
      unsafe = "\\.+*?[^]$(){}=!<>|:".chars
      unsafe.each do |char|
        string = string.gsub(char, "\\#{char}")
      end
      string
    end

    def is_atomic(trigger)
      specials = ["*", "#", "_", "(", "[", "<", "@"]
      specials.none? { |special| trigger.include?(special) }
    end

    def string_format(type, string)
      case type
      when "uppercase"
        string.upcase
      when "lowercase"
        string.downcase
      when "sentence"
        string = string.to_s
        string[0].upcase + string[1..]
      when "formal"
        string.split(/\s+/).map do |word|
          word[0].upcase + word[1..]
        end.join(" ")
      else
        string
      end
    end

    def parse_call_args(str)
      result = []
      buff = ""
      inside_a_string = false

      str.each_char do |c|
        if c.match?(/\s/) && !inside_a_string
          unless buff.empty?
            result.push(buff)
            buff = ""
          end
        elsif c == '"'
          unless inside_a_string
            # opening quote - don't add to buff
          else
            result.push(buff) unless buff.empty?
            buff = ""
          end
          inside_a_string = !inside_a_string
        else
          buff += c
        end
      end

      result.push(buff) unless buff.empty?
      result
    end

    def clone(obj)
      case obj
      when nil
        nil
      when Array
        obj.map { |item| clone(item) }
      when Hash
        obj.transform_values { |v| clone(v) }
      else
        obj
      end
    end

    def n_index_of(string, match, index)
      string.split(match, index).join(match).length
    end
  end
end
