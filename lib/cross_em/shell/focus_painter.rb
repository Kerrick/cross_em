# frozen_string_literal: true

module CrossEm
  module Shell
    # The focus ring, around the one thing A or Enter would act on, while
    # a keyboard's arrows or a controller are in use; and the left stick's
    # cursor while it moves. The ring is ink, standing a little off what
    # it marks, so it never reads as a picked-up tile's own ring; the
    # cursor is a small reticle, on whole pixels, with a halo of the page
    # so it shows over tiles and paper alike.
    class FocusPainter
      def initialize(pen)
        @pen = pen
      end

      def draw(play)
        ring(play)
        cursor(play)
      end

      private

      def ring(play)
        mark = play.focus_mark or return
        rect, shape, clip = mark
        width = @pen.stroke(2)
        gap = @pen.px(3)
        box, radius = case shape
                      when :row then [rect.inset(@pen.px(2)), @pen.px(8)]
                      when :icon then rect.inset(@pen.px(3)).then { [it, it.width / 2] }
                      when :tile then [rect.outset(gap + width), (rect.width * 0.14).round + gap + width]
                      else [rect.outset(gap + width), @pen.px(12) + gap + width]
                      end
        clip ? @pen.clip(clip) { outline(box, width, radius) } : outline(box, width, radius)
      end

      def outline(box, width, radius)
        @pen.outline(box.outset(1), @pen.palette.page, width: 1, radius: radius + 1, alpha: 0.8)
        @pen.outline(box, @pen.palette.ink, width:, radius:)
      end

      def cursor(play)
        cursor = play.cursor
        return unless cursor.visible?

        alpha = cursor.alpha
        palette = @pen.palette
        x, y = cursor.x.round, cursor.y.round
        radius = @pen.px(8)
        width = @pen.stroke(2)
        @pen.circle(:line, palette.page, x, y, radius, alpha: 0.8 * alpha, width: width + 2)
        @pen.circle(:line, palette.ink, x, y, radius, alpha:, width:)
        dot = @pen.px(2)
        @pen.fill(Presentation::Rect.new(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2), palette.ink, alpha:)
      end
    end
  end
end
