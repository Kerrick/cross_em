# frozen_string_literal: true

module CrossEm
  module Shell
    # A sheet over the Play screen: the page dimmed behind, a paper card
    # with its title and a close button, and the body, which scrolls,
    # clipped to the card, with a thin bar to show where it is.
    class SheetPainter
      def initialize(pen, buttons)
        @pen, @buttons = pen, buttons
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
        scrollbar(layout, sheet.scroll) if layout.scrolls?
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
          layout.lines.each do |line|
            y = top + line.y
            font = @pen.type.style(line.style)
            next if y + font.height < body.y || y > body.bottom

            @pen.text(line.text, font, body.x + line.x, y, color(line.style))
          end
          layout.controls.each do |control|
            rect = control.rect.offset(body.x, top)
            next if rect.bottom < body.y || rect.y > body.bottom

            control.kind == :toggle ? toggle(rect, control, play.settings) : button(rect, control, play)
          end
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
        total = label.height + detail.height
        top = rect.y + ((rect.height - total) / 2)
        @pen.text(control.text, label, rect.x, top, palette.ink)
        @pen.text(control.detail, detail, rect.x, top + label.height, palette.ink_muted)
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
