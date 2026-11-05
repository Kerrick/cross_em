# frozen_string_literal: true

module CrossEm
  module Presentation
    # When to capture the screen in a development run
    # (CROSS_EM_SHOTS="0.5,2,4"): seconds since the game started, numbered
    # from 1 in the order written.
    class ShotSchedule < Data.define(:times)
      def self.parse(text)
        new(times: text.to_s.split(",").filter_map { Float(it.strip, exception: false) }.freeze)
      end

      # The numbers of the shots that fall due after +before+, up to +now+.
      def due(before, now) = times.each_index.select { times[it] > before && times[it] <= now }.map(&:succ)

      def last = times.max
    end
  end
end
