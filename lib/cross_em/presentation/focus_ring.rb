# frozen_string_literal: true

module CrossEm
  module Presentation
    # The one thing on the screen that A, or Enter, would act on, and
    # whether its ring is shown. The ring shows once a keyboard's arrows
    # or a controller are used, and hides at the next tap or click, so
    # there is no mode to manage (Saffer).
    #
    # The focus is held by its Target's logical id, so it survives a
    # layout change or a rotation: each time it is asked for, it is found
    # again among the targets on screen now. When it is gone (a pool
    # letter placed, a button that faded), the nearest target left in its
    # region, measured from where it last was, takes its place; when its
    # whole region is gone (a sheet closed over it), the last focus in a
    # region that is there again does. Each region remembers its last
    # focus, so jumping back to a region lands where the player left it.
    class FocusRing
      attr_reader :id, :region

      def initialize
        @id = @region = @anchor = nil
        @trail = []
        @visible = false
      end

      def visible? = @visible
      def show = @visible = true
      def hide = @visible = false

      # The focused Target among +targets+, found again by id, or the best
      # stand-in for it (see the class comment), or +default+'s first id
      # there is a target for, or the first target. Adopts whichever it
      # finds. Nil when there are no targets.
      def current(targets, default: [])
        return if targets.empty?

        found = find(targets, @id, @region) || stand_in(targets) || remembered(targets) ||
                default.lazy.filter_map { |id| targets.find { it.id == id } }.first || targets.first
        adopt(found)
      end

      # Focuses +target+, remembering it as its region's last focus.
      def focus(target)
        adopt(target)
      end

      # Moves the focus towards +direction+ (Spatial): to a neighbour
      # pinned in +pins+ ({[id, direction] => id}) if it is there; else
      # to the best target that way in its own region in line with it
      # (overlapping it across); else, running off the region's edge,
      # into the nearest region that way, measured to the region's bounds
      # (+bounds+, {region => Rect}, or else all its targets'), to its
      # best shown target, in line first; else to the best target that
      # way in its own region, round a corner. Answers the Target moved
      # to, or nil when there is none that way and the focus stays.
      #
      # In line comes first so that a move never turns a corner while
      # something lies straight ahead, and regions are measured whole so
      # that a move never jumps over one, as up from the pool's corner
      # would otherwise skip a board whose letters are all off to one side
      # and land in the header (Johnson: the eye groups by region first).
      def move(targets, direction, pins: {}, default: [], bounds: {})
        from = current(targets, default:) or return
        pinned = pins[[from.id, direction]]
        own = targets.select { it.region == from.region && it != from }
        to = (pinned && (targets.find { it.id == pinned && it.region == from.region } || targets.find { it.id == pinned })) ||
             Spatial.pick(from.rect, direction, Spatial.in_line(from.rect, direction, own)) ||
             beyond(from, direction, targets, bounds) || Spatial.pick(from.rect, direction, own)
        to && focus(to)
      end

      # Jumps +by+ regions on (-1 back), in the order the regions first
      # appear in +targets+, wrapping around: to the region's last focus,
      # or else to its +firsts+ ({region => id}) or its first target.
      def hop(targets, by, firsts: {}, default: [])
        from = current(targets, default:) or return
        regions = targets.map(&:region).uniq
        region = regions[(regions.index(from.region) + by) % regions.size]
        to = memory(targets, region) || targets.find { it.region == region && it.id == firsts[region] } ||
             targets.find { it.region == region }
        focus(to)
      end

      # The last focus in +region+ that is among +targets+ now, or nil.
      def memory(targets, region)
        id = @trail.find { it.last == region }&.first or return
        find(targets, id, region)
      end

      private

      def best(rect, direction, candidates)
        Spatial.pick(rect, direction, Spatial.in_line(rect, direction, candidates)) ||
          Spatial.pick(rect, direction, candidates)
      end

      # The best target in the nearest other region that way.
      def beyond(from, direction, targets, bounds)
        others = targets.select { it.region != from.region && it.shown }.group_by(&:region)
        regions = others.map do |region, members|
          Target.new(id: region, region:, rect: bounds[region] || union(members.map(&:rect)))
        end
        ranked = regions.filter_map { |region| (score = Spatial.score(from.rect, direction, region.rect)) && [score, region.id] }
        ranked.sort_by(&:first).each do |_, region|
          to = best(from.rect, direction, others[region])
          return to if to
        end
        nil
      end

      def union(rects)
        left, top = rects.map(&:x).min, rects.map(&:y).min
        Rect.new(x: left, y: top, width: rects.map(&:right).max - left, height: rects.map(&:bottom).max - top)
      end

      def find(targets, id, region) = id && targets.find { it.id == id && it.region == region }

      # The target in the same region nearest where the focus last was.
      def stand_in(targets)
        return unless @anchor

        near = targets.select { it.region == @region }
        Spatial.nearest(near, @anchor.center_x, @anchor.center_y) unless near.empty?
      end

      # The most recent focus in a region that is on screen again.
      def remembered(targets)
        @trail.each do |id, region|
          found = find(targets, id, region)
          return found if found
        end
        nil
      end

      def adopt(target)
        @id, @region, @anchor = target.id, target.region, target.rect
        @trail.reject! { it.last == target.region }
        @trail.unshift([target.id, target.region])
        @trail.pop while @trail.size > 12
        target
      end
    end
  end
end
