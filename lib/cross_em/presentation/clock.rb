# frozen_string_literal: true

require "time"

module CrossEm
  module Presentation
    # The time of day, which is the computer's, or, for trying out
    # another day (CROSS_EM_TODAY), the same time on that date.
    class Clock < Data.define(:offset)
      def self.real = new(offset: 0)

      # A clock that reads +date+ (a Date) today, at the real time of day.
      def self.pretending(date, now = Time.now)
        new(offset: Day.new(date:).begins_at - Day.today(now).begins_at)
      end

      # A clock that reads +time+ now, and runs on from there: for trying
      # the moment a new day's puzzle arrives.
      def self.starting_at(time, now = Time.now) = new(offset: time - now)

      def now(real = Time.now) = real + offset
      def today(real = Time.now) = Day.today(now(real))
    end
  end
end
