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

      # The Units for a window +width+ by +height+ pixels on a screen of
      # +density+. Where the window has room to spare beyond the size the
      # design was drawn for, the whole design is drawn larger, in steps
      # of an eighth up to Look::ZOOM's most, so a big screen shows a
      # bigger page rather than more empty paper. Every size still rounds
      # to whole pixels, so it stays as sharp.
      def self.for_window(density:, width:, height:)
        base = new(scale: density)
        zoom = Look::ZOOM
        fit = [base.pt(width) / zoom.width, base.pt(height) / zoom.height].min
        new(scale: base.scale * ((fit * 8).floor / 8.0).clamp(1.0, zoom.most))
      end

      # +points+ as whole pixels.
      def px(points) = (points * scale).round

      # A stroke +points+ wide, never thinner than one pixel.
      def stroke(points) = [px(points), 1].max

      # Pixels back to points, for decisions such as portrait or landscape.
      def pt(pixels) = pixels / scale
    end
  end
end
