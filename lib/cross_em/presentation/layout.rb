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
    # notch, rounded corner or home indicator covers. In a window much
    # wider than the game needs, everything is set on a +paper+: a page
    # no wider than Look's page_max, centred, so the board and the column
    # sit together rather than at the window's far edges. Elsewhere
    # +paper+ is nil and the page is the whole window.
    class Layout < Data.define(:width, :height, :landscape, :header, :wordmark, :archive_button, :help_button,
                               :theme_button, :sound_button, :board, :status, :pool, :controls, :results, :paper)
      # The buttons under the pool while the game is played.
      class Controls < Data.define(:shuffle, :reset, :give_up)
        def each(&) = [[:shuffle, shuffle], [:reset, reset], [:give_up, give_up]].each(&)
      end

      # The results, once the game is over: the heading, the four
      # statistics, the clock to the next puzzle and the share button, and
      # under them a row to play the day again and to see past puzzles.
      class Results < Data.define(:heading, :stats, :countdown, :copy, :again, :archive); end

      M = Look::METRICS

      # How tightly a layout packs: the gap between parts, between pool
      # tiles, the results' heading and statistics, and, once the game is
      # over and the pool can no longer be tapped, its largest tile; and,
      # tightest of all, whether the results' two rows of buttons share
      # one.
      class Fit < Data.define(:gap, :tile_gap, :heading, :stats, :pool_max, :one_row)
        def initialize(gap:, tile_gap:, heading:, stats:, pool_max:, one_row: false) = super
      end

      ROOMY = [
        Fit.new(gap: M.gap, tile_gap: M.tile_gap, heading: M.heading, stats: M.stats, pool_max: M.tile_max),
        Fit.new(gap: 8, tile_gap: 4, heading: 52, stats: 50, pool_max: M.tile_max),
        *[36, 30, 24].map { Fit.new(gap: 8, tile_gap: 4, heading: 52, stats: 50, pool_max: it) }
      ].freeze
      FITS = [*ROOMY, *ROOMY.map { it.with(one_row: true) }].freeze

      # The layout for a window: on paper if the window is wide enough
      # and everything fits on it; upright or wide as its shape suggests,
      # as roomy as leaves the board at least one whole cell and keeps
      # everything on screen; failing that, the other way round; failing
      # that, whichever leaves the board the most room.
      def self.for(width:, height:, units:, safe: nil, over: false, pool: true)
        safe = Rect.new(x: 0, y: 0, width:, height:) if safe.nil? || safe.empty?
        if (paper = paper(safe, units))
          on_paper = plan(width:, height:, units:, safe: paper.inset(units.stroke(1)), over:, pool:)
          return on_paper.with(paper:) if on_paper.fits?(paper.inset(units.stroke(1)), units)
        end
        plan(width:, height:, units:, safe:, over:, pool:)
      end

      # Upright or wide as +safe+'s shape suggests, as roomy as fits;
      # failing that, the other way round; failing that, whichever leaves
      # the board the most room.
      def self.plan(width:, height:, units:, safe:, over:, pool:)
        natural = Planner.landscape?(safe, units)
        plans = [natural, !natural].product(FITS).lazy.map do |landscape, fit|
          Planner.new(width:, height:, units:, safe:, over:, pool:, landscape:, fit:).layout
        end
        plans.find { it.fits?(safe, units) } || plans.max_by { [it.board.width, it.board.height].min }
      end

      # The page the game is set on, when +safe+ is wider than a page
      # with a wide margin either side: page_max wide, centred, a margin
      # from the top and bottom. Otherwise nil.
      def self.paper(safe, units)
        width = units.px(M.page_max)
        return if safe.width < width + (2 * units.px(M.page_margin))

        inset = units.px(M.margin)
        Rect.new(x: safe.x + ((safe.width - width) / 2), y: safe.y + inset, width:, height: safe.height - (2 * inset))
      end

      # The least room the board may have: one smallest cell and the
      # padding around it.
      def self.least_board(units) = units.px(M.cell_min + (2 * M.board_pad))

      # Whether the board has room for a cell and every part is on screen.
      def fits?(safe, units)
        least = Layout.least_board(units)
        board.width >= least && board.height >= least && parts.all? { safe.contains?(it.x, it.y) && it.bottom <= safe.bottom && it.right <= safe.right }
      end

      def parts
        [header, status, *pool, *controls&.each&.map(&:last),
         *results&.then { [it.heading, *it.stats, it.countdown, it.copy, it.again, it.archive] }].compact
      end

      def header_buttons = [[:archive, archive_button], [:help, help_button], [:theme, theme_button], [:sound, sound_button]]

      # Works out a Layout. One is made for every window size and state.
      class Planner
        # Wide enough, in points, to put the pool beside the board, as a
        # phone on its side is.
        def self.landscape?(safe, units)
          wide, tall = units.pt(safe.width), units.pt(safe.height)
          wide >= tall * 1.1 && wide >= 560
        end

        def initialize(width:, height:, units:, safe:, over:, pool:, landscape:, fit:)
          @width, @height, @u, @over, @pool, @landscape, @fit = width, height, units, over, pool, landscape, fit
          @safe = safe
          @margin = px(M.margin)
          @gap = px(fit.gap)
        end

        def layout
          header = Rect.new(x: @safe.x + @margin, y: @safe.y, width: @safe.width - (2 * @margin), height: px(M.header))
          archive, help, theme, sound = header_buttons(header)
          parts = @landscape ? side_column(header) : bottom_stack(header)
          Layout.new(width: @width, height: @height, landscape: @landscape, header:,
                     wordmark: header.with(width: archive.x - header.x), archive_button: archive, help_button: help, theme_button: theme,
                     sound_button: sound, paper: nil, **parts)
        end

        private

        def px(points) = @u.px(points)

        def header_buttons(header)
          size = px(M.touch)
          top = header.y + ((header.height - size) / 2)
          4.times.map { |i| Rect.new(x: header.right - (size * (4 - i)), y: top, width: size, height: size) }
        end

        # Upright: from the bottom of the safe area up, then the board in
        # whatever height is left.
        def bottom_stack(header)
          inner = Rect.new(x: @safe.x + @margin, y: header.bottom, width: @safe.width - (2 * @margin), height: 0)
          bottom = @safe.bottom - @margin
          parts = {status: nil, controls: nil, results: nil}
          pool_slots, pool_height = pool(inner.x, inner.width)

          if @over
            more = centered(inner, bottom - px(M.controls), px(M.controls))
            row = @fit.one_row ? more : centered(inner, more.y - @gap - px(M.controls), px(M.controls))
            stats = centered(inner, row.y - @gap - px(@fit.stats), px(@fit.stats))
            top = stats.y - @gap
            if @pool
              pool_slots = shift(pool_slots, top - pool_height)
              top -= pool_height + @gap
            end
            heading = inner.with(y: top - px(@fit.heading), height: px(@fit.heading))
            parts[:results] = results(heading, stats, row, more)
            top = heading.y
          else
            row = centered(inner, bottom - px(M.controls), px(M.controls))
            parts[:controls] = controls(row)
            pool_slots = shift(pool_slots, row.y - @gap - pool_height)
            above = @pool ? pool_slots.first.y : row.y
            status = inner.with(y: above - @gap - px(M.status), height: px(M.status))
            parts[:status] = status
            top = status.y
          end

          board = Rect.new(x: @safe.x, y: header.bottom, width: @safe.width, height: [top - @gap / 2 - header.bottom, 0].max)
          {board:, pool: @pool ? pool_slots : [], **parts}
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
                      [px(@fit.heading), (@pool ? pool_height : nil), px(@fit.stats), px(M.controls),
                       (@fit.one_row ? nil : px(M.controls))].compact
                    else
                      [px(M.status), (@pool ? pool_height : nil), px(M.controls)].compact
                    end
          stack = heights.sum + (@gap * (heights.size - 1))
          top = column.y + [(column.height - stack) / 2, 0].max
          parts = {status: nil, controls: nil, results: nil}

          if @over
            heading = column.with(y: top, height: px(@fit.heading))
            top = heading.bottom + @gap
            if @pool
              pool_slots = shift(pool_slots, top)
              top += pool_height + @gap
            end
            stats = column.with(y: top, height: px(@fit.stats))
            row = centered(column, stats.bottom + @gap, px(M.controls))
            more = @fit.one_row ? row : centered(column, row.bottom + @gap, px(M.controls))
            parts[:results] = results(heading, stats, row, more)
          else
            parts[:status] = column.with(y: top, height: px(M.status))
            pool_slots = shift(pool_slots, top + px(M.status) + @gap)
            below = @pool ? pool_slots.last.bottom : parts[:status].bottom
            parts[:controls] = controls(centered(column, below + @gap, px(M.controls)))
          end

          board = Rect.new(x: @safe.x, y: header.bottom, width: column.x - @gap - @safe.x,
                           height: @safe.bottom - header.bottom)
          {board:, pool: @pool ? pool_slots : [], **parts}
        end

        # The twelve slots, in rows of six, or four when six would make a
        # tile smaller than a fingertip, centred across +width+; and their
        # height. Their top is 0 until shifted into place. Once the game
        # is over nothing in the pool is tapped again, so it stays in rows
        # of six and may shrink to the Fit's largest tile.
        def pool(left, width)
          gap = px(@fit.tile_gap)
          per_row = Rules::POOL_ROW_LENGTH
          tile = (width - (gap * (per_row - 1))) / per_row
          if tile < px(M.tile_min) && !@over
            gap = [gap, px(4)].min
            tile = (width - (gap * (per_row - 1))) / per_row
          end
          if tile < px(M.tile_min) && !@over
            per_row = 4
            tile = (width - (gap * (per_row - 1))) / per_row
          end
          tile = tile.clamp(1, px(@over ? @fit.pool_max : M.tile_max))
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

        # The clock takes the row's left part, the share button its right;
        # the row under them is split evenly. Packed into one row, the
        # four share it evenly.
        def results(heading, stats, row, more)
          if @fit.one_row
            countdown, copy, again, archive = row.columns(4, px(M.tile_gap))
            return Results.new(heading:, stats: stats.columns(4, px(M.tile_gap)), countdown:, copy:, again:, archive:)
          end

          copy_width = [row.width / 2, px(220)].min
          countdown = row.with(width: row.width - copy_width - @gap)
          copy = row.with(x: row.right - copy_width, width: copy_width)
          again, archive = more.columns(2, px(M.tile_gap))
          Results.new(heading:, stats: stats.columns(4, px(M.tile_gap)), countdown:, copy:, again:, archive:)
        end
      end
    end
  end
end
