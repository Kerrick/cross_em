# frozen_string_literal: true

module CrossEm
  module Shell
    # The win's square confetti, tumbling down over the board.
    class ConfettiPainter
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
      end

      def draw(play)
        area = play.layout.board
        burst, elapsed = play.motion.confetti(area, units: @pen.units, colors: @pen.palette.confetti.size)
        return unless burst

        colors = @pen.palette.confetti
        @pen.clip(area) do
          burst.at(elapsed).each do |x, y, size, angle, color, alpha|
            @pen.color(colors[color], alpha)
            G.push do
              G.translate(x, y)
              G.rotate(angle)
              G.rectangle(:fill, -size / 2.0, -size / 2.0, size, size * 0.8)
            end
          end
        end
      end
    end
  end
end
