# frozen_string_literal: true

require "presentation_helper"

class CopyTest < Minitest::Test
  include PresentationTest

  def status(game) = Copy.status(game, dictionary)

  def test_the_status_says_what_to_do_next
    game = game()

    assert_equal Copy::PICK, status(game).text
    game.tap_slot(0)

    assert_equal Copy::PLACE, status(game).text
    game.tap_cell(Position::ORIGIN)

    assert_equal Copy::PICK, status(game).text
    assert_equal "11 letters left. Tap a placed one to send it back.", status(game).detail
  end

  def test_problems_are_counted_and_explained_in_reading_order
    game = game(pool: "............", board: board("CATS", "....", "DOG.", "....", "AZXOG"))
    status = status(game)

    assert_equal :problem, status.tone
    assert_equal "8 letters need fixing. Tap one to send it back.", status.text
    assert_equal ["DOG isn't connected", "AZXOG isn't in the word list"], status.reasons
  end

  def test_short_and_lonely_words_have_their_own_reasons
    check = Check.new(problems: {at(0, 0) => :too_short, at(1, 0) => :too_short, at(5, 5) => :too_short})
    reasons = Copy.reasons(board("AZ"), check, dictionary)

    assert_equal ["AZ is too short"], reasons
    assert_equal ["Q is on its own"], Copy.reasons(Board.new(cells: {at(5, 5) => "Q"}), check, dictionary)
  end

  def test_a_word_marked_only_by_a_word_crossing_it_is_not_blamed
    board = board("CAT", "AZ.")
    check = Referee.new(dictionary).check(board)

    refute_includes Copy.reasons(board, check, dictionary), "CAT isn't connected"
  end

  def test_one_problem_is_one_letter
    game = game(pool: "............", board: board("CAT", "...", "...Z"))

    assert_equal "1 letter needs fixing. Tap one to send it back.", status(game).text
    assert_equal ["Z is on its own"], status(game).reasons
  end

  def test_the_end_says_what_was_good
    won = game(pool: "............", board: board("CAT"), status: :won)
    lost = game(pool: "Z...........", board: board("CAT"), status: :lost)

    assert_equal ["Solved!", "All 12 letters crossed."], [status(won).text, status(won).detail]
    assert_equal ["Game over", "3 of 12 letters crossed."], [status(lost).text, status(lost).detail]
  end

  def test_the_instructions_carry_the_word_list_credit_exactly
    credit = "Word list based on SCOWL by Kevin Atkinson and the sources it credits, including ENABLE and the " \
             "UK Advanced Cryptics Dictionary, Copyright (c) J Ross Beresford 1993-1999. All Rights Reserved."
    texts = Copy.instructions(touch: true).map(&:text)

    assert_includes texts, credit
  end

  def test_the_credits_show_the_shipped_files_unmodified
    read = ->(path) { File.read(File.expand_path("../#{path}", __dir__)) }
    licenses = Copy.credits(read).select { it.kind == :license }.map(&:text)

    assert_equal read.("wordlist-COPYRIGHT.txt"), licenses.first
    assert_equal 3, licenses.size
  end
end
