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

  def test_a_day_turns_over_at_nine_utc_for_everyone
    before = Time.new(2026, 11, 5, 2, 59, 59, "-06:00") # 08:59:59 UTC
    after = Time.new(2026, 11, 5, 3, 0, 0, "-06:00") # 09:00 UTC, 3 am in Missouri

    assert_equal "2026-11-04", Day.today(before).seed
    assert_equal "2026-11-05", Day.today(after).seed
    assert_equal "2026-11-05", Day.today(Time.new(2026, 11, 5, 18, 0, 0, "+09:00")).seed
  end

  def test_the_next_puzzle_begins_at_nine_utc
    assert_equal Time.utc(2026, 11, 5, 9), Day.numbered(1720).begins_at
    assert_equal Time.utc(2026, 11, 6, 9), Day.numbered(1720).ends_at
    assert_equal 1721, Day.numbered(1720).succ.number
  end

  def test_the_day_is_named_with_a_curly_apostrophe
    assert_equal "Cross ’em 1720", Day.numbered(1720).to_s
  end
end
