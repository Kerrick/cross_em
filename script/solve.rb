# frozen_string_literal: true

# Finds ways to use all twelve of a day's letters, for trying out and
# screenshotting a win (development only). Prints each as a
# CROSS_EM_SCRIPT for the game to play by itself:
#
#   ruby script/solve.rb [YYYY-MM-DD] [how many]
#
# It tries two words crossing at a shared letter, then three words in a
# row of crossings (across, down, across), and checks each board with the
# game's own Referee.
require_relative "../lib/cross_em"

include CrossEm # rubocop:disable Style/MixinUsage

date = ARGV[0] ? Date.iso8601(ARGV[0]) : Date.today
wanted = Integer(ARGV[1] || 3)
day = Day.new(date:)
letters = day.letters
dictionary = Dictionary.parse(File.read(File.expand_path("../wordlist.txt", __dir__)))
referee = Referee.new(dictionary)
supply = letters.tally

fits = ->(tally) { tally.all? { |letter, count| supply.fetch(letter, 0) >= count } }
words = File.read(File.expand_path("../wordlist.txt", __dir__)).split.map(&:upcase).uniq
            .select { it.length.between?(3, 12) && fits.(it.chars.tally) }
puts "#{day} letters #{letters.join} : #{words.size} words fit"

def board_of(placements)
  cells = {}
  placements.each do |word, column, row, down|
    word.chars.each_with_index do |letter, i|
      at = Position.new(column: down ? column : column + i, row: down ? row + i : row)
      return nil if cells[at] && cells[at] != letter

      cells[at] = letter
    end
  end
  Board.new(cells:)
end

def script_of(placements)
  (["close"] + placements.map { |word, column, row, down| "word:#{word}:#{column}:#{row}:#{down ? 'down' : 'across'}" }).join(",")
end

found = 0
exact = ->(board) { board && board.cells.values.tally == supply && referee.check(board).clean? }
report = lambda do |placements|
  puts script_of(placements)
  found += 1
  exit if found >= wanted
end

by_length = words.group_by(&:length)
# Two words: lengths add to 13, crossing at one shared letter.
words.each do |a|
  (by_length[13 - a.length] || []).each do |b|
    a.chars.each_with_index do |letter, i|
      b.chars.each_with_index do |other, j|
        next unless letter == other

        placements = [[a, 0, 0, false], [b, i, -j, true]]
        report.(placements) if exact.(board_of(placements))
      end
    end
  end
end

# Three words: A across, B down through A, C across through B. Lengths add
# to 14.
words.each do |a|
  words.each do |b|
    next if a.length + b.length > 13

    rest = 14 - a.length - b.length
    candidates = by_length[rest] or next
    a.chars.each_with_index do |letter, i|
      b.chars.each_with_index do |other, j|
        next unless letter == other

        down_column = i
        b_top = -j
        b.chars.each_with_index do |crossing, k|
          next if (b_top + k - 0).abs < 2 # leave a row between the two across words

          candidates.each do |c|
            c.chars.each_with_index do |c_letter, m|
              next unless c_letter == crossing

              placements = [[a, 0, 0, false], [b, down_column, b_top, true], [c, down_column - m, b_top + k, false]]
              report.(placements) if exact.(board_of(placements))
            end
          end
        end
      end
    end
  end
end
puts "found #{found}"
