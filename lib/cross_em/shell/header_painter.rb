# frozen_string_literal: true

module CrossEm
  module Shell
    # The header: the wordmark, with its apostrophe in the accent color,
    # the puzzle's number, and three icon buttons: How to play, the
    # appearance (following the system, light or dark), and sound.
    class HeaderPainter
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
      end

      def draw(play, appearance:, muted:)
        layout = play.layout
        palette = @pen.palette
        wordmark(layout.wordmark, Presentation::Copy.number(play.game.day))
        @pen.fill(layout.header.with(y: layout.header.bottom - 1, height: 1), palette.rule)
        help(layout.help_button)
        theme(layout.theme_button, appearance)
        sound(layout.sound_button, muted)
      end

      private

      # The wordmark and the number at their sizes if they fit beside the
      # buttons; else in smaller type; else the wordmark alone.
      def wordmark(rect, number)
        palette = @pen.palette
        font, small = fit(rect.width, number)
        top = @pen.middle_top(font, rect.center_y).round
        x = rect.x
        [["Cross ", palette.ink], ["’", palette.target], ["em", palette.ink]].each do |part, color|
          @pen.text(part, font, x, top, color)
          x += font.width(part)
        end
        return unless small

        @pen.text(number, small, x + @pen.px(10), top + font.ascent - small.ascent, palette.ink_muted)
      end

      def fit(room, number)
        sizes = Presentation::Look::SIZES
        [[sizes.wordmark, sizes.number], [sizes.wordmark - 5, sizes.number - 2]].each do |mark, label|
          font = @pen.type.fonts.slab(@pen.px(mark))
          small = @pen.type.fonts.sans(@pen.px(label))
          return [font, small] if font.width("Cross ’em") + @pen.px(10) + small.width(number) <= room - @pen.px(8)
        end
        [@pen.type.fonts.slab(@pen.px(sizes.wordmark - 5)), nil]
      end

      def icon_box(rect) = rect.inset(@pen.px(11))

      def help(rect)
        box = icon_box(rect)
        width = @pen.stroke(2)
        @pen.circle(:line, @pen.palette.ink, box.center_x, box.center_y, (box.width / 2.0) - (width / 2.0), width:)
        @pen.centered("?", @pen.type.fonts.sans_bold(@pen.px(15)), box, @pen.palette.ink)
      end

      # Half a disc for "follow the system", a sun for light, a crescent
      # moon for dark.
      def theme(rect, appearance)
        box = icon_box(rect)
        ink = @pen.palette.ink
        cx, cy = box.center_x, box.center_y
        r = box.width / 2.0
        width = @pen.stroke(2)
        case appearance
        when :system
          @pen.circle(:line, ink, cx, cy, r - (width / 2.0), width:)
          @pen.color(ink)
          G.arc(:fill, :pie, cx, cy, r - (width / 2.0), Math::PI * 0.5, Math::PI * 1.5, 24)
        when :light
          @pen.circle(:line, ink, cx, cy, r * 0.42, width:)
          8.times do |i|
            angle = i * Math::PI / 4
            @pen.line(ink, width, cx + (Math.cos(angle) * r * 0.66), cy + (Math.sin(angle) * r * 0.66),
                      cx + (Math.cos(angle) * r * 0.95), cy + (Math.sin(angle) * r * 0.95))
          end
        else
          @pen.circle(:fill, ink, cx, cy, r * 0.82)
          @pen.circle(:fill, @pen.palette.page, cx + (r * 0.42), cy - (r * 0.3), r * 0.7)
        end
      end

      # A speaker, with sound waves when on and a cross when muted.
      def sound(rect, muted)
        box = icon_box(rect)
        ink = @pen.palette.ink
        x, y, s = box.x, box.y, box.width
        @pen.polygon(ink, x + (s * 0.08), y + (s * 0.36), x + (s * 0.3), y + (s * 0.36), x + (s * 0.3), y + (s * 0.64),
                     x + (s * 0.08), y + (s * 0.64))
        @pen.polygon(ink, x + (s * 0.3), y + (s * 0.36), x + (s * 0.55), y + (s * 0.14), x + (s * 0.55), y + (s * 0.86),
                     x + (s * 0.3), y + (s * 0.64))
        width = @pen.stroke(2)
        if muted
          @pen.line(ink, width, x + (s * 0.68), y + (s * 0.36), x + (s * 0.94), y + (s * 0.64))
          @pen.line(ink, width, x + (s * 0.68), y + (s * 0.64), x + (s * 0.94), y + (s * 0.36))
        else
          @pen.color(ink)
          G.line_width = width
          G.arc(:line, :open, x + (s * 0.5), y + (s * 0.5), s * 0.22, -0.8, 0.8, 12)
          G.arc(:line, :open, x + (s * 0.5), y + (s * 0.5), s * 0.42, -0.8, 0.8, 16)
        end
      end
    end
  end
end
