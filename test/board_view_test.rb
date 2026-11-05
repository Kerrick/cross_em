# frozen_string_literal: true

require "presentation_helper"

class BoardViewTest < Minitest::Test
  include PresentationTest

  VIEWPORT = Rect.new(x: 0, y: 100, width: 400, height: 500)

  def fit(board, viewport: VIEWPORT, scale: 1, **)
    BoardView.fit(viewport:, content: BoardView.content_of(board), units: units(scale), **)
  end

  def test_an_empty_board_frames_the_origin_and_its_ring_at_the_largest_cells
    view = fit(Board.empty)

    assert_equal 72, view.cell
    assert_equal Bounds.new(left: -1, top: -1, right: 1, bottom: 1), view.content
    origin = view.rect_of(Position::ORIGIN)

    assert_in_delta VIEWPORT.center_x, origin.center_x, 1
    assert_in_delta VIEWPORT.center_y, origin.center_y, 1
  end

  def test_cells_shrink_to_fit_but_never_below_the_smallest
    assert_equal 62, fit(board("CATS")).cell, "6 columns in 376 pixels"
    assert_equal 44, fit(board("CATSDOGTAGCATS")).cell
  end

  def test_cells_follow_the_screens_density
    assert_equal 144, fit(Board.empty, viewport: rect(0, 0, 1600, 1200), scale: 2).cell
  end

  def test_a_board_that_fits_is_centred_and_does_not_pan
    view = fit(board("CAT"))

    refute_predicate view, :pannable?
    assert_equal view, view.pan(50, -50)
  end

  def test_a_wide_board_pans_only_as_far_as_its_edges
    view = fit(board("CATSDOGTAGCATS")) # 16 columns of 44 = 704 pixels in 400

    assert_predicate view, :pannable?
    far_right = view.pan(-10_000, 0)
    far_left = view.pan(10_000, 0)

    assert_equal VIEWPORT.right - 12, far_right.rect_of(at(14, 0)).right
    assert_equal VIEWPORT.x + 12, far_left.rect_of(at(-1, 0)).x
    assert_equal view.y, far_right.pan(0, 300).y, "the rows fit, so it does not pan up and down"
  end

  def test_screen_points_map_to_cells_and_back
    view = fit(board("CAT", ".O.", ".G."))

    [at(0, 0), at(2, 2), at(-1, 3), at(3, -1)].each do |position|
      rect = view.rect_of(position)

      assert_equal position, view.cell_at(rect.x, rect.y)
      assert_equal position, view.cell_at(rect.right - 1, rect.bottom - 1)
    end
    assert_nil view.cell_at(VIEWPORT.x - 1, VIEWPORT.y + 10), "outside the viewport"
  end

  def test_cells_tile_without_gaps_even_between_two_views
    a = fit(Board.empty)
    b = fit(board("CATSDOGTAGCATS"))
    halfway = a.toward(b, 0.37)

    (-2..5).each do |column|
      assert_equal halfway.rect_of(at(column, 0)).right, halfway.rect_of(at(column + 1, 0)).x
    end
  end

  def test_a_focus_is_brought_into_view
    view = fit(board("CATSDOGTAGCATS"), focus: at(14, 0))

    assert_operator view.rect_of(at(14, 0)).right, :<=, VIEWPORT.right - 12
    assert view.visible?(at(14, 0))
  end

  def test_a_previous_pannable_view_keeps_its_place
    before = fit(board("CATSDOGTAGCATS")).pan(-100, 0)
    after = fit(board("CATSDOGTAGCATSX"), previous: before)

    assert_equal before.x, after.x
  end

  def test_every_cell_of_the_content_can_be_reached_by_panning
    view = fit(board("CATSDOGTAGCATS", *Array.new(14) { "C" }))

    [at(-1, -1), at(14, 15), at(-1, 15), at(14, -1)].each do |corner|
      assert view.reveal(corner).clamped.visible?(corner), "#{corner} reachable"
    end
  end
end
