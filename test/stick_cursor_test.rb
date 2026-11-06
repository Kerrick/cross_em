# frozen_string_literal: true

require "presentation_helper"

class StickCursorTest < Minitest::Test
  include PresentationTest

  FRAME = 1.0 / 60

  def setup
    @bounds = rect(0, 0, 1000, 1000)
    @targets = [Target.new(id: :a, region: :pool, rect: rect(100, 100, 50, 50)),
                Target.new(id: :b, region: :pool, rect: rect(400, 100, 50, 50))]
  end

  def run_for(cursor, seconds, sx, sy)
    events = []
    (seconds / FRAME).round.times { events << cursor.update(FRAME, sx, sy, @targets, @bounds) }
    events.compact
  end

  def test_inside_the_dead_zone_the_stick_is_let_go
    assert_equal [0.0, 0.0], StickCursor.shaped(0.15, -0.1)
    assert_equal [0.0, 0.0], StickCursor.shaped(0.2, 0.0)
    x, y = StickCursor.shaped(0.6, 0.0)

    assert_in_delta 0.5, x
    assert_in_delta 0.0, y
    assert_in_delta 1.0, Math.hypot(*StickCursor.shaped(0.8, 0.8)), 1e-9, "the edge clamps at full speed"
  end

  def test_a_resting_stick_never_moves_it_or_shows_it
    cursor = StickCursor.new(speed: 1000)
    cursor.place(500, 500)

    assert_empty run_for(cursor, 1.0, 0.1, -0.15)
    assert_equal [500.0, 500.0], [cursor.x, cursor.y]
    refute_predicate cursor, :visible?
  end

  def test_speed_grows_with_the_square_of_the_tilt
    full, half = StickCursor.new(speed: 1000), StickCursor.new(speed: 1000)
    [full, half].each { it.place(500, 500) }
    full.update(0.1, 0.0, 1.0, [], @bounds)
    half.update(0.1, 0.0, 0.6, [], @bounds)

    assert_in_delta 100.0, full.y - 500
    assert_in_delta 25.0, half.y - 500, 1e-9, "half the travel past the dead zone, a quarter of the speed"
  end

  def test_it_slows_over_a_target
    cursor = StickCursor.new(speed: 1000)
    cursor.place(110, 120)
    cursor.update(0.01, 1.0, 0.0, @targets, @bounds)

    assert_in_delta 110 + (10 * StickCursor::FRICTION), cursor.x
  end

  def test_moving_over_a_target_focuses_it_and_letting_go_settles_on_the_nearest
    cursor = StickCursor.new(speed: 1000)
    cursor.place(0, 125)
    events = run_for(cursor, 0.2, 1.0, 0.0)

    assert_equal [:over, :a], events.first.then { [it[0], it[1].id] }, "it passes over a"
    run_for(cursor, 0.15, 1.0, 0.0)

    assert_operator cursor.x, :>, 150, "and on past it"
    assert_operator cursor.x, :<, 400
    event = cursor.update(FRAME, 0.0, 0.0, @targets, @bounds)
    nearest = cursor.x - 150 < 400 - cursor.x ? :a : :b

    assert_equal [:settle, nearest], [event[0], event[1].id]
    assert_predicate cursor, :visible?
    run_for(cursor, StickCursor::SETTLE + FRAME, 0.0, 0.0)
    target = @targets.find { it.id == nearest }.rect

    assert_in_delta target.center_x, cursor.x, 1e-6, "it glides to the target's middle"
    assert_in_delta target.center_y, cursor.y, 1e-6
    run_for(cursor, StickCursor::LINGER + 0.1, 0.0, 0.0)

    refute_predicate cursor, :visible?, "and fades once settled"
  end

  def test_let_go_far_from_everything_it_still_settles_on_the_nearest
    cursor = StickCursor.new(speed: 1000)
    cursor.place(900, 900)
    run_for(cursor, 0.05, 0.0, 1.0)
    event = cursor.update(FRAME, 0.0, 0.0, @targets, @bounds)

    assert_equal :b, event.last.id
  end

  def test_it_stays_inside_the_bounds
    cursor = StickCursor.new(speed: 1000)
    cursor.place(10, 10)
    run_for(cursor, 1.0, -1.0, -1.0)

    assert_equal [0.0, 0.0], [cursor.x, cursor.y]
    run_for(cursor, 3.0, 1.0, 1.0)

    assert_equal [999.0, 999.0], [cursor.x, cursor.y]
  end
end
