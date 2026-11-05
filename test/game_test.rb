# frozen_string_literal: true

require "test_helper"

class GameTest < Minitest::Test
  include CrossEmTest

  def test_a_new_game_holds_the_days_letters
    game = Game.start(Day.numbered(1720), referee:)

    assert_equal "JRLKTKRWIAEM".chars, game.pool.slots
    assert_predicate game.board, :empty?
    assert_predicate game, :playing?
  end

  def test_tapping_a_letter_selects_it_and_tapping_it_again_deselects_it
    game = game()

    assert_equal Events::Selected.new(index: 3), game.tap_slot(3)
    assert_equal 3, game.selected
    assert_equal Events::Deselected.new(index: 3), game.tap_slot(3)
    assert_nil game.selected
  end

  def test_tapping_another_letter_moves_the_selection
    game = game()
    game.tap_slot(3)
    game.tap_slot(5)

    assert_equal 5, game.selected
  end

  def test_tapping_an_empty_slot_does_nothing
    game = game(pool: ".ATSDOGTAGCA")
    game.tap_slot(1)

    assert_nil game.tap_slot(0)
    assert_equal 1, game.selected
  end

  def test_placing_moves_the_selected_letter_to_a_target
    game = game()
    game.tap_slot(2)
    event = game.tap_cell(Position::ORIGIN)

    assert_equal Events::Placed.new(letter: "T", index: 2, position: Position::ORIGIN), event
    assert_equal "T", game.board[Position::ORIGIN]
    assert_nil game.pool[2]
    assert_nil game.selected
  end

  def test_with_a_letter_selected_a_non_target_or_a_placed_letter_does_nothing
    game = game(pool: "C..SDOGTAGCA", board: board("AT"))
    game.tap_slot(0)

    assert_nil game.tap_cell(at(5, 5))
    assert_nil game.tap_cell(at(0, 0))
    assert_equal 0, game.selected
    assert_equal board("AT"), game.board
  end

  def test_a_returned_letter_goes_to_the_first_empty_slot
    game = game()
    game.tap_slot(4)
    game.tap_cell(at(0, 0)) # D from slot 4
    game.tap_slot(1)
    game.tap_cell(at(1, 0)) # A from slot 1
    event = game.tap_cell(at(0, 0))

    assert_equal Events::Returned.new(letter: "D", position: at(0, 0), index: 1), event
    assert_equal "D", game.pool[1]
    assert_nil game.pool[4]
  end

  def test_tapping_an_empty_cell_with_nothing_selected_does_nothing
    assert_nil game(pool: "..TSDOGTAGCA", board: board("CA")).tap_cell(at(5, 0))
  end

  def test_shuffle_keeps_every_slot_and_the_selection
    game = game(pool: "C.TSDOGTAG.A")
    game.tap_slot(4)
    game.shuffle(random: Random.new(7))

    assert_equal "C.TSDOGTAG.A".chars.map { it == "." ? nil : it }.tally, game.pool.slots.tally
    assert_equal "D", game.pool[game.selected]
  end

  def test_reset_returns_letters_in_reading_order_to_the_first_empty_slots
    game = game(pool: "..........XY", board: board(".B", "CA", "D.", "..", "..", "..", "..", "..", "..", "..", "E"))
    event = game.reset

    assert_equal %w[B C A D E], event.returns.map(&:letter)
    assert_equal %w[B C A D E] + [nil] * 5 + %w[X Y], game.pool.slots
    assert_predicate game.board, :empty?
  end

  def test_no_check_runs_while_letters_wait_in_the_pool
    game = game(pool: "C...........", board: board("XQ"))

    assert_nil game.check
  end

  def test_placing_the_last_letter_checks_and_shows_problems_without_ending
    game = game(pool: "Z...........", board: board("CAT"))
    game.tap_slot(0)
    events = events_of(game)
    game.tap_cell(at(1, 1))

    assert_equal [Events::Placed, Events::Checked], events.map(&:class)
    assert_equal 2, game.check.count
    assert_predicate game, :playing?
  end

  def test_any_move_clears_the_checks_marks
    game = game(pool: "............", board: board("CAT", ".Z."))
    game.tap_cell(at(1, 1))

    assert_nil game.check
  end

  def test_placing_every_letter_cleanly_wins
    game = game(pool: "WORDSMITHING")
    events = events_of(game)
    12.times do |index|
      game.tap_slot(index)
      game.tap_cell(at(index, 0))
    end

    assert_predicate game, :won?
    assert_equal [Events::Checked, Events::Won], events.last(2).map(&:class)
    assert_equal 12, game.good_letters
  end

  def test_giving_up_with_a_clean_full_board_is_a_win
    game = game(pool: "." * 12, board: board("WORDSMITHING"))

    assert_equal Events::Won, game.give_up.class
    assert_predicate game, :won?
  end

  def test_giving_up_otherwise_is_a_loss_with_problems_marked
    game = game(pool: "....DOGTAGCA", board: board("CAT", ".Z."))

    assert_equal Events::Lost, game.give_up.class
    assert_predicate game, :lost?
    assert_equal 2, game.check.count
    assert_equal 8, game.pool.unused_count
    assert_equal 2, game.good_letters
  end

  def test_a_finished_game_cannot_change
    game = game(pool: "....DOGTAGCA", board: board("CAT", ".Z."))
    game.give_up
    before = [game.pool, game.board]

    assert_nil game.tap_slot(4)
    assert_nil game.tap_cell(at(0, 0))
    assert_nil game.shuffle
    assert_nil game.reset
    assert_nil game.give_up
    assert_equal before, [game.pool, game.board]
  end

  def test_placing_a_letter_at_once_is_a_tap_on_its_slot_then_its_target
    game = game()
    events = events_of(game)

    assert_equal Events::Placed.new(letter: "A", index: 1, position: Position::ORIGIN), game.place_letter(1, Position::ORIGIN)
    assert_equal [Events::Placed.new(letter: "A", index: 1, position: Position::ORIGIN)], events
    assert_nil game.selected
  end

  def test_placing_a_letter_at_once_puts_down_one_selected_first
    game = game()
    game.tap_slot(4)
    events = events_of(game)
    game.place_letter(1, Position::ORIGIN)

    assert_equal [Events::Deselected, Events::Placed], events.map(&:class)
  end

  def test_placing_a_letter_at_once_off_target_or_from_an_empty_slot_does_nothing
    game = game(pool: ".ATSDOGTAGCA")

    assert_nil game.place_letter(0, Position::ORIGIN)
    assert_nil game.place_letter(1, at(3, 3))
    assert_predicate game.board, :empty?
  end

  def test_placing_the_last_letter_at_once_checks_and_can_win
    game = game(pool: "S...........", board: board("CAT"))
    events = events_of(game)
    game.place_letter(0, at(3, 0))

    assert_equal [Events::Placed, Events::Checked, Events::Won], events.map(&:class)
    assert_predicate game, :won?
  end
end
