# frozen_string_literal: true

module CrossEm
  module Shell
    # A key drawn as a little keycap, for the few places a keyboard
    # player is shown which key does what: a rounded cap with a deeper
    # lower edge, labelled "Esc" or "Tab", or with the return arrow.
    # Recognising a key is quicker than reading what it does.
    #
    # A controller's button (Presentation::PadGlyph) is drawn the same
    # way, as its own controller shows it: a face button round, with its
    # letter or, on a PlayStation controller, its shape; a bumper or Back
    # and Start as a pill.
    class KeyPainter
      def initialize(pen)
        @pen = pen
      end

      # How wide the key labelled +label+ (a String, or :return) is drawn
      # +height+ pixels tall.
      def width(label, height)
        return glyph_width(label, height) if label.is_a?(Presentation::PadGlyph)

        inner = label.is_a?(Symbol) ? (height * 0.7).round : font(height).width(label)
        [height, inner + @pen.px(10)].max
      end

      # Draws the key with its top left at (+x+, +y+); answers its width.
      # +color+ is its ink: muted, or the accent when pressing it would
      # act.
      def draw(label, x, y, height, color: nil, alpha: 1.0)
        palette = @pen.palette
        color ||= palette.ink_muted
        rect = Presentation::Rect.new(x: x.round, y: y.round, width: width(label, height), height:)
        return glyph(label, rect, color, alpha) if label.is_a?(Presentation::PadGlyph)

        radius = @pen.px(4)
        edge = @pen.px(2)
        @pen.fill(rect, color, alpha: 0.55 * alpha, radius:)
        cap = rect.with(height: rect.height - edge)
        @pen.fill(cap, palette.card, alpha:, radius:)
        @pen.outline(cap, color, width: @pen.stroke(1), alpha:, radius:)
        case label
        when :return then return_arrow(cap, color, alpha)
        when :backspace then back_arrow(cap, color, alpha)
        else @pen.centered(label, font(height), cap, color, alpha:)
        end
        rect.width
      end

      # Keys pressed together, as +labels+ side by side: how wide.
      def chord_width(labels, height) = labels.sum { width(it, height) } + (@pen.px(3) * (labels.size - 1))

      # Draws keys pressed together from (+x+, +y+); answers the width.
      def chord(labels, x, y, height, color: nil, alpha: 1.0)
        start = x
        labels.each { x += draw(it, x, y, height, color:, alpha:) + @pen.px(3) }
        x - start - @pen.px(3)
      end

      private

      def glyph_width(glyph, height)
        return height if glyph.round?

        label = glyph.label
        inner = label.is_a?(Symbol) ? (height * 0.7).round : font(height).width(label)
        [(height * 1.5).round, inner + @pen.px(12)].max
      end

      # A controller's button: a cap as round as a face button, or a pill,
      # with the same deeper lower edge as a key.
      def glyph(glyph, rect, color, alpha)
        palette = @pen.palette
        edge = @pen.px(2)
        radius = (rect.height - edge) / 2
        @pen.fill(rect, color, alpha: 0.55 * alpha, radius:)
        cap = rect.with(height: rect.height - edge)
        @pen.fill(cap, palette.card, alpha:, radius:)
        @pen.outline(cap, color, width: @pen.stroke(1), alpha:, radius:)
        label = glyph.label
        label.is_a?(Symbol) ? shape(label, cap, color, alpha) : @pen.centered(label, font(rect.height), cap, color, alpha:)
        rect.width
      end

      # A PlayStation face button's shape, or Back's two windows (View)
      # and Start's three lines (Menu).
      def shape(name, cap, color, alpha)
        w = @pen.stroke(1.5)
        cx, cy = cap.center_x, cap.center_y
        r = cap.height * 0.24
        case name
        when :cross
          @pen.line(color, w, cx - r, cy - r, cx + r, cy + r, alpha:)
          @pen.line(color, w, cx - r, cy + r, cx + r, cy - r, alpha:)
        when :circle then @pen.circle(:line, color, cx, cy, r, alpha:, width: w)
        when :square then @pen.line(color, w, cx - r, cy - r, cx + r, cy - r, cx + r, cy + r, cx - r, cy + r, cx - r, cy - r, alpha:)
        when :triangle then @pen.line(color, w, cx, cy - r, cx + r, cy + (r * 0.8), cx - r, cy + (r * 0.8), cx, cy - r, alpha:)
        when :menu
          [-1, 0, 1].each { |i| @pen.line(color, w, cx - r, cy + (i * r * 0.6), cx + r, cy + (i * r * 0.6), alpha:) }
        when :view
          s = r * 0.8
          @pen.line(color, w, cx - s - (s * 0.4), cy - s + (s * 0.4), cx - s - (s * 0.4), cy + s + (s * 0.4),
                    cx + s - (s * 0.4), cy + s + (s * 0.4), alpha:)
          @pen.line(color, w, cx - s + (s * 0.4), cy - s - (s * 0.4), cx + s + (s * 0.4), cy - s - (s * 0.4),
                    cx + s + (s * 0.4), cy + s - (s * 0.4), cx - s + (s * 0.4), cy + s - (s * 0.4),
                    cx - s + (s * 0.4), cy - s - (s * 0.4), alpha:)
        end
      end

      # ⌫: an arrow pointing left.
      def back_arrow(cap, color, alpha)
        w = @pen.stroke(1.5)
        size = cap.height * 0.5
        left = cap.center_x - (size * 0.55)
        right = cap.center_x + (size * 0.55)
        y = cap.center_y
        head = size * 0.35
        @pen.line(color, w, left, y, right, y, alpha:)
        @pen.line(color, w, left + head, y - head, left, y, left + head, y + head, alpha:)
      end

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
