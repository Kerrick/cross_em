# frozen_string_literal: true

require "presentation_helper"

class FocusRingTest < Minitest::Test
  include PresentationTest

  def target(id, region, x, y, width = 40, height = 40, shown: true) = Target.new(id:, region:, rect: rect(x, y, width, height), shown:)

  # A header row, a pool of two rows of three, and a row of buttons:
  #
  #   [h1]          [h2]
  #   [p0][p1][p2]
  #   [p3][p4][p5]
  #   [ b1 ][ b2 ]
  def screen(pool: (0..5))
    [target(:h1, :header, 0, 0), target(:h2, :header, 200, 0),
     *pool.map { target([:slot, it], :pool, (it % 3) * 50, 60 + ((it / 3) * 50)) },
     target(:b1, :controls, 0, 170, 70), target(:b2, :controls, 80, 170, 70)]
  end

  def test_starts_on_the_default_and_is_hidden_until_shown
    ring = FocusRing.new

    refute_predicate ring, :visible?
    assert_equal [:slot, 0], ring.current(screen, default: [[:slot, 0]]).id
    ring.show

    assert_predicate ring, :visible?
    ring.hide

    refute_predicate ring, :visible?
  end

  def test_moves_within_a_region_then_runs_off_its_edge_into_the_next
    ring = FocusRing.new
    targets = screen
    ring.current(targets, default: [[:slot, 1]])

    assert_equal [:slot, 4], ring.move(targets, :down).id
    assert_equal :b1, ring.move(targets, :down).id, "off the pool's bottom, into the button more under it"
    assert_equal :b2, ring.move(targets, :right).id
    assert_nil ring.move(targets, :down), "nothing below: it stays"
    assert_equal :b2, ring.id
    assert_equal [:slot, 5], ring.move(targets, :up).id
    ring.move(targets, :up)

    assert_equal :h1, ring.move(targets, :up).id, "neither is in line; h1 and h2 are as near, h1 first"
  end

  def test_a_pinned_neighbour_wins
    ring = FocusRing.new
    targets = screen
    ring.current(targets, default: [:b1])

    assert_equal :h2, ring.move(targets, :up, pins: {[:b1, :up] => :h2}).id
  end

  def test_runs_off_an_edge_only_to_targets_in_sight
    ring = FocusRing.new
    targets = [target(:a, :pool, 0, 100), target(:far, :board, 0, 0, shown: false), target(:near, :board, 300, 0)]
    ring.current(targets, default: [:a])

    assert_equal :near, ring.move(targets, :up).id
    assert_equal :far, ring.move(targets, :left).id, "within its own region, a target out of sight is fine"
  end

  def test_hops_between_regions_and_remembers_each
    ring = FocusRing.new
    targets = screen
    ring.current(targets, default: [[:slot, 0]])
    ring.move(targets, :right)
    ring.move(targets, :down)

    assert_equal [:slot, 4], ring.id
    assert_equal :b1, ring.hop(targets, 1).id, "the buttons' first, never focused before"
    ring.move(targets, :right)

    assert_equal :h1, ring.hop(targets, 1).id, "wraps round to the header"
    assert_equal :b2, ring.hop(targets, -1).id, "the buttons, where it was left"
    assert_equal [:slot, 4], ring.hop(targets, -1).id, "the pool, where it was left"
  end

  def test_a_region_jumped_to_for_the_first_time_can_name_its_first
    ring = FocusRing.new
    targets = screen
    ring.current(targets, default: [:h2])

    assert_equal [:slot, 2], ring.hop(targets, 1, firsts: {pool: [:slot, 2]}).id
  end

  def test_a_focus_that_goes_away_is_replaced_by_the_nearest_in_its_region
    ring = FocusRing.new
    ring.current(screen, default: [[:slot, 4]])

    assert_equal [:slot, 3], ring.current(screen(pool: [0, 2, 3, 5])).id, "4 went to the board; 3 and 5 are as near"
    assert_equal [:slot, 3], ring.id
  end

  def test_the_focus_survives_a_rotation_by_its_id
    ring = FocusRing.new
    ring.current(screen, default: [[:slot, 4]])
    rotated = screen.map { it.with(rect: rect(it.rect.y + 500, it.rect.x, 40, 40)) }

    assert_equal [:slot, 4], ring.current(rotated).id
    assert_equal 500 + 110, ring.current(rotated).rect.x
  end

  def test_after_a_sheet_closes_the_focus_returns_to_where_it_was
    ring = FocusRing.new
    ring.current(screen, default: [:h2])
    sheet = [target([:sheet, :close], :help, 300, 0), target([:control, :calm], :help, 0, 300, 300)]

    assert_equal [:sheet, :close], ring.current(sheet, default: [[:sheet, :close]]).id
    ring.move(sheet, :down)

    assert_equal :h2, ring.current(screen).id
    assert_equal [:control, :calm], ring.current(sheet).id, "and opening it again finds where it was in the sheet"
  end
end
