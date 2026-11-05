# frozen_string_literal: true

module CrossEm
  # A cell of the grid, which has no edges: +column+ grows to the right
  # and +row+ grows downward, and either may be negative.
  class Position < Data.define(:column, :row)
    # Positions sort in reading order: top to bottom, then left to right.
    def <=>(other) = [row, column] <=> [other.row, other.column]

    def left = with(column: column - 1)
    def right = with(column: column + 1)
    def up = with(row: row - 1)
    def down = with(row: row + 1)

    def neighbors = [up, left, right, down]

    # One step along a word's direction, forward or back.
    def after(direction) = direction == :across ? right : down
    def before(direction) = direction == :across ? left : up

    def to_s = "(#{column}, #{row})"

    # Where the first letter goes.
    ORIGIN = new(column: 0, row: 0)
  end
end
