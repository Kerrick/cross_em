# frozen_string_literal: true

module CrossEm
  module Shell
    # The words and buttons around the pool: while playing, the status
    # line and the controls; once the game is over, the results: the
    # heading, the statistics, the clock to the next puzzle, and the share
    # button.
    class PanelPainter
      def initialize(pen, buttons)
        @pen, @buttons = pen, buttons
      end

      def draw(play)
        layout = play.layout
        if (results = layout.results)
          @pen.fading(play.motion.results) { results(play, results) }
        else
          status(play.status, layout.status)
          layout.controls.each { |name, rect| control(play, name, rect) }
        end
      end

      private

      def control(play, name, rect)
        kind = if !play.enabled?(name) then :disabled
               elsif name == :give_up && play.armed? then :danger
               else :plain
               end
        @buttons.draw(rect, play.label(name), kind:, pressed: pressed?(play, name))
      end

      def pressed?(play, name) = play.gesture&.target == [:button, name] && play.gesture.tap?

      # The sentence, wrapped to two lines at most, and under it the
      # reasons for any problems, as many as fit, or the detail.
      def status(status, rect)
        palette = @pen.palette
        font = @pen.type.status
        lines = lines(status.text, font, rect.width)
        small = @pen.type.reason
        extra = status.reasons.empty? ? status.detail : reasons(status.reasons, small, rect.width)
        line = (font.height * 1.15).round
        total = (lines.size * line) + (extra ? (small.height * 1.2).round : 0)
        top = rect.y + ((rect.height - total) / 2)
        lines.each_with_index do |text, i|
          @pen.text(text, font, rect.x + ((rect.width - font.width(text)) / 2.0), top + (i * line), palette.ink)
        end
        return unless extra

        color = status.reasons.empty? ? palette.ink_muted : palette.problem
        @pen.text(extra, small, rect.x + ((rect.width - small.width(extra)) / 2.0), top + (lines.size * line) + @pen.px(2), color)
      end

      # One line if it fits; else a line a sentence, so a line never ends
      # with a lone word; at most two.
      def lines(text, font, width)
        return [text] if font.width(text) <= width

        sentences = text.split(/(?<=\.) /)
        sentences = font.wrap(text, width)[1] if sentences.size < 2 || sentences.any? { font.width(it) > width }
        sentences.first(2)
      end

      # As many reasons as fit on one line, then how many more.
      def reasons(reasons, font, width)
        shown = reasons.size.downto(1).each do |count|
          text = reasons.first(count).join("; ")
          text += "; +#{reasons.size - count} more" if count < reasons.size
          break text if font.width(text) <= width
        end
        shown.is_a?(String) ? shown : "#{reasons.first[0, 30]}…"
      end

      def results(play, results)
        palette = @pen.palette
        game = play.game
        status = play.status
        rect = results.heading
        heading = @pen.type.heading(rect.height)
        sub = @pen.type.subheading
        gap = @pen.px(4)
        total = heading.height + gap + sub.height
        top = rect.y + ((rect.height - total) / 2)
        title_color = game.won? ? palette.won : palette.ink
        @pen.text(status.text, heading, rect.x + ((rect.width - heading.width(status.text)) / 2.0), top, title_color)
        @pen.text(status.detail, sub, rect.x + ((rect.width - sub.width(status.detail)) / 2.0),
                  top + heading.height + gap, palette.ink_muted)
        stats(play.stats, results.stats)
        countdown(play, results.countdown)
        @buttons.draw(results.copy, play.label(:copy), kind: play.next_day ? :plain : :primary,
                                                      pressed: pressed?(play, :copy))
      end

      def stats(stats, rects)
        palette = @pen.palette
        number = @pen.type.stat
        label = @pen.type.stat_label
        values = [stats.played, stats.win_percent, stats.current_streak, stats.max_streak]
        rects.zip(values, Presentation::Copy::STAT_LABELS).each_with_index do |(rect, value, name), i|
          total = number.height + label.height
          top = rect.y + ((rect.height - total) / 2)
          text = value.to_s
          @pen.text(text, number, rect.x + ((rect.width - number.width(text)) / 2.0), top, palette.ink)
          @pen.text(name, label, rect.x + ((rect.width - label.width(name)) / 2.0), top + number.height, palette.ink_muted)
          next if i.zero?

          @pen.fill(Presentation::Rect.new(x: rect.x - (@pen.px(4) + 1) + 1, y: rect.y + @pen.px(8), width: 1,
                                           height: rect.height - @pen.px(16)), palette.rule)
        end
      end

      # The clock, its digits each in a cell as wide as the widest, so it
      # ticks without shuffling sideways; or, once it has run out, the
      # button to the next puzzle.
      def countdown(play, rect)
        if (day = play.next_day)
          return @buttons.draw(rect, Presentation::Copy.play_number(day), kind: :primary,
                                                                          pressed: pressed?(play, :next))
        end

        palette = @pen.palette
        label = @pen.type.countdown_label
        clock = @pen.type.countdown
        text = play.countdown.to_s
        digit = %w[0 1 2 3 4 5 6 7 8 9].map { clock.width(it) }.max
        widths = text.chars.map { it == ":" ? clock.width(":") : digit }
        total = label.height + clock.height
        top = rect.y + ((rect.height - total) / 2)
        left = rect.x + ((rect.width - widths.sum) / 2.0).round
        @pen.text(Presentation::Copy::NEXT_PUZZLE, label,
                  rect.x + ((rect.width - label.width(Presentation::Copy::NEXT_PUZZLE)) / 2.0), top, palette.ink_muted)
        text.chars.zip(widths).each do |char, width|
          @pen.text(char, clock, left + ((width - clock.width(char)) / 2.0), top + label.height, palette.ink)
          left += width
        end
      end
    end
  end
end
