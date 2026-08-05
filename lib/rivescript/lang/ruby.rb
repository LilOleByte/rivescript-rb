# frozen_string_literal: true

# RiveScript Ruby port
# Byte <byte@jvmlab.org>, https://jvmlab.org/
# MIT License

class RiveScript
  module Lang
    # Ruby language support for RiveScript object macros.
    #
    # Object macros defined in RiveScript source are compiled and executed via
    # Kernel#eval. Loading untrusted third-party RiveScript personalities can
    # therefore execute arbitrary Ruby code in your process. Disable this handler
    # when loading untrusted sources:
    #
    #   bot.set_handler("ruby", nil)
    #
    # This handler is enabled by default in the Ruby port.
    class RubyHandler
      attr_reader :objects, :sources

      def initialize(master)
        @master = master
        @objects = {}
        @sources = {}
        @binding = binding
      end

      # Called by RiveScript to load Ruby object macro source.
      # +code+ may be a Proc or an Array of source lines.
      def load(name, code)
        if code.is_a?(Proc)
          @objects[name] = code
          @sources[name] = nil
          return
        end

        lines = code.is_a?(Array) ? code.join("\n") : code.to_s
        @sources[name] = lines
        source = <<~RUBY
          @objects[#{name.inspect}] = lambda do |rs, args|
            #{lines}
          end
        RUBY

        begin
          # Intentional: RiveScript object macros are host-language eval, gated by
          # enable_object_macros / set_handler("ruby", nil). See docs/lang.ruby.md.
          eval(source, @binding, "(rivescript object #{name})", 1) # rubocop:disable Security/Eval
        rescue StandardError => e
          @master.warn("Error evaluating Ruby object: #{e.message}")
        end
      end

      # Called by RiveScript to execute a Ruby object macro.
      def call(rs, name, fields, scope = nil)
        func = @objects[name]
        return @master.errors["objectNotFound"] if func.nil?

        reply =
          if scope
            scope.instance_exec(rs, fields, &func)
          else
            func.call(rs, fields)
          end
      rescue StandardError => e
        reply = "[ERR: Error when executing Ruby object: #{e.message}]"
      ensure
        reply = "" if reply.nil?
        reply
      end
    end
  end
end
