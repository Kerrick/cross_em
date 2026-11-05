# frozen_string_literal: true

module CrossEm
  module Shell
    # The grid: graph-paper dots at every cell's corners, the letters on
    # it as flat tiles, and, while a letter is picked up, the targets it
    # may go to. Everything is clipped to the board's viewport, which
    # pans when the board is too big for it.
    class BoardPainter
      def initialize(pen, tiles)
        @pen, @tiles = pen, tiles
      end

      def draw(play)
        view = play.view
        game = play.game
        @pen.clip(view.viewport) do
          dots(view)
          targets(view, game) if game.playing? && game.selected
          game.board.positions.each do |position|
            next unless view.visible?(position)

            @tiles.draw(tile_rect(view.rect_of(position)), game.board[position], state: state(game, position),
                                                                                 depth: depth(view))
          end
        end
      end

      # A tile's footprint in its cell, leaving a gap between neighbours.
      def tile_rect(cell)
        gap = [(cell.width * 0.05).round, @pen.px(2)].max
        cell.inset(gap)
      end

      def depth(view) = [(view.cell * 0.06).round, @pen.px(2)].max

      private

      def state(game, position)
        problem = game.check&.problem?(position)
        if game.won? then :finished
        elsif game.lost? then problem ? :problem : :finished
        elsif problem then :problem
        else :plain
        end
      end

      def dots(view)
        size = @pen.stroke(2)
        half = size / 2
        @pen.color(@pen.palette.grid_dot)
        view.visible_columns.each do |column|
          x = view.rect_of(Position.new(column:, row: 0)).x - half
          view.visible_rows.each do |row|
            y = view.rect_of(Position.new(column:, row:)).y - half
            ::Lota::Graphics.rectangle(:fill, x, y, size, size)
          end
        end
      end

      def targets(view, game)
        game.board.targets.each do |position|
          next unless view.visible?(position)

          target(tile_rect(view.rect_of(position)))
        end
      end

      # A dashed square with a small plus: a place the letter can go.
      def target(rect)
        palette = @pen.palette
        width = @pen.stroke(2)
        radius = (rect.width * 0.14).round
        @pen.fill(rect, palette.target, alpha: 0.08, radius:)
        @pen.dashed(rect, palette.target, width:, dash: @pen.px(6), gap: @pen.px(4), radius:)
        arm = (rect.width * 0.14).round
        thick = @pen.stroke(2.5)
        cx = rect.x + ((rect.width - thick) / 2)
        cy = rect.y + ((rect.height - thick) / 2)
        @pen.color(palette.target)
        ::Lota::Graphics.rectangle(:fill, cx - arm + (thick / 2), cy, (2 * arm), thick)
        ::Lota::Graphics.rectangle(:fill, cx, cy - arm + (thick / 2), thick, (2 * arm))
      end
    end
  end
end
