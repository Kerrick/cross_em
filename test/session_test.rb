# frozen_string_literal: true

require "test_helper"

class SessionTest < Minitest::Test
  include CrossEmTest

  def setup
    @storage = Archive::Memory.new
  end

  def session = Session.new(archive: Archive.new(@storage), referee:)

  def test_a_day_is_saved_after_every_place_and_restored_exactly
    game = session.open(Day.numbered(1720))
    game.tap_slot(3)
    game.tap_cell(Position::ORIGIN)
    game.tap_slot(7)
    game.tap_cell(at(1, 0))
    game.shuffle(random: Random.new(3))
    game.tap_slot(game.pool.slots.index("K")) # selection is not saved

    reopened = session.open(Day.numbered(1720))

    assert_equal game.pool, reopened.pool
    assert_equal game.board, reopened.board
    assert_predicate reopened, :playing?
    assert_nil reopened.selected
  end

  def test_a_shuffle_is_saved_once_the_day_has_a_record
    game = session.open(Day.numbered(1720))
    game.shuffle(random: Random.new(1))

    assert_nil @storage.read(Archive::FILE), "shuffling alone does not make a day played"

    game.tap_slot(game.pool.slots.index("J"))
    game.tap_cell(Position::ORIGIN)
    game.shuffle(random: Random.new(2))

    assert_equal game.pool, session.open(Day.numbered(1720)).pool
  end

  def test_shuffling_alone_saves_nothing
    session.open(Day.numbered(1720)).shuffle

    assert_nil @storage.read(Archive::FILE)
  end

  def test_a_loss_is_final_after_reopening
    game = session.open(Day.numbered(1720))
    game.tap_slot(0)
    game.tap_cell(Position::ORIGIN)
    game.give_up

    reopened = session.open(Day.numbered(1720))

    assert_predicate reopened, :lost?
    assert_nil reopened.tap_slot(1)
    assert_nil reopened.tap_cell(Position::ORIGIN)
    assert_equal 1, reopened.check.count
  end

  def test_the_saved_record_carries_the_originals_fields
    game = session.open(Day.numbered(1720))
    game.tap_slot(0)
    game.tap_cell(Position::ORIGIN)
    game.give_up
    saved = JSON.parse(@storage.read(Archive::FILE)).fetch("days").first

    assert_equal({"number" => 1720, "seed" => "2026-11-05", "won" => false, "finished" => true, "unused" => 11,
                  "pool" => [nil] + "RLKTKRWIAEM".chars,
                  "board" => [{"column" => 0, "row" => 0, "letter" => "J"}]}, saved)
  end

  def test_a_day_counts_as_played_once_anything_is_saved
    game = session.open(Day.numbered(1720))
    game.tap_slot(0)
    game.tap_cell(Position::ORIGIN)

    assert_equal 1, session.stats(Day.numbered(1720)).played
  end
end
