# frozen_string_literal: true

module CrossEm
  module Shell
    # The twelve slots: a raised tile for each letter waiting, lifted with
    # a ring and a caret under it, bobbing, when picked up, and a sunken
    # dashed socket where a letter has gone to the grid. After a loss, the
    # letters left over fade inside dotted outlines: unused.
    class PoolPainter
      def initialize(pen, tiles)
        @pen, @tiles = pen, tiles
      end

      def draw(play)
        game = play.game
        motion = play.motion
        play.layout.pool.each_with_index do |rect, index|
          socket(rect)
          letter = game.pool[index]
          next if letter.nil? || motion.flying?([:slot, index])

          pose = motion.pose([:slot, index], rect)
          if game.over?
            unused(pose, letter, motion)
          else
            selected = game.selected == index
            caret(rect) if selected
            @tiles.draw(pose.rect, letter, state: selected ? :selected : :plain, depth: depth(rect),
                                           lift: lift(motion, index), alpha: pose.alpha, squash: pose.squash)
          end
        end
      end

      def depth(rect) = [(rect.height * 0.1).round, @pen.px(3)].max
      def lift(motion, index) = (@pen.px(Presentation::Look::METRICS.lift) * motion.lift(index)).round

      private

      # A letter left over after a loss, fading from a tile to an outline.
      def unused(pose, letter, motion)
        t = motion.finish(Position::ORIGIN)
        @tiles.draw(pose.rect, letter, alpha: 1.0 - t, depth: depth(pose.rect)) if t < 1.0
        @tiles.draw(pose.rect, letter, state: :unused, alpha: t)
      end

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
