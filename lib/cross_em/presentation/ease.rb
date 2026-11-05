# frozen_string_literal: true

module CrossEm
  module Presentation
    # Easing curves. Each takes progress from 0 to 1, clamped, and answers
    # how far along the motion is: 0 at the start, 1 at the end, though
    # out_back passes 1 on the way, which is the bounce.
    module Ease
      module_function

      def linear(t) = t.to_f.clamp(0.0, 1.0)
      def out_cubic(t) = 1 - ((1 - linear(t))**3)
      def in_out_sine(t) = -(Math.cos(Math::PI * linear(t)) - 1) / 2

      # Goes a little past the end and settles back.
      def out_back(t, overshoot = 1.4)
        u = linear(t) - 1
        1 + ((overshoot + 1) * (u**3)) + (overshoot * (u**2))
      end

      def by_name(name, t) = public_send(name, t)
    end
  end
end
