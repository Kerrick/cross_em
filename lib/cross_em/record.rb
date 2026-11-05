# frozen_string_literal: true

module CrossEm
  # What is saved of a day's game: enough to put the board and the pool
  # back exactly as they were. As JSON it carries the original's fields:
  # whether the game was won and finished, how many letters went unused,
  # the seed, the pool's slots in order and the board's letters.
  class Record < Data.define(:day, :pool, :board, :status)
    # A saved record that cannot be this day's game.
    class Invalid < ArgumentError; end

    # The record a saved Hash describes, checked: twelve slots, and
    # between the pool and the board exactly the day's twelve letters,
    # under the day's own number. Anything else raises Invalid rather than
    # open a game the rules cannot play.
    def self.from_h(hash)
      day = Day.new(date: Date.iso8601(hash.fetch("seed")))
      pool = Pool.new(slots: hash.fetch("pool"))
      board = Board.new(cells: hash.fetch("board").to_h { |cell| cell_of(cell) })
      status = status_of(won: hash.fetch("won"), finished: hash.fetch("finished"))
      new(day:, pool:, board:, status:).tap { it.validate(hash.fetch("number")) }
    end

    def self.cell_of(cell)
      [Position.new(column: cell.fetch("column"), row: cell.fetch("row")), cell.fetch("letter")]
    end

    def self.status_of(won:, finished:)
      if !finished then :playing
      elsif won then :won
      else :lost
      end
    end

    def number = day.number

    def validate(number)
      raise Invalid, "day #{day.seed} is No. #{day.number}, not #{number}" unless number == day.number
      raise Invalid, "the pool has #{pool.size} slots" unless pool.size == Rules::LETTER_COUNT

      letters = (pool.letters + board.cells.values).sort
      raise Invalid, "the letters are not #{day.seed}'s" unless letters == day.letters.sort
    end
    def won? = status == :won
    def finished? = status != :playing
    def unused = pool.unused_count

    def to_h
      {
        "number" => number,
        "seed" => day.seed,
        "won" => won?,
        "finished" => finished?,
        "unused" => unused,
        "pool" => pool.slots,
        "board" => board.positions.map { |at| {"column" => at.column, "row" => at.row, "letter" => board[at]} }
      }
    end
  end
end
