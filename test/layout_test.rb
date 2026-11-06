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

  def test_with_every_letter_down_the_empty_pool_makes_room_for_the_board
    [[390, 844], [1280, 800]].each do |width, height|
      with_pool = layout(width, height)
      without = layout(width, height, pool: false)

      assert_empty without.pool
      assert_operator without.board.height, :>, with_pool.board.height if width < height
      assert_operator without.status.bottom, :<=, without.controls.shuffle.y
    end
  end

  def test_after_a_win_the_empty_pool_makes_room_for_the_board
    with_pool = layout(390, 844, over: true, pool: true)
    without = layout(390, 844, over: true, pool: false)

    assert_empty without.pool
    assert_operator without.board.height, :>, with_pool.board.height
  end

  def test_every_window_from_a_small_phone_up_leaves_the_board_a_cell
    least = Look::METRICS.cell_min + (2 * Look::METRICS.board_pad)
    (320..1400).step(37).each do |width|
      [*(320..1100).step(41), 480].each do |height|
        next if [width, height].max < 480 # smaller than any phone, either way up

        [[false, true], [true, true], [true, false]].each do |over, pool|
          [1, 3].each do |scale|
            layout = layout(width, height, scale:, over:, pool:)
            where = "#{width}x#{height} pt at #{scale}x, over=#{over} pool=#{pool}"

            assert_operator layout.board.height, :>=, least * scale, where
            assert_operator layout.board.width, :>=, least * scale, where
            assert layout.fits?(Rect.new(x: 0, y: 0, width: width * scale, height: height * scale), units(scale)), where
          end
        end
      end
    end
  end

  def test_a_phone_on_its_side_puts_the_pool_beside_the_board
    assert layout(568, 320).landscape
    assert layout(568, 320, over: true).landscape
  end

  def test_after_the_game_a_cramped_pool_shrinks_rather_than_the_board
    cramped = layout(320, 480, over: true, pool: true)

    assert_operator cramped.pool.first.width, :<=, 44
    assert_equal 6, cramped.pool.map(&:y).tally.values.first
  end

  def test_a_very_wide_window_sets_the_game_on_a_centred_page
    wide = layout(1536, 864)

    assert_equal rect(178, 16, 1180, 832), wide.paper
    all_rects(wide).each { assert wide.paper.contains?(it.x, it.y) && it.right <= wide.paper.right, it.inspect }
    assert_operator wide.board.x, :>, wide.paper.x
  end

  def test_tablets_laptops_and_phones_use_the_whole_window
    [[390, 844, 3], [844, 390, 3], [820, 1180, 2], [1366, 1024, 2], [1280, 800, 2]].each do |width, height, density|
      size = {width: width * density, height: height * density}
      units = Units.for_window(density:, **size)

      assert_nil Layout.for(**size, units:).paper, "#{width}x#{height}"
    end
  end

  def test_a_wide_but_short_window_gives_up_the_page_before_the_board
    short = layout(1400, 330)

    assert_nil short.paper
    assert short.fits?(rect(0, 0, 1400, 330), units)
  end

  def test_the_statistics_share_the_measure_of_the_row_under_them
    tablet = layout(820, 1180, over: true)
    stats, row = tablet.results.stats, tablet.results

    assert_equal row.countdown.x, stats.first.x
    assert_equal row.copy.right, stats.last.right
  end

  def test_when_even_a_small_pool_leaves_no_room_the_results_buttons_share_a_row
    cramped = layout(505, 320, over: true, pool: true)
    results = cramped.results

    assert_equal [results.countdown.y] * 3, [results.copy.y, results.again.y, results.archive.y]
    assert_operator cramped.board.height, :>=, 68
  end

  def test_after_the_game_a_row_offers_play_again_and_past_puzzles
    results = layout(390, 844, over: true, pool: false).results

    assert_operator results.again.y, :>, results.copy.y
    assert_equal results.again.y, results.archive.y
    assert_operator results.again.height, :>=, 44
  end

  def test_the_header_has_four_buttons_a_fingertip_wide
    layout = layout(390, 844)

    assert_equal %i[archive help theme sound], layout.header_buttons.map(&:first)
    layout.header_buttons.each { |_, rect| assert_operator rect.width, :>=, 44 }
  end
end
