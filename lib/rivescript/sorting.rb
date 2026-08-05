# RiveScript Ruby port, https://jvmlab.org/, MIT License

# Data sorting functions

require_relative "utils"

class RiveScript
  module Sorting
    module_function

    # Sort a group of triggers in an optimal sorting order.
    def sort_trigger_set(triggers, exclude_previous = true, say = nil)
      say ||= ->(_what) {}

      prior = { "0" => [] }

      triggers.each do |trig|
        if exclude_previous && !trig[1]["previous"].nil?
          next
        end

        match = trig[0].match(/\{weight=(\d+)\}/i)
        weight = "0"
        weight = match[1] if match && match[1]

        prior[weight] ||= []
        prior[weight].push(trig)
      end

      running = []
      prior_sort = prior.keys.sort_by { |k| -k.to_i }

      prior_sort.each do |p|
        say.call("Sorting triggers with priority #{p}")

        inherits = -1
        highest_inherits = -1
        track = { inherits => init_sort_track }

        prior[p].each do |trig|
          pattern = trig[0]
          say.call("Looking at trigger: #{pattern}")

          match = pattern.match(/\{inherits=(\d+)\}/i)
          if match
            inherits = match[1].to_i
            highest_inherits = inherits if inherits > highest_inherits
            say.call("Trigger belongs to a topic that inherits other topics. Level=#{inherits}")
            pattern = pattern.gsub(/\{inherits=\d+\}/i, "")
            trig[0] = pattern
          else
            inherits = -1
          end

          track[inherits] ||= init_sort_track

          if pattern.include?("_")
            cnt = Utils.word_count(pattern)
            say.call("Has a _ wildcard with #{cnt} words.")
            if cnt > 0
              track[inherits]["alpha"][cnt] ||= []
              track[inherits]["alpha"][cnt].push(trig)
            else
              track[inherits]["under"].push(trig)
            end
          elsif pattern.include?("#")
            cnt = Utils.word_count(pattern)
            say.call("Has a # wildcard with #{cnt} words.")
            if cnt > 0
              track[inherits]["number"][cnt] ||= []
              track[inherits]["number"][cnt].push(trig)
            else
              track[inherits]["pound"].push(trig)
            end
          elsif pattern.include?("*")
            cnt = Utils.word_count(pattern)
            say.call("Has a * wildcard with #{cnt} words.")
            if cnt > 0
              track[inherits]["wild"][cnt] ||= []
              track[inherits]["wild"][cnt].push(trig)
            else
              track[inherits]["star"].push(trig)
            end
          elsif pattern.include?("[")
            cnt = Utils.word_count(pattern)
            say.call("Has optionals with #{cnt} words.")
            track[inherits]["option"][cnt] ||= []
            track[inherits]["option"][cnt].push(trig)
          else
            cnt = Utils.word_count(pattern)
            say.call("Totally atomic trigger with #{cnt} words.")
            track[inherits]["atomic"][cnt] ||= []
            track[inherits]["atomic"][cnt].push(trig)
          end
        end

        track[highest_inherits + 1] = track[-1]
        track.delete(-1)

        track_sorted = track.keys.sort
        track_sorted.each do |ip|
          say.call("ip=#{ip}")

          %w[atomic option alpha number wild].each do |kind|
            kind_sorted = track[ip][kind].keys.sort.reverse
            kind_sorted.each do |wordcnt|
              sorted_by_length = track[ip][kind][wordcnt].sort { |a, b| b[0].length <=> a[0].length }
              running.concat(sorted_by_length)
            end
          end

          under_sorted = track[ip]["under"].sort { |a, b| b[0].length <=> a[0].length }
          pound_sorted = track[ip]["pound"].sort { |a, b| b[0].length <=> a[0].length }
          star_sorted = track[ip]["star"].sort { |a, b| b[0].length <=> a[0].length }
          running.concat(under_sorted)
          running.concat(pound_sorted)
          running.concat(star_sorted)
        end
      end

      running
    end

    # Sort a list of strings by their word counts and lengths.
    def sort_list(items)
      track = {}

      items.each do |item|
        cnt = Utils.word_count(item, true)
        track[cnt] ||= []
        track[cnt].push(item)
      end

      output = []
      sorted = track.keys.sort.reverse
      sorted.each do |count|
        bylen = track[count].sort_by { |a| -a.length }
        output.concat(bylen)
      end

      output
    end

    def init_sort_track
      {
        "atomic" => {},
        "option" => {},
        "alpha" => {},
        "number" => {},
        "wild" => {},
        "pound" => [],
        "under" => [],
        "star" => []
      }
    end
    private_class_method :init_sort_track
  end
end
