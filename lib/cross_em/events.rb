# frozen_string_literal: true

module CrossEm
  # What a Game tells its listeners, one value per change. The shell
  # animates and sounds them; the archive saves after the ones that
  # change the board. Every change has already happened by the time its
  # event is told.
  module Events
    Selected = Data.define(:index)
    Deselected = Data.define(:index)

    # A letter left pool slot +index+ for the grid at +position+.
    Placed = Data.define(:letter, :index, :position)

    # A letter left the grid at +position+ for pool slot +index+.
    Returned = Data.define(:letter, :position, :index)

    # The pool was reordered: +order+ lists the old index of each slot.
    Shuffled = Data.define(:order)

    # Every letter went back, in reading order: +returns+ are Returned.
    Reset = Data.define(:returns)

    # All twelve letters were on the grid, or the player gave up, and the
    # board was checked.
    Checked = Data.define(:check)

    Won = Data.define(:game)
    Lost = Data.define(:game)

    # Events after which there is something new to save.
    SAVED = [Placed, Returned, Reset, Won, Lost].freeze
  end
end
