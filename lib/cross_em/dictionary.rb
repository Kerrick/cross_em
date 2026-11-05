# frozen_string_literal: true

module CrossEm
  # The words that count, read once from the word list into a Set, so a
  # lookup is a hash probe. The file itself ships unmodified.
  class Dictionary
    FILE = "wordlist.txt"

    def self.parse(text) = new(text.each_line(chomp: true).reject(&:empty?))

    def initialize(words)
      @words = words.to_set.freeze
    end

    # Matching is exact, against the word in lowercase.
    def include?(word) = @words.include?(word.downcase)

    def size = @words.size
  end
end
