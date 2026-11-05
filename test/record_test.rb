# frozen_string_literal: true

require "test_helper"

class RecordTest < Minitest::Test
  include CrossEmTest

  def saved(**changes)
    game = game(pool: "JRLKTKRWIAEM")
    game.tap_slot(0)
    game.tap_cell(Position::ORIGIN)
    game.to_record.to_h.merge(changes.transform_keys(&:to_s))
  end

  def test_a_saved_record_comes_back_as_it_was
    assert_equal saved, Record.from_h(saved).to_h
  end

  def test_a_record_under_another_days_number_is_refused
    assert_raises(Record::Invalid) { Record.from_h(saved(number: 1721)) }
  end

  def test_a_pool_of_the_wrong_size_is_refused
    assert_raises(Record::Invalid) { Record.from_h(saved(pool: [nil] + "RLKTKRWIAE".chars)) }
  end

  def test_letters_that_are_not_the_days_are_refused
    assert_raises(Record::Invalid) { Record.from_h(saved(pool: [nil] + "RLKTKRWIAEZ".chars)) }
    assert_raises(Record::Invalid) { Record.from_h(saved(board: [])) }
  end
end
