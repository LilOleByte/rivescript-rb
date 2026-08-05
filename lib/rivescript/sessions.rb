# frozen_string_literal: true

# RiveScript Ruby port
# Byte <byte@jvmlab.org>, https://jvmlab.org/
# MIT License

class RiveScript
  # SessionManager is the interface for session managers that store user
  # variables for RiveScript. User variables include those set with the
  # <set> tag or set_uservar, as well as recent reply history and private
  # internal state variables.
  #
  # The default session manager keeps the variables in memory. To use a
  # custom backend, subclass SessionManager and pass an instance to
  # RiveScript.new(session_manager: manager).
  class SessionManager
    # Set user variables for +username+. +data+ is a Hash of key/value pairs.
    # A value of +nil+ for a variable means it should be deleted.
    def set(username, data)
      raise NotImplementedError
    end

    # Retrieve a stored variable for a user.
    # Returns +nil+ if the user does not exist, or the string "undefined"
    # if the user exists but the key does not.
    def get(username, key)
      raise NotImplementedError
    end

    # Retrieve all stored user variables for +username+.
    # Returns +nil+ if the user does not exist.
    def get_any(username)
      raise NotImplementedError
    end

    # Retrieve all variables about all users.
    def get_all
      raise NotImplementedError
    end

    # Reset all variables stored about a particular user.
    def reset(username)
      raise NotImplementedError
    end

    # Reset all data about all users.
    def reset_all
      raise NotImplementedError
    end

    # Make a snapshot of the user's variables so that they can be restored
    # later via thaw.
    def freeze(username)
      raise NotImplementedError
    end

    # Restore the frozen snapshot of variables for a user.
    # +action+ may be "thaw" (default), "discard", or "keep".
    def thaw(username, action = "thaw")
      raise NotImplementedError
    end

    # Default session variables for a new user.
    def default_session
      { "topic" => "random" }
    end
  end

  # Default in-memory session store for RiveScript.
  class MemorySessionManager < SessionManager
    def initialize
      super
      @users = {}
      @frozen = {}
      @mutex = Mutex.new
    end

    def init(username)
      @users[username] = default_session if @users[username].nil?
    end

    def set(username, data)
      @mutex.synchronize do
        init(username)
        data.each do |key, value|
          if value.nil?
            @users[username].delete(key)
          else
            @users[username][key] = value
          end
        end
        nil
      end
    end

    def get(username, key)
      @mutex.synchronize do
        return nil if @users[username].nil?

        if @users[username].key?(key)
          @users[username][key]
        else
          "undefined"
        end
      end
    end

    def get_any(username)
      @mutex.synchronize do
        return nil if @users[username].nil?

        Utils.clone(@users[username])
      end
    end

    def get_all
      @mutex.synchronize { Utils.clone(@users) }
    end

    def reset(username)
      @mutex.synchronize do
        @users.delete(username)
        @frozen.delete(username)
        nil
      end
    end

    def reset_all
      @mutex.synchronize do
        @users = {}
        @frozen = {}
        nil
      end
    end

    def freeze(username)
      @mutex.synchronize do
        if @users[username].nil?
          raise "freeze(#{username}): user not found"
        end

        @frozen[username] = Utils.clone(@users[username])
        nil
      end
    end

    def thaw(username, action = "thaw")
      @mutex.synchronize do
        if @frozen[username].nil?
          raise "thaw(#{username}): no frozen variables found"
        end

        case action
        when "thaw"
          @users[username] = Utils.clone(@frozen[username])
          @frozen.delete(username)
        when "discard"
          @frozen.delete(username)
        when "keep"
          @users[username] = Utils.clone(@frozen[username])
        else
          raise "bad thaw action"
        end

        nil
      end
    end
  end

  # Session manager that does not remember any user variables.
  # Mostly useful for unit tests.
  class NullSessionManager < SessionManager
    def set(_username, _data)
      nil
    end

    def get(_username, _key)
      "undefined"
    end

    def get_any(_username)
      nil
    end

    def get_all
      {}
    end

    def reset(_username)
      nil
    end

    def reset_all
      nil
    end

    def freeze(_username)
      nil
    end

    def thaw(_username, _action = "thaw")
      nil
    end
  end
end
