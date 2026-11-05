# frozen_string_literal: true

module CrossEm
  module Presentation
    # Every puzzle from today back to No. 0, newest first, grouped under
    # a heading for each month, with how the player did on each: won,
    # lost, in progress or not played. Over 1,700 rows, so each has a
    # place (+y+, from the list's top, and +height+, in pixels) and only
    # the rows in view are drawn.
    class ArchiveList
      # A month's heading, or a day: its +day+, the player's +status+
      # (:won, :lost, :playing or :unplayed) and saved +record+, if any.
      class Row < Data.define(:kind, :date, :day, :status, :record, :y, :height)
        def month? = kind == :month
        def day? = kind == :day
        def bottom = y + height
        def number = day&.number
      end

      # The player's status on a day, from its saved Record (or nil).
      def self.status_of(record)
        if record.nil? then :unplayed
        elsif record.won? then :won
        elsif record.finished? then :lost
        else :playing
        end
      end

      attr_reader :rows, :height, :today

      # +records+ answers [](number) with a day's Record or nil, as an
      # Archive does. +month+ and +day+ are the rows' heights in pixels.
      def initialize(today:, records:, month:, day:)
        @today = today
        @rows = []
        y = 0
        current = nil
        today.number.downto(0) do |number|
          date = Day.numbered(number).date
          if current != [date.year, date.month]
            current = [date.year, date.month]
            @rows << Row.new(kind: :month, date:, day: nil, status: nil, record: nil, y:, height: month)
            y += month
          end
          record = records[number]
          @rows << Row.new(kind: :day, date:, day: Day.numbered(number), status: ArchiveList.status_of(record), record:,
                           y:, height: day)
          y += day
        end
        @height = y
        @rows.freeze
        @days = @rows.select(&:day?).freeze
      end

      # The rows any part of which lies between +top+ and +top+ +
      # +height+, in order: the ones to draw with the list scrolled by
      # +top+ in a body +height+ tall.
      def visible(top, height)
        first = @rows.bsearch_index { it.bottom > top } or return []
        last = @rows.bsearch_index { it.y >= top + height } || @rows.size
        @rows[first...last]
      end

      # The row at +y+ from the list's top, or nil.
      def row_at(y) = (row = @rows.bsearch { it.bottom > y }) && row.y <= y ? row : nil

      # The day row of puzzle +number+, or nil.
      def day_row(number) = (index = day_index(number)) && @days[index]

      # The day rows, newest first.
      def days = @days

      # The month heading above +row+: the one to pin to the top while
      # its days scroll under it.
      def month_of(row)
        index = @rows.bsearch_index { it.y >= row.y } or return
        index -= 1 until index.negative? || @rows[index].month?
        @rows[index] unless index.negative?
      end

      # The day +by+ rows on from day +number+ (negative for newer),
      # kept in the list.
      def step(number, by)
        index = day_index(number) || 0
        @days[(index + by).clamp(0, @days.size - 1)]
      end

      private

      def day_index(number)
        index = today.number - number
        index if index.between?(0, @days.size - 1)
      end
    end
  end
end
