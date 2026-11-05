# frozen_string_literal: true

module CrossEm
  module Shell
    # The twelve slots: a raised tile for each letter waiting, lifted with
    # a ring and a caret under it when picked up, and a sunken dashed
    # socket where a letter has gone to the grid. After a loss, the
    # letters left over are faded inside dotted outlines: unused.
    class PoolPainter
      def initialize(pen, tiles)
        @pen, @tiles = pen, tiles
      end

      def draw(play)
        game = play.game
        play.layout.pool.each_with_index do |rect, index|
          letter = game.pool[index]
          next socket(rect) unless letter

          if game.over?
            @tiles.draw(rect, letter, state: :unused)
          elsif game.selected == index
            caret(rect)
            @tiles.draw(rect, letter, state: :selected, lift: @pen.px(7), depth: depth(rect))
          else
            @tiles.draw(rect, letter, depth: depth(rect))
          end
        end
      end

      private

      def depth(rect) = [(rect.height * 0.1).round, @pen.px(3)].max

      def socket(rect)
        palette = @pen.palette
        radius = (rect.width * 0.14).round
        @pen.fill(rect, palette.page_shade, radius:)
        @pen.fill(rect.with(height: @pen.px(3)).inset(radius, 0), palette.shadow, alpha: 0.5)
        @pen.dashed(rect, palette.ink_muted, width: @pen.stroke(1), dash: @pen.px(4), gap: @pen.px(3), radius:,
                                             alpha: 0.45)
      end

      # A small upward caret under the slot, pointing at the lifted tile.
      def caret(rect)
        size = @pen.px(5)
        cx = rect.center_x.round
        top = rect.bottom + @pen.px(2)
        @pen.polygon(@pen.palette.ink, cx - size, top + size, cx, top, cx + size, top + size)
      end
    end
  end
end
