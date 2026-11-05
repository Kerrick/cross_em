# frozen_string_literal: true

module CrossEm
  # What a check found: the reason each problem letter is a problem, by
  # Position. A letter is marked once, for the first reason found, so the
  # count is of letters, not words.
  class Check < Data.define(:problems)
    def self.clean = new(problems: {})

    def initialize(problems:)
      super(problems: problems.dup.freeze)
    end

    def problem?(position) = problems.key?(position)
    def reason(position) = problems[position]
    def count = problems.size
    def clean? = problems.empty?
  end
end
