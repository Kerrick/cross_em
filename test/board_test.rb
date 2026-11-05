# frozen_string_literal: true

require "test_helper"

class BoardTest < Minitest::Test
  include CrossEmTest

  def test_an_empty_board_has_one_target_at_the_origin
    assert_equal Set[Position::ORIGIN], Board.empty.targets
  end

  def test_every_empty_cell_beside_a_letter_is_a_target
    expected = Set[at(0, -1), at(1, -1), at(-1, 0), at(2, 0), at(0, 1), at(1, 1)]

    assert_equal expected, board("AB").targets
  end

  def test_a_split_grid_has_targets_around_each_group
    split = board("A..B")

    assert_equal Set[at(0, -1), at(-1, 0), at(1, 0), at(0, 1), at(3, -1), at(2, 0), at(4, 0), at(3, 1)],
      split.targets
  end

  def test_placing_off_target_is_refused
    assert_raises(ArgumentError) { board("A").place(at(5, 5), "B") }
  end

  def test_words_read_across_then_down_then_letters_alone
    words = board("CAT", ".Z.", "...", "Q..").words

    assert_equal %w[CAT AZ Q], words.map(&:text)
    assert_equal %i[across down alone], words.map(&:direction)
    assert_equal [at(1, 0), at(1, 1)], words[1].positions
  end

  def test_a_letter_can_be_in_one_word_across_and_one_down
    words = board("CAT", "A..", "T..").words

    assert_equal %w[CAT CAT], words.map(&:text)
    assert_equal [at(0, 0)], words.map { it.positions.first }.uniq
  end

  def test_runs_split_at_gaps
    assert_equal %w[CAT DOG], board("CAT.DOG").words.map(&:text)
  end

  def test_bounds_cover_every_letter
    bounds = board("A....", "....B").bounds

    assert_equal [5, 2], [bounds.width, bounds.height]
    assert_nil Board.empty.bounds
  end

  def test_a_group_is_every_letter_reachable_through_neighbors
    split = board("AB.C", ".D..")

    assert_equal Set[at(0, 0), at(1, 0), at(1, 1)], split.group_of(at(0, 0))
  end
end
