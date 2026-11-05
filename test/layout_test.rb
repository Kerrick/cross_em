# frozen_string_literal: true

require "presentation_helper"

class LayoutTest < Minitest::Test
  include PresentationTest

  def layout(width, height, scale: 1, **) = Layout.for(width: width * scale, height: height * scale, units: units(scale), **)

  def all_rects(layout)
    [layout.header, layout.board, layout.status, *layout.pool, *layout.header_buttons.map(&:last),
     *layout.controls&.each&.map(&:last), *layout.results&.then { [it.heading, *it.stats, it.countdown, it.copy] }].compact
  end

  def test_a_phone_is_upright_with_the_pool_and_controls_under_the_board
    phone = layout(390, 844, scale: 3)

    refute phone.landscape
    assert_operator phone.board.bottom, :<=, phone.status.y
    assert_operator phone.status.bottom, :<=, phone.pool.first.y
    assert_operator phone.pool.last.bottom, :<=, phone.controls.shuffle.y
    assert_operator phone.controls.shuffle.bottom, :<=, 844 * 3
  end

  def test_pool_tiles_and_controls_are_at_least_a_fingertip
    [[390, 844], [320, 568], [844, 390], [1366, 1024], [820, 1180], [1280, 800]].each do |width, height|
      layout = layout(width, height, scale: 2)

      layout.pool.each { assert_operator it.width, :>=, 88, "#{width}x#{height} tile" }
      layout.controls.each { |_, rect| assert_operator rect.height, :>=, 88 }
      layout.header_buttons.each { |_, rect| assert_operator rect.width, :>=, 88 }
    end
  end

  def test_pool_tiles_grow_but_no_larger_than_64_points
    assert_equal 64, layout(1366, 1024).pool.first.width
  end

  def test_the_pool_is_two_rows_of_six
    pool = layout(390, 844).pool

    assert_equal 12, pool.size
    assert_equal 6, pool.map(&:y).tally.values.first
  end

  def test_a_narrow_column_makes_rows_of_four
    pool = layout(640, 480).pool # 320-point column: six would be 46 points

    assert_equal 6, pool.map(&:y).tally.values.first
    pool = layout(620, 520, safe: rect(0, 0, 620, 520)).pool

    assert_includes [4, 6], pool.map(&:y).tally.values.first
  end

  def test_wide_windows_put_the_pool_in_a_column_beside_the_board
    desk = layout(1280, 800)

    assert desk.landscape
    assert_operator desk.board.right, :<, desk.pool.first.x
    assert_operator desk.board.width, :>, desk.width / 2
  end

  def test_nothing_overlaps_and_everything_stays_on_screen
    [[390, 844], [820, 1180], [1366, 1024], [1280, 800], [844, 390]].each do |width, height|
      [false, true].each do |over|
        layout = layout(width, height, over:)
        rects = all_rects(layout)

        rects.each do |r|
          assert_operator r.x, :>=, 0, "#{width}x#{height} over=#{over}"
          assert_operator r.bottom, :<=, height, "#{width}x#{height} over=#{over}: #{r}"
        end
        assert_operator layout.board.height, :>, 100, "#{width}x#{height} over=#{over}"
      end
    end
  end

  def test_everything_stays_inside_the_safe_area
    safe = rect(0, 141, 1170, 2532 - 141 - 102)
    layout = Layout.for(width: 1170, height: 2532, units: units(3), safe:)

    assert_operator layout.header.y, :>=, safe.y
    assert_operator layout.controls.shuffle.bottom, :<=, safe.bottom
  end

  def test_when_the_game_is_over_results_replace_the_controls
    over = layout(390, 844, over: true)

    assert_nil over.controls
    assert_nil over.status
    assert_equal 4, over.results.stats.size
    assert_operator over.results.countdown.right, :<=, over.results.copy.x
  end

  def test_after_a_win_the_empty_pool_makes_room_for_the_board
    with_pool = layout(390, 844, over: true, pool: true)
    without = layout(390, 844, over: true, pool: false)

    assert_empty without.pool
    assert_operator without.board.height, :>, with_pool.board.height
  end
end
