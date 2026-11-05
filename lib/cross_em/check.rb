# frozen_string_literal: true

module CrossEm
  # What a check found: the reason each problem letter is a problem, by
  # Position, and the words that made them problems. A letter is marked
  # once, for the first reason found, so the count is of letters, not
  # words.
  class Check < Data.define(:problems, :words)
    # A word that is a problem, and why: :too_short, :not_a_word or
    # :disconnected.
    Problem = Data.define(:word, :reason)

    def self.clean = new(problems: {})

    def initialize(problems:, words: [])
      super(problems: problems.dup.freeze, words: words.dup.freeze)
    end

    def problem?(position) = problems.key?(position)
    def reason(position) = problems[position]
    def count = problems.size
    def clean? = problems.empty?
  end
end
