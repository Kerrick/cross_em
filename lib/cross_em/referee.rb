# frozen_string_literal: true

module CrossEm
  # Checks a board against the word list, as the original does:
  #
  # 1. every letter of a word shorter than Rules::MINIMUM_WORD_LENGTH is
  #    too short;
  # 2. every letter of a longer word not in the word list is not a word;
  # 3. starting at the first letter in reading order not yet marked, the
  #    letters it reaches are kept, and every other letter is
  #    disconnected. The kept group is the first one found, not the
  #    largest.
  class Referee
    def initialize(dictionary)
      @dictionary = dictionary
    end

    def check(board)
      problems = {}
      mark = ->(positions, reason) { positions.each { problems[it] ||= reason } }

      board.words.each { |word| mark.(word.positions, verdict(word)) if verdict(word) }

      first = board.positions.find { !problems.key?(it) }
      if first
        kept = board.group_of(first)
        mark.(board.positions.reject { kept.include?(it) }, :disconnected)
      end

      Check.new(problems:)
    end

    private

    def verdict(word)
      if word.length < Rules::MINIMUM_WORD_LENGTH then :too_short
      elsif !@dictionary.include?(word.text) then :not_a_word
      end
    end
  end
end
