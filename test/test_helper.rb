# frozen_string_literal: true

require "minitest/autorun"
require "cross_em"

module CrossEmTest
  include CrossEm

  WORDS = %w[cat cats dog tag act wordsmithing].freeze

  def dictionary = Dictionary.new(WORDS)
  def referee = Referee.new(dictionary)

  def at(column, row) = Position.new(column:, row:)

  # A board drawn as rows of text, the top-left character at the origin;
  # "." is an empty cell.
  def board(*rows)
    cells = rows.each_with_index.flat_map do |line, row|
      line.chars.each_with_index.filter_map { |char, column| [at(column, row), char] unless char == "." }
    end
    Board.new(cells: cells.to_h)
  end

  def pool(letters) = Pool.new(slots: letters.chars.map { it == "." ? nil : it })

  def game(pool: "CATSDOGTAGCA", board: Board.empty, status: :playing, day: Day.numbered(1720))
    pool = self.pool(pool) if pool.is_a?(String)
    Game.new(day:, pool:, board:, status:, referee:)
  end

  # Collects every event a game tells.
  def events_of(game) = [].tap { |events| game.subscribe { events << it } }
end
