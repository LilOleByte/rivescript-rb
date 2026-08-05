# RiveScript Ruby port, https://jvmlab.org/, MIT License

# Topic inheritance functions.
#
# Helper functions to assist with topic inheritance and includes.

require_relative "utils"

class RiveScript
  module Inheritance
    module_function

    # Recursively scan through a topic and retrieve a listing of all triggers in
    # that topic and in all included/inherited topics. Some triggers will come out
    # with an {inherits} tag to signify inheritance depth.
    def get_topic_triggers(rs, topic, thats = false, depth = 0, inheritance = 0, inherited = false)
      rs_depth = rs._depth
      rs_topics = rs._topics
      rs_thats = rs._thats
      rs_includes = rs._includes
      rs_inherits = rs._inherits

      if depth > rs_depth
        rs.warn("Deep recursion while scanning topic inheritance (gave up in topic #{topic})!")
        return []
      end

      rs.say("Collecting trigger list for topic #{topic} (depth=#{depth}; inheritance=#{inheritance}; inherited=#{inherited})")

      if rs_topics[topic].nil?
        rs.warn("Inherited or included topic '#{topic}' doesn't exist or has no triggers")
        return []
      end

      triggers = []
      in_this_topic = []

      unless thats
        rs_topics[topic]&.each do |trigger|
          in_this_topic.push([trigger["trigger"], trigger])
        end
      else
        rs_thats[topic]&.each do |_cur_trig, previous_map|
          previous_map.each do |_previous, pointer|
            in_this_topic.push([pointer["trigger"], pointer])
          end
        end
      end

      includes = rs_includes[topic] || {}
      if includes.any?
        includes.each_key do |inc|
          rs.say("Topic #{topic} includes #{inc}")
          triggers.concat(get_topic_triggers(rs, inc, thats, depth + 1, inheritance + 1, false))
        end
      end

      inherits = rs_inherits[topic] || {}
      if inherits.any?
        inherits.each_key do |inh|
          rs.say("Topic #{topic} inherits #{inh}")
          triggers.concat(get_topic_triggers(rs, inh, thats, depth + 1, inheritance + 1, true))
        end
      end

      topic_inherits = rs_inherits[topic] || {}
      if topic_inherits.any? || inherited
        in_this_topic.each do |trigger|
          rs.say("Prefixing trigger with {inherits=#{inheritance}} #{trigger}")
          triggers.push(["{inherits=#{inheritance}}#{trigger[0]}", trigger[1]])
        end
      else
        triggers.concat(in_this_topic)
      end

      triggers
    end

    # Given a topic, return an array of every topic related to it (all topics it
    # includes or inherits, plus all topics included or inherited by those topics,
    # and so on). The array includes the original topic, too.
    def get_topic_tree(rs, topic, depth = 0)
      rs_depth = rs._depth
      rs_includes = rs._includes
      rs_inherits = rs._inherits

      if depth > rs_depth
        rs.warn("Deep recursion while scanning topic tree!")
        return []
      end

      topics = [topic]

      (rs_includes[topic] || {}).each_key do |inc|
        topics.concat(get_topic_tree(rs, inc, depth + 1))
      end

      (rs_inherits[topic] || {}).each_key do |inh|
        topics.concat(get_topic_tree(rs, inh, depth + 1))
      end

      topics
    end
  end
end
