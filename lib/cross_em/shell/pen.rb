# frozen_string_literal: true

module CrossEm
  module Shell
    # What every painter draws with: the palette, the type, and shapes
    # and text placed on whole pixels. Rectangles come in whole pixels
    # from the Layout; a stroke is drawn inside its rectangle with its
    # edges on pixel boundaries; text starts at a whole pixel, so it is
    # never resampled.
    class Pen
      G = ::Lota::Graphics
      SEGMENTS = 12

      attr_reader :units, :type
      attr_accessor :palette

      def initialize(units:, type:, palette:)
        @units, @type, @palette = units, type, palette
        @fade = 1.0
      end

      # Draws the block with everything +alpha+ times as opaque.
      def fading(alpha)
        before = @fade
        @fade *= alpha
        yield
      ensure
        @fade = before
      end

      def px(points) = units.px(points)
      def stroke(points) = units.stroke(points)

      def color(color, alpha = 1.0) = G.color = [color.r, color.g, color.b, color.a * alpha * @fade]

      def fill(rect, color, alpha: 1.0, radius: 0)
        return if rect.empty?

        color(color, alpha)
        radius = radius.clamp(0, [rect.width, rect.height].min / 2.0)
        if radius.positive?
          G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, radius, radius, SEGMENTS)
        else
          G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height)
        end
      end

      # A line +width+ pixels wide just inside +rect+'s edge.
      def outline(rect, color, width: 1, alpha: 1.0, radius: 0)
        return if rect.empty?

        color(color, alpha)
        G.line_width = width
        half = width / 2.0
        radius = (radius - half).clamp(0, [rect.width, rect.height].min / 2.0)
        if radius.positive?
          G.rectangle(:line, rect.x + half, rect.y + half, rect.width - width, rect.height - width, radius, radius,
                      SEGMENTS)
        else
          G.rectangle(:line, rect.x + half, rect.y + half, rect.width - width, rect.height - width)
        end
      end

      # Dashes +width+ pixels thick along the inside of +rect+'s straight
      # edges, each +dash+ long with +gap+ between, centred on each side,
      # and the rounded corners drawn whole.
      def dashed(rect, color, width:, dash:, gap:, radius:, alpha: 1.0)
        color(color, alpha)
        radius = radius.clamp(0, [rect.width, rect.height].min / 2)
        [[rect.x + radius, rect.right - radius, :across], [rect.y + radius, rect.bottom - radius, :down]].each do |from, to, way|
          length = to - from
          count = [((length + gap) / (dash + gap)).floor, 1].max
          used = (count * dash) + ((count - 1) * gap)
          start = from + ((length - used) / 2)
          count.times do |i|
            at = start + (i * (dash + gap))
            if way == :across
              G.rectangle(:fill, at, rect.y, dash, width)
              G.rectangle(:fill, at, rect.bottom - width, dash, width)
            else
              G.rectangle(:fill, rect.x, at, width, dash)
              G.rectangle(:fill, rect.right - width, at, width, dash)
            end
          end
        end
        return unless radius.positive?

        G.line_width = width
        r = radius - (width / 2.0)
        [[rect.x + radius, rect.y + radius, Math::PI, Math::PI * 1.5],
         [rect.right - radius, rect.y + radius, Math::PI * 1.5, Math::PI * 2],
         [rect.right - radius, rect.bottom - radius, 0, Math::PI * 0.5],
         [rect.x + radius, rect.bottom - radius, Math::PI * 0.5, Math::PI]].each do |cx, cy, from, to|
          G.arc(:line, :open, cx, cy, r, from, to, 6)
        end
      end

      def line(color, width, *points, alpha: 1.0)
        color(color, alpha)
        G.line_width = width
        G.line(*points)
      end

      def polygon(color, *points, alpha: 1.0)
        color(color, alpha)
        G.polygon(:fill, *points)
      end

      def circle(mode, color, x, y, radius, alpha: 1.0, width: nil)
        color(color, alpha)
        G.line_width = width if width
        G.circle(mode, x, y, radius, 48)
      end

      # +text+ with its top-left at (+x+, +y+), on whole pixels.
      def text(text, font, x, y, color, alpha: 1.0)
        color(color, alpha)
        G.print(text, font, x.round, y.round)
      end

      # +text+ centred in +rect+: across by its width, down by its
      # capitals and x-height, which looks centred where the full line
      # height (with room for descenders) does not.
      def centered(text, font, rect, color, alpha: 1.0)
        x = rect.x + ((rect.width - font.width(text)) / 2.0)
        text(text, font, x, middle_top(font, rect.center_y), color, alpha:)
      end

      # Where a line's top goes so its capitals are centred on +y+.
      def middle_top(font, y) = y - font.ascent + (cap_height(font) / 2.0)

      # The height of a capital, near enough: about seven tenths of the
      # ascent in both faces.
      def cap_height(font) = font.ascent * 0.72

      # Draws the block with drawing limited to +rect+ (inside any limit
      # already set).
      def clip(rect)
        before = G.scissor
        G.intersect_scissor(*rect.to_a)
        yield
      ensure
        G.scissor = before.empty? ? nil : before
      end
    end
  end
end
