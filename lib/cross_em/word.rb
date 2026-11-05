# frozen_string_literal: true

module CrossEm
  # A run of letters on the grid, read left to right (+:across+) or top
  # to bottom (+:down+). A letter with no neighbor at all is a word of
  # one letter, whose direction is +:alone+.
  class Word < Data.define(:direction, :positions, :text)
    def length = text.length
    def to_s = text
  end
end
