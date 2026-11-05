# frozen_string_literal: true

module CrossEm
  module Presentation
    # A color as Lota takes one: red, green, blue and alpha, each 0 to 1,
    # in sRGB.
    class Color < Data.define(:r, :g, :b, :a)
      # The color written "#rrggbb".
      def self.hex(text, a = 1.0)
        value = Integer(text.delete_prefix("#"), 16)
        new(r: ((value >> 16) & 255) / 255.0, g: ((value >> 8) & 255) / 255.0, b: (value & 255) / 255.0, a:)
      end

      def initialize(r:, g:, b:, a: 1.0) = super(r: r.to_f, g: g.to_f, b: b.to_f, a: a.to_f)

      # The same color, +factor+ times as opaque.
      def fade(factor) = with(a: a * factor)

      # +amount+ of the way to +other+: 0 is this color, 1 is +other+.
      def mix(other, amount)
        Color.new(r: r + ((other.r - r) * amount), g: g + ((other.g - g) * amount),
                  b: b + ((other.b - b) * amount), a: a + ((other.a - a) * amount))
      end

      def to_a = [r, g, b, a]

      # Relative luminance, as WCAG defines it.
      def luminance
        red, green, blue = [r, g, b].map { it <= 0.04045 ? it / 12.92 : ((it + 0.055) / 1.055)**2.4 }
        (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
      end

      # WCAG's contrast ratio with +other+, from 1 to 21.
      def contrast(other)
        dark, light = [luminance, other.luminance].minmax
        (light + 0.05) / (dark + 0.05)
      end
    end
  end
end
