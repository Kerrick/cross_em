# frozen_string_literal: true

module CrossEm
  module Shell
    # What sits by the pool. While playing: the strip, which shows
    # rather than says (the twelve pips that fill as letters go down and
    # turn to marks when the check finds problems; or the word being
    # typed, its letters marked as they are typed), and the controls.
    # Once the game is over, the results: the heading and the count of
    # good letters, the statistics, the clock to the next puzzle, and the
    # share button.
    class PanelPainter
      def initialize(pen, buttons, tiles, chips, keys)
        @pen, @buttons, @tiles, @chips, @keys = pen, buttons, tiles, chips, keys
      end

      def draw(play)
        layout = play.layout
        if (results = layout.results)
          @pen.fading(play.motion.results) { results(play, results) }
        else
          typing = play.typing
          if typing.drafting? then draft(play, layout.status)
          else strip(play, layout.status)
          end
          layout.controls.each { |name, rect| control(play, name, rect) }
        end
      end

      private

      def control(play, name, rect)
        kind = if !play.enabled?(name) then :disabled
               elsif name == :give_up && play.armed? then :danger
               else :plain
               end
        @buttons.draw(rect, play.label(name), kind:, pressed: pressed?(play, name), keys: play.keycaps(name))
      end

      def pressed?(play, name) = play.gesture&.target == [:button, name] && play.gesture.tap?

      # Twelve pips, one a letter: a small tile for each on the board, an
      # empty socket for each in the pool, so the row fills as the board
      # does and is full when the check comes. A problem letter's pip
      # takes the problem's marks as the sweep finds it, and the reasons
      # follow in small type. On an empty board at a computer, two keys
      # under the pips say a word can be typed.
      def strip(play, rect)
        game = play.game
        check = game.check
        problems = check ? check.problems.keys.count { play.motion.checked?(it) } : 0
        placed = game.board.size
        under = if problems.positive? then reasons_line(Presentation::Copy.reasons(check), rect.width)
                elsif game.board.empty? && play.keyboard? then :keys
                end
        pip = @pen.px(12)
        gap = @pen.px(5)
        below = @pen.px(22)
        total = pip + (under ? @pen.px(10) + below : 0)
        top = rect.y + ((rect.height - total) / 2)
        count = Rules::LETTER_COUNT
        left = (rect.center_x - (((count * pip) + ((count - 1) * gap)) / 2.0)).round
        count.times do |i|
          box = Presentation::Rect.new(x: left + (i * (pip + gap)), y: top, width: pip, height: pip)
          state = if i >= placed then :empty
                  elsif i >= placed - problems then :problem
                  else :placed
                  end
          pip(box, state)
        end
        return unless under

        y = top + pip + @pen.px(10)
        under == :keys ? type_keys(rect, y, below) : centered_text(under, @pen.type.reason, rect, y, @pen.palette.problem)
      end

      def pip(box, state)
        palette = @pen.palette
        radius = @pen.px(3)
        case state
        when :placed then @pen.fill(box, palette.ink, radius:)
        when :problem
          @pen.outline(box, palette.problem, width: @pen.stroke(1.5), radius:)
          @pen.line(palette.problem, @pen.stroke(1.5), box.x + 1, box.bottom - 1, box.right - 1, box.y + 1)
        else @pen.outline(box, palette.ink_muted, width: @pen.stroke(1), radius:, alpha: 0.6)
        end
      end

      # A–Z, then ⏎: type a word and press Return.
      def type_keys(rect, y, height)
        widths = [@keys.width("A–Z", height), @keys.width(:return, height)]
        gap = @pen.px(6)
        x = rect.center_x - ((widths.sum + gap) / 2.0)
        x += @keys.draw("A–Z", x, y, height) + gap
        @keys.draw(:return, x, y, height)
      end

      # The word being typed, as ghost tiles with a blinking caret after
      # them. A letter that can't be had is marked as a problem at once;
      # a word whose letters can all be had is outlined in the accent,
      # ready. Under it, the keys that act on it, or the count of places
      # it fits while they are being chosen among. Enter with no place
      # for it shakes it.
      def draft(play, rect)
        typing = play.typing
        letters = typing.draft.chars
        short = typing.short
        ready = short.empty?
        accent = @pen.palette.target
        gap = @pen.px(4)
        room = [letters.size, 8].max
        tile = [@pen.px(32), (rect.width - (gap * (room - 1))) / room].min
        keys = @pen.px(20)
        total = tile + @pen.px(6) + keys
        top = rect.y + ((rect.height - total) / 2)
        width = (letters.size * tile) + ((letters.size - 1) * gap)
        shake = (play.motion.wobble(typing.refused_at) * @pen.px(8)).round
        left = (rect.center_x - (width / 2.0)).round + shake
        letters.each_with_index do |letter, i|
          @tiles.ghost(Presentation::Rect.new(x: left + (i * (tile + gap)), y: top, width: tile, height: tile), letter,
                       color: ready ? accent : nil, short: short.include?(i))
        end
        caret(play, left + width + gap, top, tile) unless typing.choosing?
        y = top + tile + @pen.px(6)
        if (note = Presentation::Copy.misfit(typing.misfit))
          return centered_text(note, @pen.type.reason, rect, y, @pen.palette.problem)
        end

        typing.choosing? ? choosing_keys(typing.choice, rect, y, keys) : draft_keys(rect, y, keys, ready)
      end

      # ⏎ places the word (in the accent when it is ready), Esc clears it.
      def draft_keys(rect, y, height, ready)
        keys = [[:return, ready ? @pen.palette.target : nil], ["Esc", nil]]
        row(rect, y, keys.map { |label, color| [@keys.width(label, height), ->(x) { @keys.draw(label, x, y, height, color:) }] })
      end

      # "1/3", then Tab for the next place, ⏎ to place it, Esc to go back.
      def choosing_keys(choice, rect, y, height)
        font = @pen.type.fonts.sans_bold(@pen.px(14))
        count = Presentation::Copy.of(choice.index, choice.size)
        color = @pen.palette.target
        parts = [[font.width(count), ->(x) { @pen.text(count, font, x, y + ((height - font.height) / 2.0), color) }]]
        parts += [["Tab", nil], [:return, color], ["Esc", nil]].map do |label, ink|
          [@keys.width(label, height), ->(x) { @keys.draw(label, x, y, height, color: ink) }]
        end
        row(rect, y, parts)
      end

      # Parts of known widths side by side, centred in +rect+.
      def row(rect, _y, parts)
        gap = @pen.px(6)
        x = rect.center_x - ((parts.sum(&:first) + (gap * (parts.size - 1))) / 2.0)
        parts.each do |width, draw|
          draw.(x.round)
          x += width + gap
        end
      end

      def centered_text(text, font, rect, y, color)
        @pen.text(text, font, rect.x + ((rect.width - font.width(text)) / 2.0), y, color)
      end

      # A text cursor after the last letter, blinking unless motion is
      # calm.
      def caret(play, x, top, height)
        return if !play.settings.calm && (play.time % 1.0) > 0.55

        @pen.fill(Presentation::Rect.new(x:, y: top + @pen.px(4), width: @pen.stroke(2), height: height - @pen.px(8)),
                  @pen.palette.ink)
      end

      # As many reasons as fit on one line, then how many more.
      def reasons_line(reasons, width)
        font = @pen.type.reason
        shown = reasons.size.downto(1).each do |count|
          text = reasons.first(count).join(" · ")
          text += " · +#{reasons.size - count}" if count < reasons.size
          break text if font.width(text) <= width
        end
        shown.is_a?(String) ? shown : "#{reasons.first[0, 24]}…"
      end

      def results(play, results)
        palette = @pen.palette
        game = play.game
        rect = results.heading
        heading = @pen.type.heading(rect.height)
        sub = @pen.type.subheading
        gap = @pen.px(4)
        total = heading.height + gap + sub.height
        top = rect.y + ((rect.height - total) / 2)
        title = Presentation::Copy.heading(game)
        @pen.text(title, heading, rect.x + ((rect.width - heading.width(title)) / 2.0), top,
                  game.won? ? palette.won : palette.ink)
        tally(game, rect, top + heading.height + gap, sub)
        if (numbers = play.stats) then stats(numbers, results.stats)
        else chip(play, results.stats)
        end
        countdown(play, results.countdown) if play.countdown?
        primary = play.primary
        @buttons.draw(results.copy, play.label(primary), kind: play.next_day ? :plain : :primary,
                                                         pressed: pressed?(play, primary), keys: primary_keys(play, primary))
        %i[again archive].each do |name|
          @buttons.draw(results.public_send(name), play.label(name), pressed: pressed?(play, name), keys: play.keycaps(name))
        end
      end

      # Under the heading: a finished tile and how many letters ended in
      # good words, "7/12", and after a loss why the rest didn't, as many
      # reasons as fit on the line.
      def tally(game, rect, y, font)
        palette = @pen.palette
        count = Presentation::Copy.tally(game.good_letters)
        glyph = font.height - @pen.px(4)
        reasons = game.lost? && game.check ? Presentation::Copy.reasons(game.check) : []
        room = rect.width - glyph - @pen.px(6) - font.width(count) - @pen.px(12)
        why = reasons.empty? ? nil : reasons_line(reasons, room)
        small = @pen.type.reason
        width = glyph + @pen.px(6) + font.width(count) + (why ? @pen.px(12) + small.width(why) : 0)
        x = (rect.center_x - (width / 2.0)).round
        tile = Presentation::Rect.new(x:, y: (y + ((font.height - glyph) / 2.0)).round, width: glyph, height: glyph)
        @pen.fill(tile, palette.finished_edge, radius: @pen.px(3))
        @pen.fill(tile.with(height: glyph - @pen.px(2)), palette.finished_face, radius: @pen.px(3))
        x = tile.right + @pen.px(6)
        @pen.text(count, font, x, y, palette.ink)
        return unless why

        @pen.text(why, small, x + font.width(count) + @pen.px(12), y + ((font.height - small.height) / 2.0), palette.problem)
      end

      # The results' main button's keys: Ctrl/Cmd+C to share, or, back to
      # today, Return, which goes there from the results.
      def primary_keys(play, primary) = primary == :today ? play.keycaps(:next) : play.keycaps(primary)

      # Where the statistics go for a game that doesn't count: its chip,
      # so a practice result is never mistaken for the day's, and for a
      # look back, the day's date.
      def chip(play, rects)
        rect = rects.first.with(width: rects.last.right - rects.first.x)
        kind, label = play.review? ? [:review, Presentation::Copy.date(play.game.day.date)] : [:practice, Presentation::Copy::PRACTICE]
        @chips.draw(kind, label, rect.center_x - (@chips.width(label) / 2.0), rect.center_y)
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
                                                                          pressed: pressed?(play, :next), keys: play.keycaps(:next))
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
        name = Presentation::Copy::NEXT_PUZZLE
        @pen.text(name, label, rect.x + ((rect.width - label.width(name)) / 2.0), top, palette.ink_muted)
        text.chars.zip(widths).each do |char, width|
          @pen.text(char, clock, left + ((width - clock.width(char)) / 2.0), top + label.height, palette.ink)
          left += width
        end
      end
    end
  end
end
