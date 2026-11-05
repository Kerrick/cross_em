# frozen_string_literal: true

module CrossEm
  # Where a whole word can go on the board, by shape alone: a player at a
  # keyboard types a word, and this finds every run of cells it could
  # fill. It never asks whether a word is real. While letters wait in the
  # pool the rules give no feedback, so the search is pure geometry and
  # counting, and a nonsense word fits wherever its letters do.
  #
  # A word fits a run of cells, across or down, when each cell either
  # already holds that letter or is empty and gets one from the pool
  # (counting the pool's letters, so a word needs two Es to use two), at
  # least one letter is new, the cells just before and after the run are
  # empty, so the board then reads exactly the word there, and the run
  # touches the letters already placed, by crossing one or lying beside
  # one. On an empty board a word goes across from the origin.
  #
  # Runs that cross a letter already placed come first: when there are
  # any, only they are offered, else the ones that lie beside. Either way
  # they come in reading order of their first cell, across before down.
  class WordFit
    # A run of cells for +word+, from +start+ going +direction+: its
    # +positions+, the +fresh+ letters it needs from the pool as
    # [position, letter] pairs in an order the rules accept (each beside
    # a letter already down), and whether it crosses a placed letter.
    class Placement < Data.define(:word, :direction, :positions, :fresh, :crossing)
      def start = positions.first
      def fresh_positions = fresh.map(&:first)
      def crossing? = crossing
    end

    # Why a word fits nowhere: +reason+ is :empty (nothing typed),
    # :missing (+letters+ are in neither the pool nor on the board),
    # :on_board (the board already reads the word, so it adds nothing),
    # or :nowhere (the letters are there but no run takes them).
    Misfit = Data.define(:word, :reason, :letters)

    DIRECTIONS = %i[across down].freeze

    attr_reader :board, :pool

    def initialize(board:, pool:)
      @board, @pool = board, pool
    end

    # Every Placement for +word+, best first, as the class comment says.
    def placements(word)
      word = word.to_s.upcase
      return [] if word.empty?

      found = candidates(word).filter_map { |start, direction| fit(word, start, direction) }
      crossing = found.select(&:crossing?)
      chosen = crossing.empty? ? found : crossing
      chosen.sort_by { [it.start.row, it.start.column, DIRECTIONS.index(it.direction)] }
            .uniq { it.positions.sort }
    end

    # Why +word+ has no placements: a Misfit. Only meaningful when
    # #placements is empty.
    def misfit(word)
      word = word.to_s.upcase
      return Misfit.new(word:, reason: :empty, letters: []) if word.empty?

      missing = subtract(subtract(word.chars, pool.letters), board.cells.values)
      return Misfit.new(word:, reason: :missing, letters: missing) unless missing.empty?
      return Misfit.new(word:, reason: :on_board, letters: []) if board.words.any? { it.text == word }

      Misfit.new(word:, reason: :nowhere, letters: [])
    end

    private

    # Every start and direction worth trying: on an empty board only the
    # origin across, else every run that could reach the letters.
    def candidates(word)
      return [[Position::ORIGIN, :across]] if board.empty?

      bounds = board.bounds
      reach = word.length
      rows = (bounds.top - reach)..(bounds.bottom + 1)
      columns = (bounds.left - reach)..(bounds.right + 1)
      rows.flat_map { |row| columns.map { |column| Position.new(column:, row:) } }.product(DIRECTIONS)
    end

    def fit(word, start, direction)
      positions = word.length.times.each_with_object([start]) { |_, run| run << run.last.after(direction) }
      after = positions.pop
      return if board.occupied?(start.before(direction)) || board.occupied?(after)

      fresh = []
      crossing = false
      positions.zip(word.chars) do |position, letter|
        if (there = board[position])
          return unless there == letter

          crossing = true
        else
          fresh << [position, letter]
        end
      end
      return if fresh.empty? || !subtract(fresh.map(&:last), pool.letters).empty?
      return unless board.empty? || crossing || fresh.any? { |position, _| position.neighbors.any? { board.occupied?(it) } }

      Placement.new(word:, direction:, positions: positions.freeze, fresh: in_order(fresh).freeze, crossing:)
    end

    # The fresh letters in an order the rules accept, one at a time: each
    # beside a letter already down (the first, on an empty board, at the
    # origin), taking the earliest in the word that can go.
    def in_order(fresh)
      down = board.cells.keys.to_set
      left = fresh.dup
      order = []
      until left.empty?
        ready = left.index { |position, _| down.empty? ? position == Position::ORIGIN : position.neighbors.any? { down.include?(it) } }
        break order.concat(left) unless ready # cannot happen for a run that touches the board

        position, letter = left.delete_at(ready)
        order << [position, letter]
        down << position
      end
      order
    end

    # The letters of +letters+ left after taking away one for each of
    # +taken+ (a multiset difference).
    def subtract(letters, taken)
      counts = taken.tally
      letters.reject { |letter| counts[letter].to_i.positive? && (counts[letter] -= 1) }
    end
  end
end
