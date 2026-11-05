# frozen_string_literal: true

module CrossEm
  module Presentation
    # Square confetti for a win, in the share text's colors: a burst from
    # above the board that tumbles down through it and fades. Each piece
    # is worked out from the moment of the burst, so any frame can be drawn
    # from the time alone.
    class Confetti
      # One square: where it starts and how it moves, its size in pixels,
      # its color's index, and how fast it turns.
      Piece = Data.define(:x, :y, :vx, :vy, :size, :color, :spin, :phase, :life)

      GRAVITY = 900.0 # points a second, a second
      LIFE = 2.6

      attr_reader :pieces

      def self.burst(area, units:, colors:, count: 90, random: Random.new)
        pieces = Array.new(count) do
          Piece.new(x: area.x + (random.rand * area.width), y: area.y - units.px(10 + (random.rand * 40)),
                    vx: units.px((random.rand - 0.5) * 220), vy: units.px(-120 - (random.rand * 260)),
                    size: units.px(5 + (random.rand * 5)), color: random.rand(colors), spin: (random.rand - 0.5) * 14,
                    phase: random.rand * Math::PI, life: LIFE * (0.7 + (random.rand * 0.3)))
        end
        new(pieces, units)
      end

      def initialize(pieces, units)
        @pieces, @units = pieces, units
      end

      # Each live piece +elapsed+ seconds after the burst, as [x, y, size,
      # angle, color, alpha].
      def at(elapsed)
        drag = 1.0 / (1.0 + (elapsed * 1.6))
        @pieces.filter_map do |piece|
          next if elapsed > piece.life

          x = piece.x + (piece.vx * elapsed * drag) + (Math.sin((elapsed * 3) + piece.phase) * @units.px(12))
          y = piece.y + (piece.vy * elapsed) + (0.5 * @units.px(GRAVITY) * (elapsed**2) * 0.55)
          alpha = (1 - ((elapsed / piece.life)**3)).clamp(0.0, 1.0)
          [x, y, piece.size, piece.phase + (piece.spin * elapsed), piece.color, alpha]
        end
      end

      def done?(elapsed) = elapsed > LIFE
    end
  end
end
