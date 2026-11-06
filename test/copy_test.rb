# frozen_string_literal: true

require "presentation_helper"

class CopyTest < Minitest::Test
  include PresentationTest

  def test_problems_are_explained_briefly_in_reading_order
    check = referee.check(board("CATS", "....", "DOG.", "....", "AZXOG"))

    assert_equal ["DOG: not joined", "AZXOG: not a word"], Copy.reasons(check)
  end

  def test_short_and_lonely_words_have_their_own_reasons
    assert_equal ["AZ: too short"], Copy.reasons(referee.check(board("AZ")))
    assert_equal ["Q: alone"], Copy.reasons(referee.check(Board.new(cells: {at(5, 5) => "Q"})))
  end

  def test_a_word_marked_only_by_a_word_crossing_it_is_not_blamed
    assert_equal ["CA: too short", "AZ: too short"], Copy.reasons(referee.check(board("CAT", "AZ.")))
  end

  def test_the_end_has_a_heading_and_a_count_of_good_letters
    won = game(pool: "............", board: board("CAT"), status: :won)
    lost = game(pool: "Z...........", board: board("CAT"), status: :lost)

    assert_equal [Copy::WON, Copy::LOST], [Copy.heading(won), Copy.heading(lost)]
    assert_equal "3/12", Copy.tally(lost.good_letters)
  end

  def test_a_misfit_says_a_few_words_only_when_the_marks_cant
    misfit = ->(reason) { Copy.misfit(WordFit::Misfit.new(word: "CAT", reason:, letters: [])) }

    assert_nil misfit.(:missing), "the draft's marks show a missing letter"
    assert_equal "Already there", misfit.(:on_board)
    assert_equal "No room", misfit.(:nowhere)
  end

  def test_how_to_play_uses_the_devices_verb
    touch = Copy.instructions(touch: true).map(&:text).compact.join(" ")
    mouse = Copy.instructions(touch: false).map(&:text).compact.join(" ")

    assert_includes touch, "Tap a placed letter"
    assert_includes mouse, "Click a placed letter"
    refute_match(/\bTap\b/, mouse)
  end

  def test_the_credits_open_with_the_game_then_the_word_list_credit_exactly_then_its_copyright_file
    credit = "Word list based on SCOWL by Kevin Atkinson and the sources it credits, including ENABLE and the " \
             "UK Advanced Cryptics Dictionary, Copyright (c) J Ross Beresford 1993-1999. All Rights Reserved."
    read = ->(path) { File.read(File.expand_path("../#{path}", __dir__)) }
    blocks = Copy.credits(read)

    assert_equal [:heading, "Cross ’em"], [blocks[0].kind, blocks[0].text]
    assert_includes blocks[1].text, "Kerrick Long"
    assert_includes blocks[1].text, "3.0 or later"
    assert_equal [:heading, "Word list"], [blocks[2].kind, blocks[2].text]
    assert_equal credit, blocks[3].text
    assert_equal [:license, read.("wordlist-COPYRIGHT.txt")], [blocks[4].kind, blocks[4].text]
    refute_includes Copy.instructions(touch: true).map(&:text), credit
  end

  def test_the_credits_show_the_shipped_files_unmodified
    read = ->(path) { File.read(File.expand_path("../#{path}", __dir__)) }
    licenses = Copy.credits(read).select { it.kind == :license }.map(&:text)

    assert_equal read.("wordlist-COPYRIGHT.txt"), licenses.first
    assert_equal 3, licenses.size
  end
end
