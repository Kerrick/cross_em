# frozen_string_literal: true

module CrossEm
  module Shell
    # The header: the wordmark, with its apostrophe in the accent color,
    # the puzzle's number, and four icon buttons: Past puzzles (a
    # calendar), How to play, the page's appearance (a sun on the light
    # page, a moon on the dark one; tapping flips it), and sound. A game
    # that doesn't count carries a tag by its number, for as long as it
    # is shown: "Practice · doesn't count", or "Your board · read-only".
    class HeaderPainter
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
      end

      def draw(play, dark:, muted:)
        layout = play.layout
        palette = @pen.palette
        number = Presentation::Copy.number(play.game.day)
        if (tag = tag_of(play)) then tagged(layout.wordmark, number, tag)
        else wordmark(layout.wordmark, number)
        end
        @pen.fill(layout.header.with(y: layout.header.bottom - 1, height: 1), palette.rule)
        calendar(layout.archive_button)
        help(layout.help_button)
        theme(layout.theme_button, dark)
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

      def tag_of(play)
        copy = Presentation::Copy
        if play.practice? then [copy::PRACTICE, copy::PRACTICE_DETAIL]
        elsif play.review? then [copy::REVIEW, copy::REVIEW_DETAIL]
        end
      end

      # The wordmark, the number and the tag on one line if they fit;
      # else the number alone, in the wordmark's slab, with the tag beside
      # it on two lines; else the number inside the tag.
      def tagged(rect, number, (label, detail))
        palette = @pen.palette
        sizes = Presentation::Look::SIZES
        bold = @pen.type.fonts.sans_bold(@pen.px(13))
        small = @pen.type.fonts.sans(@pen.px(13))
        inline = "#{label} · #{detail}"
        font, number_font = fit(rect.width - pill_width(bold, inline) - @pen.px(10), number)
        if number_font
          wordmark(rect.with(width: rect.width - pill_width(bold, inline) - @pen.px(10)), number)
          x = rect.x + font.width("Cross ’em") + @pen.px(10) + number_font.width(number) + @pen.px(10)
          return pill(x, rect.center_y, [[inline, bold]], palette)
        end

        slab = @pen.type.fonts.slab(@pen.px(sizes.wordmark - 5))
        stacked = [[label, bold], [detail, small]]
        x = rect.x
        if slab.width(number) + @pen.px(10) + pill_width(bold, label, detail) <= rect.width
          @pen.text(number, slab, x, @pen.middle_top(slab, rect.center_y).round, palette.ink)
          return pill(x + slab.width(number) + @pen.px(10), rect.center_y, stacked, palette)
        end
        pill(x, rect.center_y, [["#{number} · #{label}", bold], [detail, small]], palette)
      end

      def pill_width(font, *lines) = lines.map { font.width(it) }.max + @pen.px(16)

      # A rounded outline around one or two short lines, the first in ink,
      # the second muted.
      def pill(x, center_y, lines, palette)
        width = lines.map { |text, font| font.width(text) }.max + @pen.px(16)
        line = lines.first[1].height
        height = (line * lines.size) + @pen.px(8)
        box = Presentation::Rect.new(x: x.round, y: (center_y - (height / 2.0)).round, width:, height:)
        @pen.outline(box, palette.ink_muted, width: @pen.stroke(1.5), radius: @pen.px(8))
        lines.each_with_index do |(text, font), i|
          @pen.text(text, font, box.x + @pen.px(8), box.y + @pen.px(4) + (i * line), i.zero? ? palette.ink : palette.ink_muted)
        end
      end

      def icon_box(rect) = rect.inset(@pen.px(11))

      # A calendar page: a ring-bound top band and a few days.
      def calendar(rect)
        box = icon_box(rect)
        ink = @pen.palette.ink
        width = @pen.stroke(2)
        page = box.with(y: box.y + @pen.px(2), height: box.height - @pen.px(2))
        @pen.outline(page, ink, width:, radius: @pen.px(3))
        @pen.fill(page.with(height: @pen.px(6)), ink, radius: @pen.px(2))
        [0.3, 0.7].each do |at|
          x = (box.x + (box.width * at)).round - (width / 2)
          @pen.fill(Presentation::Rect.new(x:, y: box.y - @pen.px(1), width:, height: @pen.px(5)), ink)
        end
        dot = @pen.px(3)
        [0.28, 0.5, 0.72].product([0.55, 0.78]).each do |fx, fy|
          @pen.fill(Presentation::Rect.new(x: (page.x + (page.width * fx)).round - (dot / 2),
                                           y: (page.y + (page.height * fy)).round - (dot / 2), width: dot, height: dot), ink)
        end
      end

      def help(rect)
        box = icon_box(rect)
        width = @pen.stroke(2)
        @pen.circle(:line, @pen.palette.ink, box.center_x, box.center_y, (box.width / 2.0) - (width / 2.0), width:)
        @pen.centered("?", @pen.type.fonts.sans_bold(@pen.px(15)), box, @pen.palette.ink)
      end

      # A sun on the light page, a crescent moon on the dark one.
      def theme(rect, dark)
        box = icon_box(rect)
        ink = @pen.palette.ink
        cx, cy = box.center_x, box.center_y
        r = box.width / 2.0
        width = @pen.stroke(2)
        if dark
          @pen.circle(:fill, ink, cx, cy, r * 0.82)
          @pen.circle(:fill, @pen.palette.page, cx + (r * 0.42), cy - (r * 0.3), r * 0.7)
        else
          @pen.circle(:fill, ink, cx, cy, r * 0.36)
          8.times do |i|
            angle = i * Math::PI / 4
            @pen.line(ink, width, cx + (Math.cos(angle) * r * 0.62), cy + (Math.sin(angle) * r * 0.62),
                      cx + (Math.cos(angle) * r * 0.95), cy + (Math.sin(angle) * r * 0.95))
          end
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
