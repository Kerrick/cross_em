# frozen_string_literal: true

require "test_helper"

class ArchiveTest < Minitest::Test
  include CrossEmTest

  NOW = Time.utc(2026, 11, 5, 12)

  def played_record
    game = game(pool: "JRLKTKRWIAEM")
    game.tap_slot(0)
    game.tap_cell(Position::ORIGIN)
    game.to_record
  end

  def test_a_damaged_file_is_kept_aside_and_saving_goes_on
    storage = Archive::Memory.new(Archive::FILE => "{not json")
    archive = Archive.open(storage, now: NOW)

    assert_equal "{not json", storage.read("records-unreadable-#{NOW.to_i}.json")
    assert_equal 0, archive.size
    archive.save(played_record)

    assert_equal 1, Archive.new(storage).size, "the session's games are saved"
  end

  def test_a_record_that_is_not_its_days_counts_as_damage
    storage = Archive::Memory.new(Archive::FILE => Archive.text_of([played_record]).sub('"J"', '"Z"'))
    warnings = []

    assert_equal 0, Archive.open(storage, now: NOW, warn: ->(message) { warnings << message }).size
    assert_equal 1, warnings.size
  end

  def test_a_fresh_file_names_its_format
    assert_equal Archive::FORMAT, JSON.parse(Archive.empty_text).fetch("format")
  end
end
