# frozen_string_literal: true

module CrossEm
  module Presentation
    # The window onto the grid: how big a cell is, and where the grid sits
    # in the +viewport+, as the pixel (+x+, +y+) of cell (0, 0)'s top-left
    # corner. The grid has no edges, so the view frames +content+, the
    # cells that must be reachable: the letters and one ring of targets
    # around them.
    #
    # A view fits its content with cells as big as will fit, between
    # Look's smallest and largest. When even the smallest are too big, the
    # content is bigger than the viewport along that axis and the view
    # pans, but never so far that an edge of the content comes away from
    # the viewport's edge; along an axis that fits, the content is
    # centred. Easing between two views gives a cell size that is not a
    # whole number; every rectangle is rounded edge by edge, so cells tile
    # without gaps or overlaps either way.
    class BoardView < Data.define(:viewport, :cell, :x, :y, :content, :pad)
      M = Look::METRICS

      # The letters' bounds and one ring around them; on an empty board,
      # the origin and its ring.
      def self.content_of(board)
        bounds = board.bounds || Bounds.new(left: 0, top: 0, right: 0, bottom: 0)
        Bounds.new(left: bounds.left - 1, top: bounds.top - 1, right: bounds.right + 1, bottom: bounds.bottom + 1)
      end

      # The view of +content+ in +viewport+. With a +previous+ view whose
      # cells are as big, the content stays where it was rather than
      # jumping to the middle; with a +focus+, that cell is brought into
      # view.
      def self.fit(viewport:, content:, units:, focus: nil, previous: nil)
        pad = units.px(M.board_pad)
        room = [viewport.width - (2 * pad), viewport.height - (2 * pad)]
        cell = [room[0] / content.width, room[1] / content.height].min.clamp(units.px(M.cell_min), units.px(M.cell_max))
        view = new(viewport:, cell:, x: 0, y: 0, content:, pad:).centered
        view = view.with(x: previous.x, y: previous.y) if previous&.cell == cell && view.pannable?
        view = view.reveal(focus) if focus
        view.clamped
      end

      def pannable? = overflows?(:x) || overflows?(:y)

      # The view moved by (+dx+, +dy+) pixels, as a drag or a scroll moves
      # it, but kept within its content.
      def pan(dx, dy) = with(x: x + dx, y: y + dy).clamped

      # The cell under the pixel (+px+, +py+), or nil outside the viewport.
      def cell_at(px, py)
        return unless viewport.contains?(px, py)

        Position.new(column: ((px - x) / cell.to_f).floor, row: ((py - y) / cell.to_f).floor)
      end

      # Where the cell at +position+ is drawn, on whole pixels.
      def rect_of(position)
        left, right = edge(x, position.column), edge(x, position.column + 1)
        top, bottom = edge(y, position.row), edge(y, position.row + 1)
        Rect.new(x: left, y: top, width: right - left, height: bottom - top)
      end

      def visible?(position) = rect_of(position).then { it.right > viewport.x && it.x < viewport.right && it.bottom > viewport.y && it.y < viewport.bottom }

      # Every column and row with any part inside the viewport.
      def visible_columns = (((viewport.x - x) / cell.to_f).floor..((viewport.right - x) / cell.to_f).floor)
      def visible_rows = (((viewport.y - y) / cell.to_f).floor..((viewport.bottom - y) / cell.to_f).floor)

      # The view panned just enough to show the cell at +position+ with the
      # padding around it.
      def reveal(position)
        rect = rect_of(position)
        dx = shortfall(rect.x, rect.right, viewport.x + pad, viewport.right - pad)
        dy = shortfall(rect.y, rect.bottom, viewport.y + pad, viewport.bottom - pad)
        with(x: x + dx, y: y + dy)
      end

      # The content in the middle of the viewport.
      def centered
        with(x: (viewport.center_x - ((content.left + (content.width / 2.0)) * cell)).round,
             y: (viewport.center_y - ((content.top + (content.height / 2.0)) * cell)).round)
      end

      # Within bounds: centred along an axis that fits, else panned no
      # further than the content's edges.
      def clamped
        middle = centered
        with(x: overflows?(:x) ? x.clamp(*range(:x)) : middle.x, y: overflows?(:y) ? y.clamp(*range(:y)) : middle.y)
      end

      # The view +amount+ of the way to +other+, as the camera eases.
      def toward(other, amount)
        return other if amount >= 1.0

        with(viewport: other.viewport, content: other.content, cell: cell + ((other.cell - cell) * amount),
             x: x + ((other.x - x) * amount), y: y + ((other.y - y) * amount))
      end

      private

      def edge(origin, index) = (origin + (index * cell)).round

      def span(axis) = axis == :x ? content.width * cell : content.height * cell
      def room(axis) = (axis == :x ? viewport.width : viewport.height) - (2 * pad)
      def overflows?(axis) = span(axis) > room(axis)

      # The origins that keep the content's edges at or past the
      # viewport's padded edges.
      def range(axis)
        if axis == :x
          [viewport.right - pad - ((content.right + 1) * cell), viewport.x + pad - (content.left * cell)]
        else
          [viewport.bottom - pad - ((content.bottom + 1) * cell), viewport.y + pad - (content.top * cell)]
        end
      end

      def shortfall(low, high, least, most)
        if low < least then least - low
        elsif high > most then most - high
        else 0
        end
      end
    end
  end
end
