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

        title = @pen.type.sheet_title
        @pen.text(sheet.title, title, layout.title.x, @pen.middle_top(title, layout.title.center_y), palette.ink)
        close(layout.close)
        @pen.fill(layout.title.with(y: layout.title.bottom - 1, height: 1), palette.rule)

        body(play, layout, sheet.scroll)
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
