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
