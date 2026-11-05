# frozen_string_literal: true

module CrossEm
  # The fixed facts of the puzzle. Everything else in the rules follows
  # from these, so they live together, apart from how the game looks.
  module Rules
    NAME = "Cross ’em" # with U+2019, as the original writes it

    # The day of puzzle 0. Each later UTC day counts one more.
    LAUNCH = Date.new(2022, 2, 19)

    # A word of fewer letters than this is a problem.
    MINIMUM_WORD_LENGTH = 3

    # The twelve letter dice, each with its six faces in the original's
    # order. The order matters: the day's roll depends on it.
    DICE = [
      %w[B Z X S N K],
      %w[H R N R H N],
      %w[N O N I I Y],
      %w[C B T C J D],
      %w[E A E O O A],
      %w[T T C C S M],
      %w[R F D L L W],
      %w[T T W H P H],
      %w[A I U E O U],
      %w[L G R G D R],
      %w[B L M M Y L],
      %w[P F P K G V]
    ].map(&:freeze).freeze

    LETTER_COUNT = DICE.size

    # The share text shows the pool in rows of this many slots.
    POOL_ROW_LENGTH = 6
  end
end
