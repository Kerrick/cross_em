# frozen_string_literal: true

module CrossEm
  module Shell
    # A button: ink on paper, outlined, or filled for the one action that
    # matters most on the screen. A disabled one fades to the page's rule.
    # A label too long for its button wraps onto two lines in a smaller
    # size, rather than being cut off.
    class ButtonPainter
      def initialize(pen, keys)
        @pen, @keys = pen, keys
      end

      # +kind+ is :plain, :primary, :danger or :disabled. +keys+, on a
      # computer, are the keycaps for the button's action, drawn after
      # its label when they fit (a tooltip shows them when they don't).
      def draw(rect, label, kind: :plain, pressed: false, keys: nil)
        palette = @pen.palette
        radius = @pen.px(12)
        rect = rect.offset(0, @pen.px(1)) if pressed
        case kind
        when :primary then @pen.fill(rect, palette.ink, radius:)
        when :danger then @pen.fill(rect, palette.problem, radius:)
        when :disabled then @pen.outline(rect, palette.rule, width: @pen.stroke(1.5), radius:)
        else
          @pen.fill(rect, palette.card, radius:)
          @pen.outline(rect, palette.ink, width: @pen.stroke(1.5), radius:)
        end
        color = case kind
                when :primary, :danger then palette.page
                when :disabled then palette.ink_muted
                else palette.ink
                end
        alpha = kind == :disabled ? 0.6 : 1.0
        return label(rect, label, color, alpha:) unless keys && fits?(rect, label, keys)

        font = @pen.type.button
        height = @pen.px(18)
        gap = @pen.px(8)
        width = font.width(label) + gap + @keys.chord_width(keys, height)
        x = (rect.center_x - (width / 2.0)).round
        @pen.text(label, font, x, @pen.middle_top(font, rect.center_y), color, alpha:)
        @keys.chord(keys, x + font.width(label) + gap, rect.center_y - (height / 2.0), height, alpha: alpha * 0.9)
      end

      # Whether +label+ and its +keys+ fit on one line in +rect+.
      def fits?(rect, label, keys)
        @pen.type.button.width(label) + @pen.px(8) + @keys.chord_width(keys, @pen.px(18)) <= rect.width - @pen.px(16)
      end

      private

      def label(rect, text, color, alpha:)
        room = rect.width - @pen.px(16)
        font = @pen.type.button
        return @pen.centered(text, font, rect, color, alpha:) if font.width(text) <= room

        small = @pen.type.fonts.sans_bold(@pen.px(14))
        lines = text.split(/(?<=[?.!]) /)
        _, lines = small.wrap(text, room) if lines.size < 2 || lines.any? { small.width(it) > room }
        line_height = (small.height * 1.05).round
        top = rect.center_y - (lines.size * line_height / 2.0)
        lines.each_with_index do |line, i|
          row = rect.with(y: (top + (i * line_height)).round, height: line_height)
          @pen.centered(line, small, row, color, alpha:)
        end
      end
    end
  end
end
