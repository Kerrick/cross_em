# frozen_string_literal: true

require "test_helper"

class WordFitTest < Minitest::Test
  include CrossEmTest

  def fit(board, pool) = WordFit.new(board:, pool: pool(pool))

  # Each placement as [column, row, direction, the fresh letters' cells].
  def summary(placements)
    placements.map { [it.start.column, it.start.row, it.direction, it.fresh_positions.map { |p| [p.column, p.row] }] }
  end

  def test_an_empty_board_takes_a_word_across_from_the_origin
    placements = fit(Board.empty, "CRABXXXXXXXX").placements("crab")

    assert_equal [[0, 0, :across, [[0, 0], [1, 0], [2, 0], [3, 0]]]], summary(placements)
    refute_predicate placements.first, :crossing?
  end

  def test_a_word_crossing_a_placed_letter_uses_it_and_needs_only_the_rest
    # CRAB down through CAT's A; the pool has no A of its own.
    placements = fit(board("CAT"), "RBCXXXXXX...").placements("CRAB")

    assert_equal [[1, -2, :down, [[1, -1], [1, -2], [1, 1]]]], summary(placements)
    assert placements.all?(&:crossing?)
  end

  def test_crossings_come_first_and_in_reading_order_across_before_down
    # CAT across; the word TA could go down through T, or across beside.
    placements = fit(board("CAT"), "AAXXXXXXX...").placements("TA")

    assert_equal [[2, 0, :down, [[2, 1]]]], summary(placements)
  end

  def test_with_nothing_to_cross_the_words_beside_the_letters_are_offered
    placements = fit(board("CAT"), "DOGXXXXXX...").placements("DOG")
    starts = summary(placements).map { it.first(3) }

    refute placements.any?(&:crossing?)
    assert_includes starts, [0, 1, :across], "under CAT"
    assert_includes starts, [0, -1, :across], "over CAT"
    assert_equal starts, starts.sort_by { |column, row, direction| [row, column, direction == :across ? 0 : 1] }
  end

  def test_a_word_never_runs_on_into_a_letter_at_either_end
    # DOG straight after CAT would read CATDOG.
    placements = fit(board("CAT"), "DOGXXXXXX...").placements("DOG")

    refute_includes summary(placements).map { it.first(3) }, [3, 0, :across]
    refute_includes summary(placements).map { it.first(3) }, [-3, 0, :across]
  end

  def test_extending_a_word_places_only_the_new_letter
    placements = fit(board("CAT"), "SXXXXXXXX...").placements("CATS")

    assert_equal [[0, 0, :across, [[3, 0]]]], summary(placements)
  end

  def test_a_word_inside_a_longer_run_does_not_fit_there
    # CAT inside CATS: the S after it would make the run CATS, not CAT.
    placements = fit(board("CATS"), "CATXXXXXX...").placements("CAT")

    refute(placements.any? { it.start.row.zero? && it.direction == :across })
  end

  def test_a_word_already_on_the_board_adds_nothing
    placements = fit(board("CAT"), "XXXXXXXXX...").placements("CAT")

    assert_empty placements
    assert_equal :on_board, fit(board("CAT"), "XXXXXXXXX...").misfit("CAT").reason
  end

  def test_a_word_can_use_only_some_of_the_letters_on_its_way
    # Down through the A of CAT, with the rest from the pool: BAD.
    placements = fit(board("CAT"), "BDXXXXXXX...").placements("BAD")

    assert_equal [[1, -1, :down, [[1, -1], [1, 1]]]], summary(placements)
  end

  def test_a_word_crosses_only_where_the_board_has_the_same_letter
    # DOT can only end on CAT's T.
    placements = fit(board("CAT"), "DOGXXXXXX...").placements("DOT")

    assert_equal [[2, -2, :down, [[2, -1], [2, -2]]]], summary(placements)
  end

  def test_the_pool_is_counted_letter_by_letter
    two_es = fit(Board.empty, "EXXXXXXXXXXX")

    assert_empty two_es.placements("EE")
    assert_equal 1, fit(Board.empty, "EEXXXXXXXXXX").placements("EE").size
  end

  def test_only_the_letters_past_what_the_pool_and_board_hold_are_short
    # 1719's pool: one E and one C.
    word_fit = fit(Board.empty, "HPWLKNDHACEB")

    assert_equal [3, 5], word_fit.short("CHECKED"), "the second C and the second E"
    assert_empty word_fit.short("BACKED")
  end

  def test_letters_on_the_board_count_towards_what_can_be_had
    word_fit = fit(board("CAT"), "EXXXXXXXX...")

    assert_empty word_fit.short("TACE"), "the T, A and C are on the board"
    assert_equal [3], word_fit.short("CATT"), "but there is only one T"
  end

  def test_a_letter_in_neither_is_short_everywhere_it_appears
    assert_equal [0, 2], fit(board("CAT"), "AXXXXXXXX...").short("QAQ")
  end

  def test_letters_missing_from_pool_and_board_are_named
    misfit = fit(board("CAT"), "RXXXXXXXX...").misfit("CRAB")

    assert_equal :missing, misfit.reason
    assert_equal %w[B], misfit.letters
  end

  def test_a_word_whose_letters_are_there_but_fit_nowhere_says_so
    # ACT could only borrow CAT's C or T, and the pool has no T or C.
    word_fit = fit(board("CAT"), "AXXXXXXXX...")

    assert_empty word_fit.placements("ACT")
    assert_equal :nowhere, word_fit.misfit("ACT").reason
  end

  def test_fresh_letters_come_in_an_order_the_rules_accept
    # Down through the middle of CAT: the letter above the A first, then
    # the one above that, each beside a letter already down.
    placement = fit(board("CAT"), "XYXXXXXXX...").placements("YXA").first

    assert_equal [[1, -1], [1, -2]], placement.fresh_positions.map { [it.column, it.row] }
    game = game(pool: "XY..........", board: board("CAT"))
    placement.fresh.each do |position, letter|
      game.tap_slot(game.pool.slots.index(letter))
      game.tap_cell(position)
    end

    assert_equal "YXA", game.board.words.find { it.direction == :down }.text
  end

  def test_the_search_never_consults_the_word_list
    # QZX is no word, and fits all the same.
    refute_empty fit(Board.empty, "QZXXXXXXXXXX").placements("QZX")
  end

  def test_a_single_letter_is_offered_once_per_cell
    placements = fit(board("A"), "SXXXXXXXXXX.").placements("S")

    assert_equal placements.map { it.positions.sort }.uniq.size, placements.size
    assert_equal 4, placements.size
  end

  def test_lower_case_is_read_as_capitals_and_nothing_typed_fits_nowhere
    assert_equal 1, fit(Board.empty, "CRABXXXXXXXX").placements("crab").size
    assert_empty fit(Board.empty, "CRABXXXXXXXX").placements("")
    assert_equal :empty, fit(Board.empty, "CRABXXXXXXXX").misfit("").reason
  end
end
