# frozen_string_literal: true

require "presentation_helper"

class SpatialTest < Minitest::Test
  include PresentationTest

  def target(id, x, y, width, height, region: :main) = Target.new(id:, region:, rect: rect(x, y, width, height))

  def pick(from, direction, targets) = Spatial.pick(from.rect, direction, targets - [from])&.id

  # An irregular layout, in the spirit of the results:
  #
  #   [  wide  ][b]
  #   [c ][ d ]
  #        [  e  ]
  def irregular
    {wide: target(:wide, 0, 0, 200, 40), b: target(:b, 210, 0, 40, 40), c: target(:c, 0, 60, 60, 40),
     d: target(:d, 70, 60, 90, 40), e: target(:e, 100, 120, 150, 40)}
  end

  def test_each_direction_picks_the_nearest_in_line
    t = irregular
    all = t.values

    assert_equal :b, pick(t[:wide], :right, all)
    assert_equal :wide, pick(t[:b], :left, all)
    assert_equal :d, pick(t[:wide], :down, all), "c and d both lie under the wide one; d nearer its middle"
    assert_equal :c, pick(t[:d], :left, all)
    assert_equal :d, pick(t[:c], :right, all)
    assert_equal :wide, pick(t[:d], :up, all), "d is under the wide one, not under b"
    assert_equal :e, pick(t[:d], :down, all)
    assert_equal :d, pick(t[:e], :up, all)
  end

  def test_nothing_lies_beyond_the_edge
    t = irregular
    all = t.values

    assert_nil pick(t[:wide], :up, all)
    assert_nil pick(t[:wide], :left, all)
    assert_nil pick(t[:e], :down, all)
    assert_nil pick(t[:b], :right, all)
  end

  def test_in_line_far_beats_near_off_to_the_side
    from = target(:from, 100, 300, 40, 40)
    straight = target(:straight, 100, 100, 40, 40)
    aside = target(:aside, 200, 240, 40, 40)

    assert_equal :straight, pick(from, :up, [from, straight, aside])
  end

  def test_overlapping_across_is_in_line_and_middles_break_a_tie
    from = target(:from, 100, 100, 40, 40)
    left_edge = target(:left_edge, 70, 160, 40, 40)
    centred = target(:centred, 100, 160, 40, 40)

    assert_equal :centred, pick(from, :down, [from, left_edge, centred])
  end

  def test_a_neighbour_whose_middle_is_not_past_the_edge_does_not_count
    from = target(:from, 100, 100, 100, 40)
    overlapping = target(:overlapping, 140, 110, 40, 40)

    assert_nil pick(from, :down, [from, overlapping]), "its middle is inside the focused thing"
    assert_nil pick(irregular[:wide], :left, irregular.values), "c is below, not left"
  end

  def test_nearest_to_a_point
    t = irregular
    all = t.values

    assert_equal :d, Spatial.nearest(all, 100, 80).id, "inside d"
    assert_equal :b, Spatial.nearest(all, 260, 20).id, "just right of b"
    assert_equal :e, Spatial.nearest(all, 300, 200).id
    assert_in_delta 0.0, Spatial.distance(t[:c].rect, 10, 70)
    assert_in_delta 5.0, Spatial.distance(t[:c].rect, 65, 70)
  end

  def test_a_rect_cut_to_another
    assert_equal rect(50, 20, 50, 30), rect(0, 20, 100, 30).intersect(rect(50, 0, 100, 100))
    assert_predicate rect(0, 0, 10, 10).intersect(rect(20, 20, 5, 5)), :empty?
  end
end
