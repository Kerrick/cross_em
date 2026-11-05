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
        @panel = PanelPainter.new(pen, buttons)
        @sheet = SheetPainter.new(pen, buttons)
        @flights = FlightPainter.new(pen, tiles, @board, @pool)
        @confetti = ConfettiPainter.new(pen)
      end

      def draw(play, appearance:, muted:)
        page = @pen.palette.page
        G.clear(page.r, page.g, page.b, 1.0)
        # Hard-edged lines: an edge on a pixel boundary stays sharp, and
        # the window's multisampling smooths the curves.
        G.line_style = :rough
        G.line_join = :miter
        @board.draw(play)
        @header.draw(play, appearance:, muted:)
        @pool.draw(play)
        @panel.draw(play)
        @flights.draw(play)
        @confetti.draw(play)
        @sheet.draw(play)
      end
    end
  end
end
