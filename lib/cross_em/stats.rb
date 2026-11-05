# frozen_string_literal: true

module CrossEm
  # The numbers shown after a game, from every saved Record. A day counts
  # as played once anything was saved for it, finished or not.
  class Stats < Data.define(:played, :win_percent, :current_streak, :max_streak)
    def self.of(records, today:)
      won = records.select(&:won?).map(&:number).to_set
      new(
        played: records.size,
        win_percent: records.empty? ? 0 : Rational(won.size * 100, records.size).round,
        current_streak: (today.number).downto(0).take_while { won.include?(it) }.size,
        max_streak: won.sort.slice_when { |a, b| b != a + 1 }.map(&:size).max || 0
      )
    end
  end
end
