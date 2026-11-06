# frozen_string_literal: true

module CrossEm
  module Presentation
    # Something the focus can rest on: a logical +id+ ([:slot, 3],
    # [:cell, position], [:button, :shuffle] ...), the +region+ it belongs
    # to (:header, :board, :pool, :controls, :results, or a sheet's kind),
    # and where it is on the screen now, +rect+, in pixels. The id stays
    # the same when the layout changes; the rect does not. A target out
    # of sight (a board cell the camera has panned away from) is not
    # +shown+: it can be moved to from within its region, which brings
    # it into view, but not from outside it, nor by the stick's cursor.
    class Target < Data.define(:id, :region, :rect, :shown)
      def initialize(id:, region:, rect:, shown: true) = super
    end

    # Moving a focus by direction, as a television's remote or a console
    # menu does (spatial navigation): from the focused thing's rectangle,
    # the best candidate on that side, by how far it is and how well it
    # lines up. It works from rectangles alone, so it follows every
    # layout, orientation and scale.
    #
    # A candidate counts when it lies on that side: its middle past the
    # focused thing's edge. Of
    # those, the one with the least score wins: the gap to it along the
    # way of travel, plus three times the gap across it (none when the
    # two overlap across, as a column or a row does), plus a fifth of how
    # far their middles are apart across, which breaks ties in favour of
    # the one most nearly in line. Lining up weighs heavily, so a thing
    # straight ahead wins over a nearer one off to the side, as the eye
    # expects of rows and columns (Johnson: Gestalt proximity and
    # continuity).
    module Spatial
      DIRECTIONS = %i[up down left right].freeze

      # Across weighs this much more than along.
      ACROSS = 3.0

      # And the middles' offset this much, to break ties.
      ALIGN = 0.2

      module_function

      # The best of +candidates+ (Targets) to move to from +from+ (a Rect)
      # towards +direction+, or nil when none lies that way.
      def pick(from, direction, candidates)
        best = nil
        best_score = nil
        candidates.each do |candidate|
          score = score(from, direction, candidate.rect) or next
          best, best_score = candidate, score if best_score.nil? || score < best_score
        end
        best
      end

      # Those of +candidates+ that overlap +from+ across +direction+: in
      # its column for up and down, in its row for left and right.
      def in_line(from, direction, candidates)
        _, across = axes(direction)
        candidates.select { gap_across(from, it.rect, across).zero? && overlaps?(from, it.rect, across) }
      end

      def overlaps?(from, to, across)
        across == :x ? to.x < from.right && from.x < to.right : to.y < from.bottom && from.y < to.bottom
      end

      # How far +to+ is from +from+ towards +direction+, as #pick weighs
      # it, or nil when it isn't that way at all.
      def score(from, direction, to)
        along, across = axes(direction)
        return unless ahead?(from, to, direction, along)

        gap = gap_along(from, to, direction)
        overlap_gap = gap_across(from, to, across)
        offset = (middle(to, across) - middle(from, across)).abs
        gap + (ACROSS * overlap_gap) + (ALIGN * offset)
      end

      # The distance from the point (+x+, +y+) to +rect+: none inside it.
      def distance(rect, x, y)
        dx = [rect.x - x, 0, x - rect.right].max
        dy = [rect.y - y, 0, y - rect.bottom].max
        Math.hypot(dx, dy)
      end

      # The candidate nearest the point (+x+, +y+): the one it is inside,
      # or the closest edge, the closer middle breaking a tie.
      def nearest(candidates, x, y)
        candidates.min_by do |candidate|
          rect = candidate.rect
          [distance(rect, x, y), Math.hypot(rect.center_x - x, rect.center_y - y)]
        end
      end

      def axes(direction) = %i[left right].include?(direction) ? %i[x y] : %i[y x]

      def middle(rect, axis) = axis == :x ? rect.center_x : rect.center_y

      # Whether +to+'s middle is past +from+'s edge that way.
      def ahead?(from, to, direction, along)
        case direction
        when :right then middle(to, along) > from.right
        when :left then middle(to, along) < from.x
        when :down then middle(to, along) > from.bottom
        else middle(to, along) < from.y
        end
      end

      def gap_along(from, to, direction)
        gap = case direction
              when :right then to.x - from.right
              when :left then from.x - to.right
              when :down then to.y - from.bottom
              else from.y - to.bottom
              end
        [gap, 0].max
      end

      def gap_across(from, to, across)
        low, high = across == :x ? %i[x right] : %i[y bottom]
        [to.public_send(low) - from.public_send(high), from.public_send(low) - to.public_send(high), 0].max
      end
    end
  end
end
