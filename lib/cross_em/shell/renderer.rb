# frozen_string_literal: true

module CrossEm
  module Shell
    # Draws a frame of the Play screen, straight to the window at its own
    # resolution: the page, the board, the header, the pool, the status
    # and controls or the results, the tiles in flight over them, any
    # confetti, and any sheet over everything.
    class Renderer
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
        tiles = TilePainter.new(pen)
        buttons = ButtonPainter.new(pen)
        @board = BoardPainter.new(pen, tiles)
        @pool = PoolPainter.new(pen, tiles)
        @header = HeaderPainter.new(pen)
        @panel = PanelPainter.new(pen, buttons, tiles)
        @sheet = SheetPainter.new(pen, buttons, tiles)
        @flights = FlightPainter.new(pen, tiles, @board, @pool)
        @confetti = ConfettiPainter.new(pen)
      end

      def draw(play, dark:, muted:)
        # Hard-edged lines: an edge on a pixel boundary stays sharp, and
        # the window's multisampling smooths the curves.
        G.line_style = :rough
        G.line_join = :miter
        paper(play.layout.paper)
        @board.draw(play)
        @header.draw(play, dark:, muted:)
        @pool.draw(play)
        @panel.draw(play)
        @flights.draw(play)
        @confetti.draw(play)
        @sheet.draw(play)
      end

      private

      # The page: the whole window, or, in a very wide one, a sheet of
      # paper lying on a darker desk, with a soft shadow and a hairline
      # edge.
      def paper(rect)
        palette = @pen.palette
        ground = rect ? palette.page_shade : palette.page
        G.clear(ground.r, ground.g, ground.b, 1.0)
        return unless rect

        radius = @pen.px(6)
        @pen.fill(rect.offset(0, @pen.px(3)), palette.shadow, radius:)
        @pen.fill(rect, palette.page, radius:)
        @pen.outline(rect, palette.rule, radius:)
      end
    end
  end
end
