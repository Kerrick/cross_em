# frozen_string_literal: true

require "test_helper"

class StatsTest < Minitest::Test
  include CrossEmTest

  def record(number, status) = Record.new(day: Day.numbered(number), pool: pool("." * 12), board: Board.empty, status:)

  def stats(today, **days) = Stats.of(days.map { |number, status| record(number.to_s.to_i, status) }, today: Day.numbered(today))

  def test_nothing_played
    assert_equal Stats.new(played: 0, win_percent: 0, current_streak: 0, max_streak: 0), Stats.of([], today: Day.numbered(5))
  end

  def test_the_current_streak_ends_today_and_stops_at_a_gap
    result = stats(10, "5": :won, "6": :won, "8": :won, "9": :won, "10": :won)

    assert_equal 3, result.current_streak
    assert_equal 3, result.max_streak
  end

  def test_the_current_streak_is_zero_unless_today_is_won
    assert_equal 0, stats(10, "8": :won, "9": :won).current_streak
    assert_equal 0, stats(10, "9": :won, "10": :playing).current_streak
    assert_equal 0, stats(10, "9": :won, "10": :lost).current_streak
  end

  def test_the_max_streak_is_the_longest_run_of_won_numbers_ever
    result = stats(20, "1": :won, "2": :won, "3": :won, "4": :won, "5": :lost, "6": :won, "19": :won, "20": :won)

    assert_equal 4, result.max_streak
    assert_equal 2, result.current_streak
  end

  def test_a_loss_or_an_unfinished_day_still_counts_as_played
    assert_equal 3, stats(3, "1": :won, "2": :lost, "3": :playing).played
  end

  def test_win_percent_rounds_to_the_nearest_whole_number
    assert_equal 67, stats(3, "1": :won, "2": :won, "3": :lost).win_percent # 66.67
    assert_equal 33, stats(3, "1": :won, "2": :lost, "3": :lost).win_percent # 33.33
    assert_equal 13, stats(8, "1": :won, **(2..8).to_h { [it.to_s.to_sym, :lost] }).win_percent # 12.5
    assert_equal 100, stats(1, "1": :won).win_percent
  end
end
