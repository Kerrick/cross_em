# frozen_string_literal: true

require "test_helper"

class RefereeTest < Minitest::Test
  include CrossEmTest

  def test_a_two_letter_crossing_word_is_too_short
    check = referee.check(board("CAT", ".Z."))

    assert_equal({at(1, 0) => :too_short, at(1, 1) => :too_short}, check.problems)
    assert_equal 2, check.count
  end

  def test_letters_apart_from_the_first_group_are_disconnected
    check = referee.check(board("CAT.DOG"))

    assert_equal [at(4, 0), at(5, 0), at(6, 0)], check.problems.keys.sort
    assert_equal [:disconnected], check.problems.values.uniq
    assert_equal 3, check.count
  end

  def test_the_first_group_in_reading_order_is_kept_even_if_smaller
    check = referee.check(board("DOG....", "....CATS"))

    assert_equal [at(4, 1), at(5, 1), at(6, 1), at(7, 1)], check.problems.keys.sort
    assert_equal 4, check.count
  end

  def test_a_word_not_in_the_list_is_not_a_word
    check = referee.check(board("CTA"))

    assert_equal [:not_a_word], check.problems.values.uniq
    assert_equal 3, check.count
  end

  def test_a_letter_alone_is_a_word_too_short
    assert_equal({at(0, 0) => :too_short}, referee.check(board("A")).problems)
  end

  def test_the_kept_group_starts_at_the_first_letter_not_already_marked
    # "XQ" is too short, so the group kept starts at C, and X and Q are
    # not marked a second time.
    check = referee.check(board("XQ..", "..CAT"))

    assert_equal({at(0, 0) => :too_short, at(1, 0) => :too_short}, check.problems)
  end

  def test_a_clean_board_has_no_problems
    assert_predicate referee.check(board("CATS", "A...", "T...")), :clean?
  end

  def test_matching_is_against_the_lowercase_word
    assert Dictionary.new(%w[cat]).include?("CAT")
    refute Dictionary.new(%w[Cat]).include?("CAT")
  end

  def problem_words(check) = check.words.map { [it.word.text, it.reason] }

  def test_the_check_names_the_words_that_are_problems_in_reading_order
    check = referee.check(board("CATS", "....", "DOG.", "....", "AZXOG"))

    assert_equal [["DOG", :disconnected], ["AZXOG", :not_a_word]], problem_words(check)
  end

  def test_a_good_word_crossed_by_a_bad_one_is_not_named
    check = referee.check(board("CAT", "AZ."))

    assert_equal [["CA", :too_short], ["AZ", :too_short], ["AZ", :too_short]], problem_words(check), "AZ down and across"
    refute_includes problem_words(check).map(&:first), "CAT"
  end

  def test_a_clean_board_names_no_words
    assert_empty referee.check(board("CATS")).words
  end
end
