# frozen_string_literal: true

module CrossEm
  module Presentation
    # A rectangle on the screen, in pixels. Layout makes them from whole
    # numbers, so whatever is drawn in one starts and ends on a pixel.
    class Rect < Data.define(:x, :y, :width, :height)
      def self.zero = new(x: 0, y: 0, width: 0, height: 0)

      def right = x + width
      def bottom = y + height
      def center_x = x + (width / 2.0)
      def center_y = y + (height / 2.0)

      def contains?(px, py) = px >= x && px < right && py >= y && py < bottom
      def empty? = width <= 0 || height <= 0

      # Grown by +amount+ on every side, or shrunk when it is negative.
      def inset(dx, dy = dx) = with(x: x + dx, y: y + dy, width: width - (2 * dx), height: height - (2 * dy))
      def outset(amount) = inset(-amount)

      def offset(dx, dy) = with(x: x + dx, y: y + dy)

      # The part of this rectangle inside +other+; empty when none is.
      def intersect(other)
        left, top = [x, other.x].max, [y, other.y].max
        right, bottom = [self.right, other.right].min, [self.bottom, other.bottom].min
        Rect.new(x: left, y: top, width: [right - left, 0].max, height: [bottom - top, 0].max)
      end

      # The same rectangle on whole pixels, rounding each edge.
      def round
        left, top = x.round, y.round
        Rect.new(x: left, y: top, width: right.round - left, height: bottom.round - top)
      end

      # Grown about its centre to at least +least+ each way: a button's
      # reach, never smaller than a fingertip.
      def reach(least)
        wide, tall = [width, least].max, [height, least].max
        Rect.new(x: (center_x - (wide / 2.0)).floor, y: (center_y - (tall / 2.0)).floor, width: wide, height: tall)
      end

      # Splits the width into +count+ equal parts with +gap+ between, on
      # whole pixels; any pixels left over go to the first parts.
      def columns(count, gap)
        room = width - (gap * (count - 1))
        base, extra = room.divmod(count)
        left = x
        Array.new(count) do |i|
          part = base + (i < extra ? 1 : 0)
          Rect.new(x: left, y:, width: part, height:).tap { left += part + gap }
        end
      end

      def to_a = [x, y, width, height]
    end
  end
end
