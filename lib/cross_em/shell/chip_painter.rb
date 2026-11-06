# frozen_string_literal: true

module CrossEm
  module Shell
    # The chip a game that doesn't count wears: a small rounded tag with
    # a dashed edge, as a ghost tile's (nothing here is for keeps), an
    # icon of its own, a word, and, where tapping it goes back to today's
    # game, a ×. Practice has a circling arrow (another go); a look back
    # at a finished board has an eye (to look at, not to change).
    class ChipPainter
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
      end

      def height = @pen.px(28)

      def width(label, close: false)
        @pen.px(10) + icon_size + @pen.px(6) + font.width(label) + (close ? @pen.px(8) + cross_size : 0) + @pen.px(10)
      end

      # Draws the chip for +kind+ (:practice or :review) with its left
      # edge at +x+, centred on +center_y+; answers its rect.
      def draw(kind, label, x, center_y, close: false)
        palette = @pen.palette
        box = Presentation::Rect.new(x: x.round, y: (center_y - (height / 2.0)).round, width: width(label, close:), height:)
        radius = box.height / 2
        @pen.fill(box, palette.card, radius:)
        @pen.dashed(box, palette.ink_muted, width: @pen.stroke(1.5), dash: @pen.px(5), gap: @pen.px(3), radius:)
        left = box.x + @pen.px(10)
        icon = Presentation::Rect.new(x: left, y: box.center_y - (icon_size / 2), width: icon_size, height: icon_size)
        kind == :review ? eye(icon) : again(icon)
        text_x = icon.right + @pen.px(6)
        @pen.text(label, font, text_x, @pen.middle_top(font, box.center_y), palette.ink)
        cross(text_x + font.width(label) + @pen.px(8), box.center_y) if close
        box
      end

      private

      def font = @pen.type.fonts.sans_bold(@pen.px(13))
      def icon_size = @pen.px(14)
      def cross_size = @pen.px(8)

      # A circling arrow: most of a ring, with a head at its end.
      def again(rect)
        ink = @pen.palette.ink
        cx, cy = rect.center_x, rect.center_y
        r = (rect.width / 2.0) - @pen.stroke(1)
        @pen.color(ink)
        G.line_width = @pen.stroke(1.75)
        G.arc(:line, :open, cx, cy, r, -Math::PI * 0.35, Math::PI * 1.45, 18)
        end_angle = -Math::PI * 0.35
        ex, ey = cx + (Math.cos(end_angle) * r), cy + (Math.sin(end_angle) * r)
        head = r * 0.75
        @pen.polygon(ink, ex + (head * 0.6), ey - (head * 0.15), ex - (head * 0.5), ey - (head * 0.55),
                     ex - (head * 0.1), ey + (head * 0.6))
      end

      # An eye: a lens outline and its pupil.
      def eye(rect)
        ink = @pen.palette.ink
        cx, cy = rect.center_x, rect.center_y
        w = rect.width / 2.0
        h = rect.height * 0.32
        steps = 10
        top = (0..steps).flat_map { |i| t = i / steps.to_f; [cx - w + (2 * w * t), cy - (h * Math.sin(Math::PI * t))] }
        bottom = (0..steps).flat_map { |i| t = i / steps.to_f; [cx + w - (2 * w * t), cy + (h * Math.sin(Math::PI * t))] }
        @pen.line(ink, @pen.stroke(1.5), *top, *bottom)
        @pen.circle(:fill, ink, cx, cy, h * 0.62)
      end

      def cross(x, cy)
        size = cross_size
        ink = @pen.palette.ink_muted
        width = @pen.stroke(1.75)
        @pen.line(ink, width, x, cy - (size / 2.0), x + size, cy + (size / 2.0))
        @pen.line(ink, width, x, cy + (size / 2.0), x + size, cy - (size / 2.0))
      end
    end
  end
end
