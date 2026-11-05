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

    # Where Past puzzles' parts go: a card as tall as the safe area
    # allows, its title and close button, and the body the list scrolls
    # in. It answers what a SheetLayout does, so a press, a drag and a
    # wheel work on it as on any sheet; a tap on a day is a control whose
    # id is [:day, number].
    class ArchiveLayout < Data.define(:card, :title, :close, :link, :body, :list)
      M = Look::METRICS

      def self.build(list:, safe:, units:)
        margin = units.px(M.margin)
        width = [safe.width - (2 * margin), units.px(M.sheet_max)].min
        height = safe.height - (2 * margin)
        card = Rect.new(x: safe.x + ((safe.width - width) / 2), y: safe.y + margin, width:, height:)
        pad = units.px(width < units.px(420) ? 20 : 28)
        title_height = units.px(64)
        title = Rect.new(x: card.x + pad, y: card.y, width: card.width - (2 * pad), height: title_height)
        touch = units.px(M.touch)
        close = Rect.new(x: card.right - units.px(8) - touch, y: card.y + ((title_height - touch) / 2), width: touch,
                         height: touch)
        body = Rect.new(x: card.x + units.px(8), y: title.bottom, width: card.width - (2 * units.px(8)),
                        height: card.bottom - title.bottom - units.px(8))
        new(card:, title:, close:, link: nil, body:, list:)
      end

      def content_height = list.height
      def most_scroll = [content_height - body.height, 0].max
      def scrolls? = most_scroll.positive?

      # The day under (+px+, +py+) with the list scrolled by +scroll+.
      def control_at(px, py, scroll)
        return unless body.contains?(px, py)

        row = list.row_at(py - body.y + scroll)
        SheetLayout::Control.new(id: [:day, row.number], kind: :day, rect: row_rect(row, 0), text: nil, detail: nil,
                                 primary: false) if row&.day?
      end

      # Where +row+ is drawn on the screen with the list scrolled by
      # +scroll+.
      def row_rect(row, scroll) = Rect.new(x: body.x, y: body.y + row.y - scroll, width: body.width, height: row.height)

      # The rows in view with the list scrolled by +scroll+.
      def visible(scroll) = list.visible(scroll, body.height)

      # The scroll that brings +row+ wholly into view, below the month's
      # heading pinned at the top, moving as little as it can.
      def reveal(row, scroll)
        heading = list.rows.first.height
        top = row.y - heading
        bottom = row.bottom - body.height
        scroll.clamp(bottom, [top, bottom].max).clamp(0, most_scroll)
      end
    end
  end
end

