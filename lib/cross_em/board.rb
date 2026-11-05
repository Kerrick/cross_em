# frozen_string_literal: true

module CrossEm
  # The letters on the grid, by Position. The grid has no edges, so a
  # board is only as big as the letters on it.
  class Board < Data.define(:cells)
    def self.empty = new(cells: {})

    def initialize(cells:)
      super(cells: cells.dup.freeze)
    end

    def [](position) = cells[position]
    def occupied?(position) = cells.key?(position)
    def size = cells.size
    def empty? = cells.empty?

    # Every position with a letter, in reading order.
    def positions = cells.keys.sort

    # Where the next letter may go: the origin of an empty board, or else
    # every empty cell beside a letter.
    def targets
      return Set[Position::ORIGIN] if empty?

      cells.keys.flat_map(&:neighbors).reject { occupied?(it) }.to_set
    end

    def target?(position) = targets.include?(position)

    def place(position, letter)
      raise ArgumentError, "#{position} is not a target" unless target?(position)

      with(cells: cells.merge(position => letter))
    end

    # The letter at +position+, and the board without it.
    def lift(position)
      letter = cells.fetch(position) { raise ArgumentError, "#{position} is empty" }
      [letter, with(cells: cells.except(position))]
    end

    # Every word: runs of two or more across, then down, then each letter
    # that belongs to neither, as a word of one.
    def words
      runs = runs_along(:across) + runs_along(:down)
      in_runs = runs.flat_map(&:positions).to_set
      alone = positions.reject { in_runs.include?(it) }.map { word(:alone, [it]) }
      runs + alone
    end

    # Every letter reachable from +start+ by steps up, down, left and
    # right through letters.
    def group_of(start)
      group = Set[start]
      frontier = [start]
      until frontier.empty?
        frontier.pop.neighbors.each do |neighbor|
          frontier << neighbor if occupied?(neighbor) && group.add?(neighbor)
        end
      end
      group
    end

    # The smallest rectangle around every letter, or nil for an empty
    # board.
    def bounds
      return if empty?

      columns, rows = cells.keys.map(&:column).minmax, cells.keys.map(&:row).minmax
      Bounds.new(left: columns.first, top: rows.first, right: columns.last, bottom: rows.last)
    end

    private

    def runs_along(direction)
      starts = positions.select { !occupied?(it.before(direction)) && occupied?(it.after(direction)) }
      starts.map do |start|
        run = [start]
        run << run.last.after(direction) while occupied?(run.last.after(direction))
        word(direction, run)
      end
    end

    def word(direction, run) = Word.new(direction:, positions: run.freeze, text: run.map { cells[it] }.join)
  end

  # A rectangle of cells, inclusive at every edge.
  class Bounds < Data.define(:left, :top, :right, :bottom)
    def width = right - left + 1
    def height = bottom - top + 1
    def rows = (top..bottom)
    def columns = (left..right)
    def include?(position) = columns.cover?(position.column) && rows.cover?(position.row)
  end
end
