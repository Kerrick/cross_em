# frozen_string_literal: true

module CrossEm
  module Shell
    # The header: the wordmark, with its apostrophe in the accent color,
    # the puzzle's number, and four icon buttons: Past puzzles (a
    # calendar), How to play, the page's appearance (a sun on the light
    # page, a moon on the dark one; tapping flips it), and sound. A game
    # that doesn't count carries a tag by its number, for as long as it
    # is shown: a Practice chip, or a Your board chip for a look back,
    # each a way back to today's game.
    class HeaderPainter
      G = ::Lota::Graphics

      def initialize(pen, chips)
        @pen, @chips = pen, chips
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
        if play.practice? then [:practice, Presentation::Copy::PRACTICE]
        elsif play.review? then [:review, Presentation::Copy::REVIEW]
        end
      end

      # The wordmark, the number and the chip on one line if they fit;
      # else the number alone and the chip, the number smaller and then
      # the chip without its × as room runs out; else the chip alone. The
      # chip's word is never given up: a game that doesn't count always
      # says so. The × says a tap goes back to today's game.
      def tagged(rect, number, (kind, label))
        chip = @chips.width(label, close: true)
        room = rect.width - chip - @pen.px(10)
        font, number_font = fit(room, number)
        if number_font
          wordmark(rect.with(width: room), number)
          x = rect.x + font.width("Cross ’em") + @pen.px(10) + number_font.width(number) + @pen.px(10)
          return @chips.draw(kind, label, x, rect.center_y, close: true)
        end

        slab = @pen.type.fonts.slab(@pen.px(Presentation::Look::SIZES.wordmark - 5))
        sans = @pen.type.fonts.sans_bold(@pen.px(15))
        [[slab, true], [sans, true], [sans, false]].each do |font, close|
          width = @chips.width(label, close:)
          next if font.width(number) + @pen.px(8) + width > rect.width

          @pen.text(number, font, rect.x, @pen.middle_top(font, rect.center_y).round, @pen.palette.ink)
          return @chips.draw(kind, label, rect.x + font.width(number) + @pen.px(8), rect.center_y, close:)
        end
        @chips.draw(kind, label, rect.x, rect.center_y, close: true)
      end

      public

      # The name of the header button the mouse rests on, in a small card
      # under it, kept inside the window.
      def tooltip(play)
        tip = play.tooltip or return
        text, rect = tip
        palette = @pen.palette
        font = @pen.type.fonts.sans_bold(@pen.px(13))
        width = font.width(text) + @pen.px(16)
        height = font.height + @pen.px(10)
        x = (rect.center_x - (width / 2.0)).round.clamp(@pen.px(4), play.layout.width - width - @pen.px(4))
        x = rect.x if rect.width > @pen.px(Presentation::Look::METRICS.touch)
        box = Presentation::Rect.new(x:, y: rect.bottom + @pen.px(2), width:, height:)
        @pen.fill(box.offset(0, @pen.px(2)), palette.shadow, radius: @pen.px(6))
        @pen.fill(box, palette.ink, radius: @pen.px(6))
        @pen.centered(text, font, box, palette.page)
      end

      private

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
