# frozen_string_literal: true

module CrossEm
  module Shell
    # Tiles in flight, over everything else on the Play screen: from the
    # pool to the grid, back again, or across the pool in a shuffle. Each
    # is drawn where Motion says it is, on its way to where the rules have
    # already put it.
    class FlightPainter
      def initialize(pen, tiles, board, pool)
        @pen, @tiles, @board, @pool = pen, tiles, board, pool
      end

      def draw(play)
        motion = play.motion
        motion.flying_keys.each do |kind, at|
          kind == :cell ? cell(play, at) : slot(play, at)
        end
      end

      private

      def cell(play, position)
        letter = play.game.board[position] or return
        view = play.shown_view
        pose = play.motion.pose([:cell, position], view.tile_rect(position))
        @tiles.draw(pose.rect, letter, depth: @board.depth(view), alpha: pose.alpha)
      end

      def slot(play, index)
        letter = play.game.pool[index] or return
        rect = play.layout.pool[index] or return
        pose = play.motion.pose([:slot, index], rect)
        selected = play.game.selected == index
        @tiles.draw(pose.rect, letter, state: selected ? :selected : :plain, depth: @pool.depth(rect),
                                       lift: selected ? @pool.lift(play.motion, index) : 0, alpha: pose.alpha)
      end
    end
  end
end
