# frozen_string_literal: true

module CrossEm
  module Presentation
    # Turns the design's points into the screen's whole pixels. The game
    # draws 1:1 in physical pixels (conf.rb turns off Lota's own scaling),
    # so every size is decided here, once, from the screen's density: 2 on
    # a Retina display, 3 on most iPhones. Nothing is drawn at one size and
    # scaled to another.
    class Units < Data.define(:scale)
      def initialize(scale:) = super(scale: scale.to_f.positive? ? scale.to_f : 1.0)

      # +points+ as whole pixels.
      def px(points) = (points * scale).round

      # A stroke +points+ wide, never thinner than one pixel.
      def stroke(points) = [px(points), 1].max

      # Pixels back to points, for decisions such as portrait or landscape.
      def pt(pixels) = pixels / scale

      # Where a stroke of +width+ pixels goes so its edges fall on pixel
      # boundaries: odd widths sit on a pixel's centre.
      def self.line_at(pixel, width) = width.odd? ? pixel + 0.5 : pixel.to_f
    end
  end
end
