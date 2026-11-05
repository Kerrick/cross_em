# frozen_string_literal: true

module CrossEm
  module Presentation
    # Where everything goes in a window of a given size, in whole pixels.
    #
    # Upright (a phone, a narrow window): the header across the top, the
    # board in the middle, and under it the status line, the pool and the
    # controls, in thumb reach. Wide (a tablet on its side, a desktop):
    # the board on the left, and a column on the right with the status
    # line, the pool and the controls. When the game is over, the results
    # take the place of the status line and the controls, and the pool
    # stays only while letters are left in it.
    #
    # Everything stays inside +safe+, the part of the window that no
    # notch, rounded corner or home indicator covers.
    class Layout < Data.define(:width, :height, :landscape, :header, :wordmark, :help_button, :theme_button,
                               :sound_button, :board, :status, :pool, :controls, :results)
      # The buttons under the pool while the game is played.
      class Controls < Data.define(:shuffle, :reset, :give_up)
        def each(&) = [[:shuffle, shuffle], [:reset, reset], [:give_up, give_up]].each(&)
      end

      # The results, once the game is over: the heading, the four
      # statistics, the clock to the next puzzle and the share button.
      class Results < Data.define(:heading, :stats, :countdown, :copy); end

      M = Look::METRICS

      def self.for(width:, height:, units:, safe: nil, over: false, pool: true)
        Planner.new(width:, height:, units:, safe: safe || Rect.new(x: 0, y: 0, width:, height:), over:, pool:).layout
      end

      def header_buttons = [[:help, help_button], [:theme, theme_button], [:sound, sound_button]]

      # Works out a Layout. One is made for every window size and state.
      class Planner
        def initialize(width:, height:, units:, safe:, over:, pool:)
          @width, @height, @u, @over, @pool = width, height, units, over, pool
          @safe = safe.empty? ? Rect.new(x: 0, y: 0, width:, height:) : safe
          @margin = px(M.margin)
          @gap = px(M.gap)
        end

        def layout
          header = Rect.new(x: @safe.x + @margin, y: @safe.y, width: @safe.width - (2 * @margin), height: px(M.header))
          help, theme, sound = header_buttons(header)
          parts = landscape? ? side_column(header) : bottom_stack(header)
          Layout.new(width: @width, height: @height, landscape: landscape?, header:,
                     wordmark: header.with(width: help.x - header.x), help_button: help, theme_button: theme,
                     sound_button: sound, **parts)
        end

        private

        def px(points) = @u.px(points)

        # Wide enough, in points, to put the pool beside the board.
        def landscape?
          wide, tall = @u.pt(@safe.width), @u.pt(@safe.height)
          wide >= tall * 1.1 && wide >= 600
        end

        def header_buttons(header)
          size = px(M.touch)
          top = header.y + ((header.height - size) / 2)
          3.times.map { |i| Rect.new(x: header.right - (size * (3 - i)), y: top, width: size, height: size) }
        end

        # Upright: from the bottom of the safe area up, then the board in
        # whatever height is left.
        def bottom_stack(header)
          inner = Rect.new(x: @safe.x + @margin, y: header.bottom, width: @safe.width - (2 * @margin), height: 0)
          bottom = @safe.bottom - @margin
          parts = {status: nil, controls: nil, results: nil}
          pool_slots, pool_height = pool(inner.x, inner.width)

          if @over
            row = centered(inner, bottom - px(M.controls), px(M.controls))
            stats = inner.with(y: row.y - @gap - px(M.stats), height: px(M.stats))
            top = stats.y - @gap
            if @pool
              pool_slots = shift(pool_slots, top - pool_height)
              top -= pool_height + @gap
            end
            heading = inner.with(y: top - px(M.heading), height: px(M.heading))
            parts[:results] = results(heading, stats, row)
            top = heading.y
          else
            row = centered(inner, bottom - px(M.controls), px(M.controls))
            parts[:controls] = controls(row)
            pool_slots = shift(pool_slots, row.y - @gap - pool_height)
            status = inner.with(y: pool_slots.first.y - @gap - px(M.status), height: px(M.status))
            parts[:status] = status
            top = status.y
          end

          board = Rect.new(x: @safe.x, y: header.bottom, width: @safe.width, height: [top - @gap / 2 - header.bottom, 0].max)
          {board:, pool: @over && !@pool ? [] : pool_slots, **parts}
        end

        # Wide: a column on the right, its parts centred top to bottom in
        # the room under the header, and the board to its left.
        def side_column(header)
          room = (@safe.width - (2 * @margin))
          column_width = (room * 0.38).round.clamp(px(M.column_min), [px(M.column_max), room / 2].max)
          column = Rect.new(x: @safe.right - @margin - column_width, y: header.bottom, width: column_width,
                            height: @safe.bottom - @margin - header.bottom)
          pool_slots, pool_height = pool(column.x, column.width)
          heights = if @over
                      [px(M.heading), (@pool ? pool_height : nil), px(M.stats), px(M.controls)].compact
                    else
                      [px(M.status), pool_height, px(M.controls)]
                    end
          stack = heights.sum + (@gap * (heights.size - 1))
          top = column.y + [(column.height - stack) / 2, 0].max
          parts = {status: nil, controls: nil, results: nil}

          if @over
            heading = column.with(y: top, height: px(M.heading))
            top = heading.bottom + @gap
            if @pool
              pool_slots = shift(pool_slots, top)
              top += pool_height + @gap
            end
            stats = column.with(y: top, height: px(M.stats))
            row = centered(column, stats.bottom + @gap, px(M.controls))
            parts[:results] = results(heading, stats, row)
          else
            parts[:status] = column.with(y: top, height: px(M.status))
            pool_slots = shift(pool_slots, top + px(M.status) + @gap)
            parts[:controls] = controls(centered(column, pool_slots.last.bottom + @gap, px(M.controls)))
          end

          board = Rect.new(x: @safe.x, y: header.bottom, width: column.x - @gap - @safe.x,
                           height: @safe.bottom - header.bottom)
          {board:, pool: @over && !@pool ? [] : pool_slots, **parts}
        end

        # The twelve slots, in rows of six, or four when six would make a
        # tile smaller than a fingertip, centred across +width+; and their
        # height. Their top is 0 until shifted into place.
        def pool(left, width)
          gap = px(M.tile_gap)
          per_row = Rules::POOL_ROW_LENGTH
          tile = (width - (gap * (per_row - 1))) / per_row
          if tile < px(M.tile_min)
            per_row = 4
            tile = (width - (gap * (per_row - 1))) / per_row
          end
          tile = tile.clamp(1, px(M.tile_max))
          rows = Rules::LETTER_COUNT / per_row
          start = left + ((width - ((per_row * tile) + ((per_row - 1) * gap))) / 2)
          slots = Array.new(Rules::LETTER_COUNT) do |i|
            row, column = i.divmod(per_row)
            Rect.new(x: start + (column * (tile + gap)), y: row * (tile + gap), width: tile, height: tile)
          end
          [slots, (rows * tile) + ((rows - 1) * gap)]
        end

        def shift(slots, top) = slots.map { it.offset(0, top) }

        # A row as wide as +area+, but no wider than the controls look
        # best, centred.
        def centered(area, top, height)
          width = [area.width, px(M.controls_max)].min
          Rect.new(x: area.x + ((area.width - width) / 2), y: top, width:, height:)
        end

        def controls(row)
          shuffle, reset, give_up = row.columns(3, px(M.tile_gap))
          Controls.new(shuffle:, reset:, give_up:)
        end

        # The clock takes the row's left part, the share button its right.
        def results(heading, stats, row)
          copy_width = [row.width / 2, px(220)].min
          countdown = row.with(width: row.width - copy_width - @gap)
          copy = row.with(x: row.right - copy_width, width: copy_width)
          Results.new(heading:, stats: stats.columns(4, px(M.tile_gap)), countdown:, copy:)
        end
      end
    end
  end
end
