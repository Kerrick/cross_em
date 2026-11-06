# frozen_string_literal: true

module CrossEm
  module Shell
    # A key drawn as a little keycap, for the few places a keyboard
    # player is shown which key does what: a rounded cap with a deeper
    # lower edge, labelled "Esc" or "Tab", or with the return arrow.
    # Recognising a key is quicker than reading what it does.
    class KeyPainter
      def initialize(pen)
        @pen = pen
      end

      # How wide the key labelled +label+ (a String, or :return) is drawn
      # +height+ pixels tall.
      def width(label, height)
        inner = label == :return ? (height * 0.7).round : font(height).width(label)
        [height, inner + @pen.px(10)].max
      end

      # Draws the key with its top left at (+x+, +y+); answers its width.
      # +color+ is its ink: muted, or the accent when pressing it would
      # act.
      def draw(label, x, y, height, color: nil, alpha: 1.0)
        palette = @pen.palette
        color ||= palette.ink_muted
        rect = Presentation::Rect.new(x: x.round, y: y.round, width: width(label, height), height:)
        radius = @pen.px(4)
        edge = @pen.px(2)
        @pen.fill(rect, color, alpha: 0.55 * alpha, radius:)
        cap = rect.with(height: rect.height - edge)
        @pen.fill(cap, palette.card, alpha:, radius:)
        @pen.outline(cap, color, width: @pen.stroke(1), alpha:, radius:)
        if label == :return then return_arrow(cap, color, alpha)
        else @pen.centered(label, font(height), cap, color, alpha:)
        end
        rect.width
      end

      private

      def font(height) = @pen.type.fonts.sans_bold([(height * 0.5).round, 9].max)

      # ⏎: down from the top right, then left, to an arrowhead.
      def return_arrow(cap, color, alpha)
        w = @pen.stroke(1.5)
        size = cap.height * 0.5
        right = cap.center_x + (size * 0.5)
        left = cap.center_x - (size * 0.5)
        top = cap.center_y - (size * 0.45)
        bottom = cap.center_y + (size * 0.25)
        head = size * 0.28
        @pen.line(color, w, right, top, right, bottom, left, bottom, alpha:)
        @pen.line(color, w, left + head, bottom - head, left, bottom, left + head, bottom + head, alpha:)
      end
    end
  end
end
