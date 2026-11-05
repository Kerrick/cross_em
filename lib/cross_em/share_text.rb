# frozen_string_literal: true

module CrossEm
  # The result as plain text, square for square the original's format, so
  # results compare across both games:
  #
  #   Cross ’em 1720 12/12
  #
  #   🟩🟩🟩🟩🟩🟩
  #   🟩🟩🟩🟩🟩🟩
  #
  #   🟦🟦🟦🟦⬜
  #   ...
  #
  # An empty cell is ⬛ instead of ⬜ when the game is showing its dark
  # appearance.
  class ShareText < Data.define(:game, :dark)
    UNUSED = "🟥"
    USED_IN_WIN = "🟩"
    USED_IN_LOSS = "🟨"
    GOOD = "🟦"
    PROBLEM = "🟥"
    EMPTY_LIGHT = "⬜"
    EMPTY_DARK = "⬛"

    def self.for(game, dark: false) = new(game:, dark:)

    def to_s = [heading, pool_rows, board_rows].reject(&:empty?).join("\n\n")

    def heading = "#{Rules::NAME} #{game.day.number} #{game.good_letters}/#{Rules::LETTER_COUNT}"

    def pool_rows
      used = game.won? ? USED_IN_WIN : USED_IN_LOSS
      game.pool.slots.map { it ? UNUSED : used }.each_slice(Rules::POOL_ROW_LENGTH).map(&:join).join("\n")
    end

    def board_rows
      bounds = game.board.bounds or return ""
      bounds.rows.map { |row| bounds.columns.map { square(Position.new(column: it, row:)) }.join }.join("\n")
    end

    private

    def square(position)
      if !game.board.occupied?(position) then dark ? EMPTY_DARK : EMPTY_LIGHT
      elsif game.check&.problem?(position) then PROBLEM
      else GOOD
      end
    end
  end
end
