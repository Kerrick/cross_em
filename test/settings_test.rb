# frozen_string_literal: true

require "presentation_helper"

class SettingsTest < Minitest::Test
  include PresentationTest

  def test_settings_round_trip_through_json
    settings = Settings.new(instructions_seen: true, muted: true, appearance: :dark, calm: true)

    assert_equal settings, Settings.parse(settings.to_json)
  end

  def test_a_missing_or_damaged_file_gives_the_defaults
    assert_equal Settings.default, Settings.parse(nil)
    assert_equal Settings.default, Settings.parse("{not json")
    assert_equal Settings.default, Settings.parse("[1, 2]")
    assert_equal :system, Settings.parse('{"appearance": "purple"}').appearance
  end

  def test_the_appearance_follows_the_system_unless_chosen
    assert Appearance.dark?(:system, :dark)
    refute Appearance.dark?(:system, :unknown)
    assert Appearance.dark?(:dark, :light)
    refute Appearance.dark?(:light, :dark)
    assert_equal %i[light dark system], Appearance::CHOICES.map { Appearance.next(it) }
  end

  def test_a_pretend_clock_keeps_the_time_of_day
    real = Time.utc(2026, 11, 5, 14, 30, 5)
    clock = Clock.pretending(Date.new(2026, 1, 2), real)

    assert_equal Time.utc(2026, 1, 2, 14, 30, 5), clock.now(real)
    assert_equal Day.new(date: Date.new(2026, 1, 2)), clock.today(real)
  end

  def test_a_clock_can_start_at_a_moment_and_run_on
    real = Time.utc(2026, 11, 5, 14, 0, 0)
    clock = Clock.starting_at(Time.utc(2026, 11, 7, 23, 59, 58), real)

    assert_equal Time.utc(2026, 11, 8, 0, 0, 1), clock.now(real + 3)
  end
end
