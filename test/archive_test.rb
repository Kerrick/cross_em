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

  # A storage whose records file is there but cannot be read.
  class Unreadable < CrossEm::Archive::Memory
    def written(name) = @files[name]
    def read(name) = name == CrossEm::Archive::FILE ? raise(CrossEm::Archive::Unreadable, name) : super
  end

  def test_records_that_cannot_be_read_are_never_written_over
    storage = Unreadable.new
    archive = Archive.open(storage, now: NOW)
    archive.save(played_record)

    assert_nil storage.written(Archive::FILE)
    assert_equal 1, archive.size, "the session still plays"
  end

  def test_a_save_is_written_aside_and_read_back_before_it_replaces_the_file
    storage = Archive::Memory.new
    Archive.new(storage).save(played_record)

    assert_equal storage.read(Archive::NEW), storage.read(Archive::FILE)
  end

  def test_a_save_cut_short_is_recovered_from_its_copy
    storage = Archive::Memory.new
    Archive.new(storage).save(played_record)
    storage.write(Archive::FILE, '{"format": 1, "da')

    assert_equal 1, Archive.open(storage, now: NOW).size
  end
end
