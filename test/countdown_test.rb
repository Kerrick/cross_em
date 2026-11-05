# frozen_string_literal: true

require "test_helper"

class CountdownTest < Minitest::Test
  include CrossEm

  def test_it_counts_to_the_next_utc_midnight
    now = Time.utc(2026, 11, 5, 14, 2, 3)

    assert_equal "09:57:57", Countdown.between(now, Day.today(now).ends_at).to_s
  end

  def test_part_of_a_second_still_shows_as_a_second
    countdown = Countdown.between(Time.utc(2026, 11, 5, 23, 59, 59.25r), Time.utc(2026, 11, 6))

    assert_equal "00:00:01", countdown.to_s
    refute_predicate countdown, :done?
  end

  def test_it_stops_at_zero
    countdown = Countdown.between(Time.utc(2026, 11, 6, 0, 0, 1), Time.utc(2026, 11, 6))

    assert_equal "00:00:00", countdown.to_s
    assert_predicate countdown, :done?
  end
end
