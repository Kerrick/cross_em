# frozen_string_literal: true

module CrossEm
  module Presentation
    # How the screen catches up with the rules. Every change has already
    # happened when Motion hears of it; Motion only remembers when it
    # happened, and where a tile came from, so the painters can show it
    # arriving. A tile is known by where it now is: [:cell, position] on
    # the grid, or [:slot, index] in the pool.
    #
    # With calm motion, flights, lifts, sweeps and waves become short
    # fades, nothing bobs or breathes, and there is no confetti.
    class Motion
      # Seconds, as doc/design.md gives them.
      LIFT = 0.12
      PLACE = 0.22
      RETURN = 0.20
      STAGGER = 0.03
      SHUFFLE = 0.26
      LAND = 0.14
      SWEEP = 0.45
      SHAKE = 0.32
      FLIP = 0.32
      WAVE = 0.06
      SETTLE = 0.45
      CAMERA = 0.25
      FADE = 0.08
      TARGETS = 0.15

      # A tile on its way: from +from+ (a Rect) to wherever its key is
      # drawn, leaving at +start+ for +duration+ seconds, along +ease+,
      # rising +arc+ pixels at its height.
      class Flight < Data.define(:from, :start, :duration, :ease, :arc)
        def progress(now) = ((now - start) / duration).clamp(0.0, 1.0)
        def landed_at = start + duration
      end

      # Where and how to draw a tile this frame: its rect, its opacity,
      # and how squashed it is (1 is not at all).
      class Pose < Data.define(:rect, :alpha, :squash)
        def self.at(rect) = new(rect:, alpha: 1.0, squash: 1.0)
      end

      attr_reader :now, :calm

      def initialize(calm: false)
        @calm = calm
        @now = 0.0
        @flights = {}
        @lifted = {}
        @lowered = {}
        @check = nil
        @ending = nil
        @camera = nil
        @confetti = nil
      end

      def calm=(calm)
        @calm = calm
        settle
      end

      def update(now) = @now = now

      # Finishes every motion at once, as when the game is replaced.
      def settle
        @flights.clear
        @lowered.clear
        @lifted.transform_values! { -1.0 }
        @camera = nil
        @confetti = nil
      end

      # --- Being told what happened ---

      def selected(index, previous = nil)
        lowered(previous) if previous && previous != index
        @lifted[index] = @now
        @lowered.delete(index)
      end

      def lowered(index)
        return unless @lifted.delete(index)

        @lowered[index] = @now
      end

      # The tile in slot +index+ left for the grid, from where it was.
      def left(index)
        @lifted.delete(index)
        @lowered.delete(index)
      end

      # The selected tile moved slots (a shuffle), still lifted.
      def moved_lift(index)
        @lifted.clear
        @lifted[index] = -1.0 if index
        @lowered.clear
      end

      def fly(key, from, kind, delay: 0.0)
        duration, ease, arc = case kind
                              when :place then [PLACE, :out_back, 0.18]
                              when :shuffle then [SHUFFLE, :in_out_sine, 0.5]
                              else [RETURN, :out_cubic, 0.12]
                              end
        duration = FADE if calm
        @lifted.delete(key[1]) if key[0] == :slot
        @flights[key] = Flight.new(from:, start: @now + (calm ? 0 : delay), duration:, ease:, arc: calm ? 0 : arc)
      end

      # Every letter on the board was checked, against the board's
      # bounds, swept left to right, beginning +delay+ seconds from now
      # (once a typed word's last letter is on its way).
      def checked(bounds, problems, delay: 0.0)
        @check = {at: @now + (calm ? 0 : delay), bounds:, problems: problems.dup}
      end

      def won(bounds, delay: 0.0) = @ending = {at: @now + (calm ? 0 : delay), kind: :won, bounds:}
      def lost(delay: 0.0) = @ending = {at: @now + (calm ? 0 : delay), kind: :lost}

      # The camera moves from +from+ to +to+ (BoardViews).
      def camera(from, to)
        @camera = from && !calm && from != to ? {from:, to:, at: @now} : nil
      end

      # --- What the painters ask ---

      def flying?(key)
        flight = @flights[key] or return false
        return true if @now < flight.landed_at

        @flights.delete(key) if @now > flight.landed_at + LAND
        false
      end

      def flying_keys = @flights.keys.select { flying?(it) }

      # Where the tile for +key+ is drawn on its way to +to+, or at rest.
      def pose(key, to)
        flight = @flights[key] or return Pose.at(to)
        t = flight.progress(@now)
        return Pose.new(rect: to, alpha: t, squash: 1.0) if calm
        return Pose.new(rect: to, alpha: 1.0, squash: squash(@now - flight.landed_at)) if t >= 1.0

        eased = Ease.by_name(flight.ease, t)
        from = flight.from
        width = from.width + ((to.width - from.width) * eased)
        height = from.height + ((to.height - from.height) * eased)
        cx = from.center_x + ((to.center_x - from.center_x) * eased)
        cy = from.center_y + ((to.center_y - from.center_y) * eased)
        cy -= Math.sin(Math::PI * Ease.linear(t)) * flight.arc * Math.hypot(to.center_x - from.center_x, to.center_y - from.center_y) * 0.5
        rect = Rect.new(x: (cx - (width / 2)).round, y: (cy - (height / 2)).round, width: width.round, height: height.round)
        Pose.new(rect:, alpha: 1.0, squash: 1.0)
      end

      # How far up a pool tile is lifted, 0 to 1, with a gentle bob while
      # it stays up.
      def lift(index)
        if (since = @lifted[index])
          up = calm ? 1.0 : Ease.out_cubic((@now - since) / LIFT)
          bob = calm ? 0.0 : Math.sin((@now - since) * Math::PI * 1.6) * 0.12 * up
          return up + bob
        end
        since = @lowered[index] or return 0.0
        down = calm ? 1.0 : Ease.out_cubic((@now - since) / LIFT)
        @lowered.delete(index) if down >= 1.0
        1.0 - down
      end

      # How visible the targets are: they fade in when a letter is picked
      # up, and then breathe.
      def targets(selected_since = @lifted.values.max)
        return 1.0 unless selected_since

        fade = ((@now - selected_since) / TARGETS).clamp(0.0, 1.0)
        breath = calm ? 1.0 : 0.82 + (0.18 * Math.sin(@now * Math::PI))
        fade * breath
      end

      # Whether the check has reached +position+ yet, so its mark shows.
      def checked?(position) = mark_time(position) <= @now

      # The sweep's place across the board's columns, as a fraction from
      # 0 to 1, while it runs; nil otherwise.
      def sweep
        return unless @check && !calm

        t = (@now - @check[:at]) / SWEEP
        t if t.between?(0.0, 1.0)
      end

      def sweep_bounds = @check&.fetch(:bounds)

      # A problem letter shakes, briefly, as the sweep passes it: its
      # sideways offset in units of its size.
      def shake(position)
        return 0.0 unless @check&.fetch(:problems)&.include?(position) && !calm

        t = (@now - mark_time(position)) / SHAKE
        return 0.0 unless t.between?(0.0, 1.0)

        Math.sin(t * Math::PI * 5) * (1 - t) * 0.06
      end

      # After a win, each tile flips to its finished face in a wave from
      # the top left: answers the flip's progress, 0 to 1, or nil before it
      # begins. After a loss, tiles take their final faces in a fade.
      def finish(position)
        return 1.0 unless @ending

        start = ending_start(position)
        duration = calm ? FADE : (@ending[:kind] == :won ? FLIP : SETTLE)
        t = (@now - start) / duration
        t.clamp(0.0, 1.0)
      end

      def ending_kind = @ending&.fetch(:kind)

      # How visible the results are: they arrive once the check has swept
      # the board, as its letters take their final faces.
      def results
        return 1.0 unless @ending

        start = @ending[:at] + (calm ? 0 : SWEEP + 0.25)
        ((@now - start) / 0.35).clamp(0.0, 1.0)
      end

      # The camera's view this frame, or nil when it is at rest.
      def view
        return unless @camera

        t = (@now - @camera[:at]) / CAMERA
        return @camera = nil if t >= 1.0

        @camera[:from].toward(@camera[:to], Ease.out_cubic(t))
      end

      def confetti(area, units:, colors:)
        return if calm || @ending.nil? || @ending[:kind] != :won

        at = @ending[:at] + ending_length - 0.1
        return if @now < at

        @confetti ||= Confetti.burst(area, units:, colors:)
        [@confetti, @now - at]
      end

      private

      def squash(since)
        return 1.0 if since.negative? || since > LAND

        1.0 - (0.12 * Math.sin(Math::PI * since / LAND))
      end

      def mark_time(position)
        return -Float::INFINITY unless @check
        return @check[:at] if calm

        bounds = @check[:bounds] or return @check[:at]
        @check[:at] + (SWEEP * ((position.column - bounds.left + 0.5) / bounds.width.to_f))
      end

      def ending_start(position)
        start = @ending[:at] + (calm ? 0 : SWEEP)
        return start unless @ending[:kind] == :won && !calm && (bounds = @ending[:bounds])

        start + (WAVE * ((position.column - bounds.left) + (position.row - bounds.top)))
      end

      # How long the board takes to settle after the end: the sweep, then
      # the wave or the fade.
      def ending_length
        return SWEEP + SETTLE unless @ending[:kind] == :won && (bounds = @ending[:bounds])

        SWEEP + (WAVE * (bounds.width + bounds.height - 2)) + FLIP
      end
    end
  end
end
