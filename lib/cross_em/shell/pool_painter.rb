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
        marks = play.typing.pool_marks
        play.layout.pool.each_with_index do |rect, index|
          @tiles.socket(rect)
          mark(rect) if marks.include?(index)
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

      # A short bar under a slot whose letter the word being typed would
      # use: a light mark, quieter than the caret of a letter picked up.
      def mark(rect)
        width = (rect.width * 0.4).round
        bar = Presentation::Rect.new(x: (rect.center_x - (width / 2.0)).round, y: rect.bottom + @pen.px(3), width:,
                                     height: @pen.px(3))
        @pen.fill(bar, @pen.palette.ink_muted, radius: bar.height / 2)
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
