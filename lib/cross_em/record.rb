# frozen_string_literal: true

module CrossEm
  # What is saved of a day's game: enough to put the board and the pool
  # back exactly as they were. As JSON it carries the original's fields:
  # whether the game was won and finished, how many letters went unused,
  # the seed, the pool's slots in order and the board's letters.
  class Record < Data.define(:day, :pool, :board, :status)
    def self.from_h(hash)
      new(
        day: Day.new(date: Date.iso8601(hash.fetch("seed"))),
        pool: Pool.new(slots: hash.fetch("pool")),
        board: Board.new(cells: hash.fetch("board").to_h { |cell| [Position.new(column: cell.fetch("column"), row: cell.fetch("row")), cell.fetch("letter")] }),
        status: status_of(won: hash.fetch("won"), finished: hash.fetch("finished"))
      )
    end

    def self.status_of(won:, finished:)
      if !finished then :playing
      elsif won then :won
      else :lost
      end
    end

    def number = day.number
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
