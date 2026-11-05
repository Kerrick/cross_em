# frozen_string_literal: true

require "test_helper"

class DailyTest < Minitest::Test
  include CrossEmTest

  VECTORS = {
    "2022-02-19" => [0, "CRPHSULSFROI"],
    "2022-02-28" => [9, "RNRKOXYNCPOT"],
    "2024-02-29" => [740, "MIRCLSORVLPO"],
    "2026-11-05" => [1720, "JRLKTKRWIAEM"],
    "2030-01-01" => [2873, "HCYKGUAMKNDD"]
  }.freeze

  VECTORS.each do |seed, (number, letters)|
    define_method("test_#{seed}_is_puzzle_#{number}_with_#{letters}") do
      day = Day.new(date: Date.iso8601(seed))

      assert_equal seed, day.seed
      assert_equal number, day.number
      assert_equal letters, day.letters.join
      assert_equal day, Day.numbered(number)
    end
  end

  def test_the_generator_matches_the_originals_first_draws
    random = Sfc32.seeded("2022-02-19")

    [0.2537169876, 0.7891746445, 0.9707022002].each { assert_in_delta it, random.call, 1e-10 }
  end

  def test_a_day_is_a_utc_date
    late_in_new_york = Time.new(2026, 11, 4, 22, 30, 0, "-05:00")

    assert_equal "2026-11-05", Day.today(late_in_new_york).seed
  end

  def test_the_next_puzzle_begins_at_utc_midnight
    assert_equal Time.utc(2026, 11, 6), Day.numbered(1720).ends_at
    assert_equal 1721, Day.numbered(1720).succ.number
  end

  def test_the_day_is_named_with_a_curly_apostrophe
    assert_equal "Cross ’em 1720", Day.numbered(1720).to_s
  end
end
