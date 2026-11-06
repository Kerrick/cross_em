# frozen_string_literal: true

module CrossEm
  module Presentation
    # A controller's left stick as a cursor with gravity, as an inventory
    # cursor in a console game moves: for layouts where moving by
    # direction would guess wrong, the player simply points.
    #
    # Pure arithmetic over time and rectangles. Each frame, #update takes
    # the stick's position and the targets on screen. Inside a dead zone
    # the stick counts as let go (a resting stick drifts); past it, the
    # cursor moves at a speed that grows with the square of the tilt, so
    # a small tilt is fine and a full one quick (Swink: a response curve).
    # Over a target it slows ("friction"), so it is easy to stop on one.
    # Let go, it settles onto the nearest target, gliding to its middle,
    # and that target is the focus. While it moves, the target under it
    # is the focus, so the stick and the d-pad drive the same focus and
    # either can be picked up at any moment.
    class StickCursor
      # How far the stick must tilt, of its full travel, before it moves
      # the cursor.
      DEAD_ZONE = 0.2

      # The speed over a target, as a part of the speed elsewhere.
      FRICTION = 0.45

      # Seconds to glide onto the target settled on.
      SETTLE = 0.12

      # Seconds the cursor stays in sight after it has settled.
      LINGER = 0.6

      attr_reader :x, :y

      # The fastest, in pixels a second, at full tilt.
      attr_accessor :speed

      # +speed+ is the fastest, in pixels a second, at full tilt.
      def initialize(speed:)
        @speed = speed.to_f
        @x = @y = 0.0
        @time = 0.0
        @moving = false
        @glide = nil
        @seen_at = nil
      end

      # The stick's tilt (+sx+, +sy+), each from -1 to 1, past the dead
      # zone and rescaled to 0..1 from its edge, so motion starts gently
      # rather than with a jump: [x, y], or [0, 0] inside it.
      def self.shaped(sx, sy, dead_zone: DEAD_ZONE)
        magnitude = Math.hypot(sx, sy)
        return [0.0, 0.0] if magnitude <= dead_zone

        scaled = ((magnitude - dead_zone) / (1.0 - dead_zone)).clamp(0.0, 1.0)
        [sx / magnitude * scaled, sy / magnitude * scaled]
      end

      # Puts the cursor at (+x+, +y+) at once, out of sight: where the
      # d-pad moved the focus, so the stick goes on from there.
      def place(x, y)
        @x, @y = x.to_f, y.to_f
        @glide = nil
        @moving = false
      end

      def moving? = @moving

      # Whether to draw it: while it moves or glides, and a moment after.
      def visible? = @moving || !@glide.nil? || (!@seen_at.nil? && @time - @seen_at < LINGER)

      # How opaque to draw it, fading out once it has settled.
      def alpha
        return 1.0 if @moving || @glide
        return 0.0 unless @seen_at

        (1.0 - ((@time - @seen_at) / LINGER)).clamp(0.0, 1.0)
      end

      # One frame of +seconds+, the stick at (+sx+, +sy+), among
      # +targets+, the cursor kept inside +bounds+ (a Rect). Answers
      # [:over, target] while moving over a target, [:settle, target]
      # the frame the stick is let go, or nil.
      def update(seconds, sx, sy, targets, bounds)
        @time += seconds
        dx, dy = StickCursor.shaped(sx, sy)
        if dx.zero? && dy.zero?
          was = @moving
          @moving = false
          glide(seconds)
          return was ? settle(targets) : nil
        end

        @moving = true
        @glide = nil
        @seen_at = @time
        under = under(targets)
        # The tilt's direction times the square of its size: dx * m.
        speed = @speed * (under ? FRICTION : 1.0) * Math.hypot(dx, dy)
        @x = (@x + (dx * speed * seconds)).clamp(bounds.x.to_f, (bounds.right - 1).to_f)
        @y = (@y + (dy * speed * seconds)).clamp(bounds.y.to_f, (bounds.bottom - 1).to_f)
        now = under(targets)
        now && [:over, now]
      end

      private

      def under(targets) = targets.find { it.rect.contains?(@x, @y) }

      # Settles onto the nearest target, gliding to its middle.
      def settle(targets)
        target = Spatial.nearest(targets, @x, @y) or return
        @glide = {from: [@x, @y], to: [target.rect.center_x, target.rect.center_y], t: 0.0}
        [:settle, target]
      end

      def glide(seconds)
        return unless @glide

        @glide[:t] += seconds
        amount = Ease.out_cubic((@glide[:t] / SETTLE).clamp(0.0, 1.0))
        (fx, fy), (tx, ty) = @glide.values_at(:from, :to)
        @x, @y = fx + ((tx - fx) * amount), fy + ((ty - fy) * amount)
        return if @glide[:t] < SETTLE

        @glide = nil
        @seen_at = @time
      end
    end
  end
end
