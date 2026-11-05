# frozen_string_literal: true

require "presentation_helper"

class MotionTest < Minitest::Test
  include PresentationTest

  FROM = Rect.new(x: 0, y: 500, width: 50, height: 50)
  TO = Rect.new(x: 200, y: 100, width: 60, height: 60)

  def motion(calm: false) = Motion.new(calm:)

  def test_a_placed_tile_flies_from_its_slot_to_its_cell_and_lands
    motion = motion()
    motion.fly([:cell, at(0, 0)], FROM, :place)

    assert_equal FROM, motion.pose([:cell, at(0, 0)], TO).rect
    assert motion.flying?([:cell, at(0, 0)])
    motion.update(Motion::PLACE / 2)
    middle = motion.pose([:cell, at(0, 0)], TO).rect

    assert_operator middle.center_x, :>, FROM.center_x
    assert_operator middle.center_y, :<, (FROM.center_y + TO.center_y) / 2, "it arcs upward"
    motion.update(Motion::PLACE + (Motion::LAND / 2))

    refute motion.flying?([:cell, at(0, 0)])
    assert_equal TO, motion.pose([:cell, at(0, 0)], TO).rect
    assert_operator motion.pose([:cell, at(0, 0)], TO).squash, :<, 1.0, "and squashes as it lands"
  end

  def test_staggered_flights_wait_where_they_were
    motion = motion()
    motion.fly([:slot, 3], FROM, :return, delay: 0.09)
    motion.update(0.05)

    assert_equal FROM, motion.pose([:slot, 3], TO).rect
  end

  def test_calm_motion_fades_in_place_instead_of_flying
    motion = motion(calm: true)
    motion.fly([:cell, at(0, 0)], FROM, :place)
    motion.update(Motion::FADE / 2)
    pose = motion.pose([:cell, at(0, 0)], TO)

    assert_equal TO, pose.rect
    assert_in_delta 0.5, pose.alpha, 0.01
  end

  def test_a_picked_up_tile_rises_bobs_and_comes_back_down
    motion = motion()
    motion.selected(4)

    assert_in_delta 0.0, motion.lift(4)
    motion.update(Motion::LIFT)

    assert_in_delta 1.0, motion.lift(4), 0.15
    motion.update(2.0)

    assert_in_delta 1.0, motion.lift(4), 0.13
    motion.lowered(4)
    motion.update(2.0 + Motion::LIFT)

    assert_in_delta 0.0, motion.lift(4)
  end

  def test_picking_up_another_tile_lowers_the_first
    motion = motion()
    motion.selected(1)
    motion.update(1)
    motion.selected(2, 1)
    motion.update(1 + Motion::LIFT)

    assert_in_delta 0.0, motion.lift(1)
  end

  def test_the_check_sweeps_left_to_right_and_shakes_problems_as_it_passes
    motion = motion()
    bounds = Bounds.new(left: 0, top: 0, right: 3, bottom: 0)
    motion.checked(bounds, [at(3, 0)])
    motion.update(Motion::SWEEP * 0.3)

    assert motion.checked?(at(0, 0))
    refute motion.checked?(at(3, 0))
    assert_in_delta 0.3, motion.sweep, 0.01
    motion.update(Motion::SWEEP + 0.05)

    assert motion.checked?(at(3, 0))
    refute_equal 0.0, motion.shake(at(3, 0))
    assert_equal 0.0, motion.shake(at(0, 0))
  end

  def test_a_win_flips_tiles_in_a_wave_from_the_top_left_then_shows_results
    motion = motion()
    motion.won(Bounds.new(left: 0, top: 0, right: 4, bottom: 4))
    motion.update(Motion::SWEEP + (Motion::FLIP / 2))

    assert_operator motion.finish(at(0, 0)), :>, motion.finish(at(4, 4))
    assert_equal 0.0, motion.results
    motion.update(5)

    assert_equal 1.0, motion.finish(at(4, 4))
    assert_equal 1.0, motion.results
  end

  def test_the_camera_eases_to_its_new_view_and_rests
    view = BoardView.fit(viewport: rect(0, 0, 400, 400), content: BoardView.content_of(Board.empty), units: units)
    moved = view.with(x: view.x + 100)
    motion = motion()
    motion.camera(view, moved)
    motion.update(Motion::CAMERA / 2)

    assert_operator motion.view.x, :>, view.x
    assert_operator motion.view.x, :<, moved.x
    motion.update(Motion::CAMERA)

    assert_nil motion.view
  end

  def test_confetti_only_after_a_win_and_never_calm
    lost = motion()
    lost.lost
    lost.update(5)

    assert_nil lost.confetti(rect(0, 0, 100, 100), units: units, colors: 5)
    won = motion()
    won.won(Bounds.new(left: 0, top: 0, right: 2, bottom: 2))
    won.update(2)
    confetti, elapsed = won.confetti(rect(0, 0, 100, 100), units: units, colors: 5)

    refute_empty confetti.at(elapsed)
  end
end
