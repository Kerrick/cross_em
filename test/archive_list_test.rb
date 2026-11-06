# frozen_string_literal: true

require "presentation_helper"

class ArchiveListTest < Minitest::Test
  include PresentationTest

  TODAY = Day.numbered(1720) # 2026-11-05

  def record(number, status, board: board("CAT"))
    day = Day.numbered(number)
    Record.new(day:, pool: Pool.new(slots: Array.new(12)), board:, status:)
  end

  def list(records = {}) = ArchiveList.new(today: TODAY, records:, month: 30, day: 50)

  def test_every_day_from_today_back_to_number_zero_newest_first
    days = list.days

    assert_equal 1721, days.size
    assert_equal [1720, 1719], days.first(2).map(&:number)
    assert_equal 0, days.last.number
    assert_equal Date.new(2022, 2, 19), days.last.date
  end

  def test_days_are_grouped_under_a_heading_for_each_month
    rows = list.rows

    assert_predicate rows.first, :month?
    assert_equal Date.new(2026, 11, 5), rows.first.date
    assert_equal [5, 4, 3, 2, 1], rows[1..5].map { it.date.day }
    assert_predicate rows[6], :month?
    assert_equal 10, rows[6].date.month
    # Feb 2022 to Nov 2026: 58 months.
    assert_equal 58, rows.count(&:month?)
  end

  def test_each_day_has_the_players_status
    statuses = list({1720 => record(1720, :playing), 1719 => record(1719, :won), 1718 => record(1718, :lost)})
               .days.first(4).map(&:status)

    assert_equal %i[playing won lost unplayed], statuses
  end

  def test_rows_stack_without_gaps
    rows = list.rows

    rows.each_cons(2) { |above, below| assert_equal above.bottom, below.y }
    assert_equal rows.last.bottom, list.height
    assert_equal (58 * 30) + (1721 * 50), list.height
  end

  def test_only_the_rows_in_view_are_drawn
    list = list()

    # The heading (0-30), then days at 30, 80, 130, ...
    assert_equal [0, 30, 80], list.visible(0, 100).map(&:y)
    assert_equal [80, 130], list.visible(100, 60).map(&:y), "a row cut by the top edge counts"
    assert_equal [list.rows.last], list.visible(list.height - 10, 300)
    assert_empty list.visible(list.height, 300)
  end

  def test_a_point_finds_its_row
    list = list()

    assert_predicate list.row_at(10), :month?
    assert_equal 1720, list.row_at(30).number
    assert_equal 1719, list.row_at(129).number
    assert_nil list.row_at(list.height)
  end

  def test_the_month_heading_of_a_row
    list = list()
    row = list.day_row(1700) # 2026-10-16

    assert_equal 10, list.month_of(row).date.month
  end

  def test_stepping_through_days_stays_in_the_list
    list = list()

    assert_equal 1719, list.step(1720, 1).number
    assert_equal 1720, list.step(1720, -5).number
    assert_equal 0, list.step(3, 10).number
  end

  def test_a_tap_on_the_pinned_month_heading_opens_no_day
    layout = ArchiveLayout.build(list: list(), safe: rect(0, 0, 390, 844), units: units)
    body = layout.body
    scroll = 100 # the heading is pinned; day 1719 (80-130) is under it
    heading, pinned = layout.pinned(scroll)

    assert_predicate heading, :month?
    assert_equal body.y, pinned.y
    assert_nil layout.control_at(body.center_x, body.y + 5, scroll), "the pinned heading, not the day under it"
    assert_equal [:day, 1718], layout.control_at(body.center_x, body.y + 40, scroll).id
    assert_nil layout.pinned(0), "at the top the heading is in its own place"
  end
end
