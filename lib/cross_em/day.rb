# frozen_string_literal: true

module CrossEm
  # One UTC calendar day, and so one puzzle. Everyone playing on the same
  # day gets the same letters.
  class Day < Data.define(:date)
    def self.today(now = Time.now) = new(date: now.utc.to_date)
    def self.numbered(number) = new(date: Rules::LAUNCH + number)

    # The seed is the date as YYYY-MM-DD, as the original's is.
    def seed = date.iso8601

    # Whole days since the launch: puzzle 0 is 2022-02-19.
    def number = (date - Rules::LAUNCH).to_i

    def succ = with(date: date.next_day)
    def begins_at = Time.utc(date.year, date.month, date.day)
    def ends_at = succ.begins_at

    # Rolls the twelve dice with this day's generator: one shuffle puts
    # the dice in order, then each die shuffles its faces and shows the
    # first.
    def letters
      random = Sfc32.seeded(seed)
      random.shuffle(Rules::DICE).map { |faces| random.shuffle(faces).first }
    end

    def to_s = "#{Rules::NAME} #{number}"
  end
end
