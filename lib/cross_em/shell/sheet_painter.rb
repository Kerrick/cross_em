# frozen_string_literal: true

module CrossEm
  module Shell
    # A sheet over the Play screen: the page dimmed behind, a paper card
    # with its title and a close button, and the body, which scrolls,
    # clipped to the card, with a thin bar to show where it is.
    class SheetPainter
      def initialize(pen, buttons, tiles)
        @pen, @buttons, @tiles = pen, buttons, tiles
      end

      def draw(play)
        sheet = play.sheet or return
        layout = play.sheet_layout
        palette = @pen.palette
        @pen.fill(Presentation::Rect.new(x: 0, y: 0, width: play.layout.width, height: play.layout.height), palette.scrim)
        radius = @pen.px(16)
        @pen.fill(layout.card.offset(0, @pen.px(4)), palette.shadow, radius:)
        @pen.fill(layout.card, palette.card, radius:)
        @pen.outline(layout.card, palette.rule, radius:)

        title = title_font(sheet.title, (layout.link&.rect || layout.close).x - layout.title.x - @pen.px(8))
        @pen.text(sheet.title, title, layout.title.x, @pen.middle_top(title, layout.title.center_y), palette.ink)
        close(layout.close)
        link(layout.link, play) if layout.link
        @pen.fill(layout.title.with(y: layout.title.bottom - 1, height: 1), palette.rule)

        if layout.is_a?(Presentation::ArchiveLayout) then archive(play, layout, sheet)
        else body(play, layout, sheet.scroll)
        end
        return unless layout.scrolls?

        fades(layout, sheet.scroll)
        scrollbar(layout, sheet.scroll)
      end

      private

      def close(rect)
        box = rect.inset(@pen.px(14))
        width = @pen.stroke(2)
        ink = @pen.palette.ink
        @pen.line(ink, width, box.x, box.y, box.right, box.bottom)
        @pen.line(ink, width, box.x, box.bottom, box.right, box.y)
      end

      # The title's slab at its size, or smaller where a narrow card
      # leaves it less room beside the title bar's buttons.
      def title_font(text, room)
        size = Presentation::Look::SIZES.sheet_title
        [size, size - 4, size - 7].each do |points|
          font = @pen.type.fonts.slab(@pen.px(points))
          return font if font.width(text) <= room
        end
        @pen.type.fonts.slab(@pen.px(size - 7))
      end

      # A button in the title bar, as the body's buttons look, a little
      # shorter than its reach.
      def link(control, play)
        pressed = play.gesture&.target == [:sheet, :link] && play.gesture.tap?
        @buttons.draw(control.rect.inset(0, @pen.px(5)), control.text, kind: :plain, pressed:, keys: play.keycaps(control.id))
      end

      def body(play, layout, scroll)
        body = layout.body
        top = body.y - scroll
        @pen.clip(body) do
          line_height = @pen.type.line_height(:license)
          layout.lines.each do |line|
            y = top + line.y
            next if y + line_height < body.y || y > body.bottom

            mark(line, body, y, line_height)
          end
          layout.examples.each do |example|
            rect = example.rect.offset(body.x, top)
            example(example, rect) unless rect.bottom < body.y || rect.y > body.bottom
          end
          layout.controls.each do |control|
            rect = control.rect.offset(body.x, top)
            next if rect.bottom < body.y || rect.y > body.bottom

            control.kind == :toggle ? toggle(rect, control, play.settings) : button(rect, control, play)
          end
        end
      end

      # Past puzzles: only the rows in view, each month's heading pinned
      # to the top while its days scroll under it, until the next month's
      # pushes it away.
      def archive(play, layout, sheet)
        scroll = sheet.scroll
        rows = layout.visible(scroll)
        return if rows.empty?

        @pen.clip(layout.body) do
          rows.each do |row|
            rect = layout.row_rect(row, scroll)
            row.month? ? month(rect, row) : day(play, rect, row)
          end
          heading, rect = layout.pinned(scroll)
          month(rect, heading) if heading
        end
      end

      def month(rect, row)
        palette = @pen.palette
        @pen.fill(rect, palette.card)
        font = @pen.type.style(:heading)
        pad = @pen.px(12)
        @pen.text(Presentation::Copy.month(row.date), font, rect.x + pad, rect.bottom - font.height - @pen.px(6), palette.ink)
        @pen.fill(rect.with(y: rect.bottom - 1, height: 1).inset(pad, 0), palette.rule)
      end

      # A day: its number and date at the left, and at the right how the
      # player did, as a glyph whose shape says it, never by color alone,
      # and a count out of twelve: good letters for a finished game,
      # letters placed for one in progress. The counts line up in a
      # column, so the glyphs do too.
      def day(play, rect, row)
        palette = @pen.palette
        pad = @pen.px(12)
        pressed = play.gesture&.target == [:sheet, :body] && play.gesture.tap? && rect.contains?(play.gesture.x, play.gesture.y)
        @pen.fill(rect.inset(@pen.px(2)), palette.page_shade, radius: @pen.px(8)) if pressed
        title = @pen.type.style(:toggle)
        small = @pen.type.style(:small)
        top = rect.y + ((rect.height - title.height - small.height) / 2)
        today = row.number == play.archive_list.today.number
        date = Presentation::Copy.date(row.date)
        @pen.text(Presentation::Copy.number(row.day), title, rect.x + pad, top, palette.ink)
        @pen.text(today ? "#{Presentation::Copy::TODAY} · #{date}" : date, small, rect.x + pad, top + title.height, palette.ink_muted)

        record = row.record
        count = case row.status
                when :won then Presentation::Copy.tally(Rules::LETTER_COUNT)
                when :lost then Presentation::Copy.tally(play.good_letters(record))
                when :playing then Presentation::Copy.tally(record.board.size)
                end
        right = rect.right - pad
        size = @pen.px(22)
        if count
          font = @pen.type.style(:toggle)
          width = font.width(Presentation::Copy.tally(Rules::LETTER_COUNT))
          @pen.text(count, font, right - font.width(count), @pen.middle_top(font, rect.center_y), palette.ink)
          right -= width + @pen.px(10)
        end
        glyph(row.status, right - (size / 2.0), rect.center_y, size / 2.0)
        @pen.fill(rect.with(y: rect.bottom - 1, height: 1).inset(pad, 0), palette.rule)
      end

      # Solved: a filled disc with a tick. Game over: a ring with a cross.
      # In progress: a ring half filled. Not played: a faint dashed ring.
      def glyph(status, cx, cy, r)
        palette = @pen.palette
        width = @pen.stroke(1.5)
        case status
        when :won
          @pen.circle(:fill, palette.won, cx, cy, r)
          @pen.line(palette.page, @pen.stroke(2), cx - (r * 0.45), cy + (r * 0.02), cx - (r * 0.1), cy + (r * 0.38),
                    cx + (r * 0.5), cy - (r * 0.35))
        when :lost
          @pen.circle(:line, palette.ink_muted, cx, cy, r - (width / 2.0), width:)
          k = r * 0.38
          @pen.line(palette.ink_muted, width, cx - k, cy - k, cx + k, cy + k)
          @pen.line(palette.ink_muted, width, cx - k, cy + k, cx + k, cy - k)
        when :playing
          @pen.circle(:line, palette.target, cx, cy, r - (width / 2.0), width:)
          @pen.color(palette.target)
          ::Lota::Graphics.arc(:fill, :pie, cx, cy, r - width, Math::PI / 2, Math::PI * 1.5, 24)
        else
          @pen.color(palette.ink_muted, 0.6)
          ::Lota::Graphics.line_width = width
          10.times do |i|
            from = i * Math::PI / 5
            ::Lota::Graphics.arc(:line, :open, cx, cy, r - (width / 2.0), from, from + (Math::PI / 10), 4)
          end
        end
      end

      # A patch of the game's graph paper with a few tiles crossing on it
      # and a glowing square, drawn as the board draws them.
      def example(example, rect)
        palette = @pen.palette
        @pen.fill(rect, palette.page, radius: @pen.px(10))
        cells = (-1..8).flat_map { |column| (-1..4).map { |row| example.cell_rect(column, row, rect) } }
        size = @pen.stroke(2)
        @pen.clip(rect.inset(@pen.px(4))) do
          cells.each { @pen.fill(Presentation::Rect.new(x: it.x - (size / 2), y: it.y - (size / 2), width: size, height: size), palette.grid_dot) }
        end
        inset = ->(cell) { cell.inset([(cell.width * 0.05).round, 2].max) }
        @tiles.target(inset.(example.cell_rect(*example.target, rect)))
        example.tiles.each do |letter, column, row|
          @tiles.draw(inset.(example.cell_rect(column, row, rect)), letter, depth: @pen.px(3))
        end
      end

      # A line of text, or a license's rule, or the bar beside a quote.
      def mark(line, body, y, line_height)
        case line.style
        when :rule then @pen.fill(Presentation::Rect.new(x: body.x, y:, width: body.width, height: 1), @pen.palette.rule)
        when :quote
          @pen.fill(Presentation::Rect.new(x: body.x + line.x, y:, width: @pen.stroke(2), height: line_height),
                    @pen.palette.rule)
        else @pen.text(line.text, @pen.type.style(line.style), body.x + line.x, y, color(line.style))
        end
      end

      def color(style)
        case style
        when :small, :license then @pen.palette.ink_muted
        else @pen.palette.ink
        end
      end

      def button(rect, control, play)
        pressed = play.gesture&.target == [:sheet, :body] && play.gesture.tap? &&
                  rect.contains?(play.gesture.x, play.gesture.y)
        @buttons.draw(rect, control.text, kind: control.primary ? :primary : :plain, pressed:)
      end

      # A setting's name and what it does, and a switch: its knob at the
      # right and filled when on, at the left and hollow when off.
      def toggle(rect, control, settings)
        palette = @pen.palette
        on = settings.public_send(control.id)
        label = @pen.type.style(:toggle)
        detail = @pen.type.style(:small)
        switch = Presentation::Rect.new(x: rect.right - @pen.px(52), y: (rect.center_y - @pen.px(16)).round,
                                        width: @pen.px(52), height: @pen.px(32))
        _, lines = detail.wrap(control.detail, switch.x - rect.x - @pen.px(12))
        total = label.height + (lines.size * detail.height)
        top = rect.y + ((rect.height - total) / 2)
        @pen.text(control.text, label, rect.x, top, palette.ink)
        lines.each_with_index do |line, i|
          @pen.text(line, detail, rect.x, top + label.height + (i * detail.height), palette.ink_muted)
        end
        radius = switch.height / 2
        if on
          @pen.fill(switch, palette.target, radius:)
        else
          @pen.fill(switch, palette.page_shade, radius:)
          @pen.outline(switch, palette.ink_muted, width: @pen.stroke(1.5), radius:)
        end
        knob = switch.height - (@pen.px(4) * 2)
        x = on ? switch.right - @pen.px(4) - knob : switch.x + @pen.px(4)
        @pen.fill(Presentation::Rect.new(x:, y: switch.y + @pen.px(4), width: knob, height: knob),
                  on ? palette.card : palette.ink_muted, radius: knob / 2)
      end

      # The body's text fades into the card at an edge with more beyond
      # it, so a cut line reads as "more" rather than as a mistake.
      def fades(layout, scroll)
        body = layout.body
        depth = @pen.px(18)
        card = @pen.palette.card
        full = Presentation::Rect.new(x: layout.card.x + 1, y: 0, width: layout.card.width - 2, height: 1)
        depth.times do |i|
          alpha = ((depth - i) / depth.to_f)**1.6
          @pen.fill(full.with(y: body.y + i), card, alpha:) if scroll.positive?
          @pen.fill(full.with(y: body.bottom - 1 - i - @pen.px(8)), card, alpha:) if scroll < layout.most_scroll
        end
        @pen.fill(full.with(y: body.bottom - @pen.px(8), height: @pen.px(8) - @pen.px(16) / 2), card) if scroll < layout.most_scroll
      end

      def scrollbar(layout, scroll)
        body = layout.body
        track = body.height - @pen.px(16)
        length = [(track * body.height / layout.content_height.to_f).round, @pen.px(24)].max
        y = body.y + @pen.px(8) + ((track - length) * scroll / layout.most_scroll.to_f).round
        bar = Presentation::Rect.new(x: layout.card.right - @pen.px(8), y:, width: @pen.px(3), height: length)
        @pen.fill(bar, @pen.palette.ink_muted, alpha: 0.5, radius: bar.width / 2)
      end
    end
  end
end
