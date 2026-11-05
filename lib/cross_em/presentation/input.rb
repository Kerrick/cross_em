# frozen_string_literal: true

module CrossEm
  module Presentation
    # A finger or the mouse going down, moving, or coming up, at (+x+,
    # +y+) in pixels. +id+ tells one finger from another; the mouse is
    # :mouse.
    class Pointer < Data.define(:phase, :id, :x, :y); end

    # Decides which of Lota's input callbacks are the player's pointer. A
    # finger on a touchscreen fires touchpressed, and SDL then also makes
    # up a mousepressed for it with istouch true; only the touch counts, so
    # one finger is one press. A trackpad's touches (coordinates from 0 to
    # 1) are not presses either: the trackpad also moves the mouse, and
    # scrolls through wheelmoved. On iOS and Android, SDL turns a real
    # mouse into touches marked +mouse+, which arrive again as the mouse.
    module InputRouter
      module_function

      def mouse(phase, x, y, button: 1, istouch: false)
        return if istouch || button != 1

        Pointer.new(phase:, id: :mouse, x: x.to_f, y: y.to_f)
      end

      def touch(phase, id, x, y, devicetype, mouse)
        return unless devicetype.to_s == "touchscreen"
        return if mouse == true
        return unless x.is_a?(Numeric) && y.is_a?(Numeric)

        Pointer.new(phase:, id:, x: x.to_f, y: y.to_f)
      end
    end

    # One press, from down to up: where it began, where it is, what it
    # began on (+target+), and whether it has moved far enough to be a
    # drag rather than a tap. Only a press that never became a drag is a
    # tap when it ends.
    class Gesture < Data.define(:id, :target, :start_x, :start_y, :x, :y, :dragging)
      def self.start(pointer, target)
        new(id: pointer.id, target:, start_x: pointer.x, start_y: pointer.y, x: pointer.x, y: pointer.y,
            dragging: false)
      end

      # The gesture with the pointer at (+x+, +y+): a drag once it is
      # +threshold+ pixels or more from where it began.
      def moved(x, y, threshold)
        far = Math.hypot(x - start_x, y - start_y) >= threshold
        with(x:, y:, dragging: dragging || far)
      end

      def tap? = !dragging
    end
  end
end
