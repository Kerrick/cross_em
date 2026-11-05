# frozen_string_literal: true

require "presentation_helper"

class UnitsTest < Minitest::Test
  include PresentationTest

  def test_points_become_whole_pixels_at_the_screens_density
    assert_equal 88, units(2).px(44)
    assert_equal 132, units(3).px(44)
    assert_equal 45, units(1.5).px(30)
  end

  def test_a_stroke_is_never_thinner_than_a_pixel
    assert_equal 1, units(1).stroke(0.3)
    assert_equal 3, units(3).stroke(1)
  end

  def test_a_missing_density_counts_as_one
    assert_in_delta 1.0, Units.new(scale: 0).scale
  end

  def test_phones_tablets_and_laptops_draw_the_design_at_its_own_size
    [[390, 844, 3], [844, 390, 3], [820, 1180, 2], [1280, 800, 2], [1440, 900, 2]].each do |w, h, d|
      assert_in_delta d, Units.for_window(density: d, width: w * d, height: h * d).scale, 1e-9, "#{w}x#{h}"
    end
  end

  def test_a_big_screen_draws_the_design_larger_in_eighths
    assert_in_delta 1.25, Units.for_window(density: 1, width: 1920, height: 1080).scale
    assert_in_delta 2.25, Units.for_window(density: 2, width: 2 * 1512, height: 2 * 982).scale
    assert_in_delta 2.25, Units.for_window(density: 2, width: 2 * 1366, height: 2 * 1024).scale
    assert_in_delta 1.5, Units.for_window(density: 1, width: 3840, height: 2160).scale
  end

  def test_columns_share_out_every_pixel
    parts = rect(10, 0, 101, 20).columns(3, 5)

    assert_equal [10, 46, 81], parts.map(&:x)
    assert_equal [31, 30, 30], parts.map(&:width)
    assert_equal 111, parts.last.right
  end

  def test_reach_grows_a_small_rect_to_a_fingertip
    assert_equal rect(-12, -12, 44, 44), rect(0, 0, 20, 20).reach(44)
  end
end
