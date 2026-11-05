# frozen_string_literal: true

module CrossEm
  module Shell
    # The grid: graph-paper dots at every cell's corners, the letters on
    # it as flat tiles (or, before the first, a socket where it will go),
    # and, while a letter is picked up, the targets it may go to,
    # breathing. A check sweeps a soft light across it, marking
    # problems as it passes; at the end, the letters take their final
    # faces, in a wave after a win. Everything is clipped to the board's
    # viewport, which pans when the board is too big for it.
    class BoardPainter
      G = ::Lota::Graphics

      def initialize(pen, tiles)
        @pen, @tiles = pen, tiles
      end

      def draw(play)
        view = play.shown_view
        game = play.game
        motion = play.motion
        @pen.clip(view.viewport) do
          dots(view)
          start(view) if game.playing? && game.board.empty? && !game.selected
          targets(view, game, motion.targets) if game.playing? && game.selected
          game.board.positions.each do |position|
            next if !view.visible?(position) || motion.flying?([:cell, position])

            tile(view, game, motion, position)
          end
          sweep(view, motion)
        end
      end

      def depth(view) = [(view.cell * 0.06).round, @pen.px(2)].max

      private

      def tile(view, game, motion, position)
        rect = view.tile_rect(position)
        pose = motion.pose([:cell, position], rect)
        rect = pose.rect.offset((motion.shake(position) * rect.width).round, 0)
        letter = game.board[position]
        problem = game.check&.problem?(position) && motion.checked?(position)
        options = {depth: depth(view), alpha: pose.alpha, squash: pose.squash}
        return @tiles.draw(rect, letter, state: problem ? :problem : :plain, **options) unless game.over?

        settle(rect, letter, game, motion, position, problem, options)
      end

      # The end: after a win, each tile flips over to its finished face;
      # after a loss, the good letters fade to theirs and the problems keep
      # their marks.
      def settle(rect, letter, game, motion, position, problem, options)
        t = motion.finish(position)
        if game.won? && motion.ending_kind == :won && !motion.calm && t < 1.0
          flip = (t - 0.5).abs * 2
          state = t < 0.5 ? :plain : :finished
          return @tiles.draw(rect, letter, state:, flip: [flip, 0.02].max, **options)
        end
        return @tiles.draw(rect, letter, state: :problem, **options) if problem
        return @tiles.draw(rect, letter, state: :finished, **options) if t >= 1.0

        @tiles.draw(rect, letter, state: :plain, **options)
        @tiles.draw(rect, letter, state: :finished, **options, alpha: options[:alpha] * t)
      end

      def dots(view)
        size = @pen.stroke(2)
        half = size / 2
        @pen.color(@pen.palette.grid_dot)
        columns = view.visible_columns.map { view.rect_of(Position.new(column: it, row: 0)).x - half }
        view.visible_rows.each do |row|
          y = view.rect_of(Position.new(column: 0, row:)).y - half
          columns.each { G.rectangle(:fill, it, y, size, size) }
        end
      end

      # On an empty board, a sunken socket where the first letter will go,
      # so the eye has somewhere to look before a letter is picked up. It
      # gives way to the target there as one is.
      def start(view) = @tiles.socket(view.tile_rect(Position::ORIGIN))

      def targets(view, game, alpha)
        game.board.targets.each do |position|
          next unless view.visible?(position)

          target(view.tile_rect(position), alpha)
        end
      end

      # A dashed square with a small plus: a place the letter can go.
      def target(rect, alpha)
        palette = @pen.palette
        width = @pen.stroke(2)
        radius = (rect.width * 0.14).round
        @pen.fill(rect, palette.target, alpha: 0.1 * alpha, radius:)
        @pen.dashed(rect, palette.target, width:, dash: @pen.px(6), gap: @pen.px(4), radius:, alpha:)
        arm = (rect.width * 0.14).round
        thick = @pen.stroke(2.5)
        cx = rect.x + ((rect.width - thick) / 2)
        cy = rect.y + ((rect.height - thick) / 2)
        @pen.color(palette.target, alpha)
        G.rectangle(:fill, cx - arm + (thick / 2), cy, 2 * arm, thick)
        G.rectangle(:fill, cx, cy - arm + (thick / 2), thick, 2 * arm)
      end

      # A soft band of light crossing the letters, left to right.
      def sweep(view, motion)
        progress = motion.sweep or return
        bounds = motion.sweep_bounds or return
        left = view.rect_of(Position.new(column: bounds.left, row: bounds.top))
        right = view.rect_of(Position.new(column: bounds.right, row: bounds.bottom))
        x = left.x + ((right.right - left.x) * progress)
        top = left.y - @pen.px(8)
        height = right.bottom - left.y + @pen.px(16)
        band = view.cell * 1.4
        strips = 14
        strip = (band / strips).ceil
        fade = Math.sin(Math::PI * progress)
        strips.times do |i|
          offset = (i - (strips / 2.0) + 0.5) / (strips / 2.0)
          alpha = Math.exp(-3 * (offset**2)) * fade
          @pen.fill(Presentation::Rect.new(x: (x + (offset * band / 2)).round, y: top, width: strip, height:),
                    @pen.palette.glow, alpha:)
        end
      end
    end
  end
end
