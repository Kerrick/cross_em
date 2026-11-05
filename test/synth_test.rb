# frozen_string_literal: true

require "test_helper"
require "cross_em/presentation/synth"

class SynthTest < Minitest::Test
  Synth = CrossEm::Presentation::Synth

  # Roughly how long each sound should last, in seconds.
  DURATIONS = {
    pick: 0.06, place: 0.09, return: 0.06, shuffle: 0.3, check: 0.4,
    problem: 0.15, win: 1.2, loss: 0.9, button: 0.03, copied: 0.25
  }.freeze

  def test_lists_every_sound = assert_equal DURATIONS.keys.sort, Synth::SOUNDS.sort

  def test_sample_rate = assert_equal 44_100, Synth::SAMPLE_RATE

  def test_every_sound_renders_samples_in_range
    Synth::SOUNDS.each do |name|
      samples = Synth.render(name)
      refute_empty samples, name
      assert samples.all?(Float), name
      assert samples.all? { it.between?(-1.0, 1.0) }, name
    end
  end

  def test_every_sound_peaks_near_point_nine
    Synth::SOUNDS.each do |name|
      assert_in_delta 0.9, Synth.render(name).map(&:abs).max, 0.01, name
    end
  end

  def test_every_sound_starts_and_ends_at_silence
    Synth::SOUNDS.each do |name|
      samples = Synth.render(name)
      assert_in_delta 0.0, samples.first, 0.01, name
      assert_in_delta 0.0, samples.last, 0.01, name
    end
  end

  def test_durations_are_as_designed
    DURATIONS.each do |name, expected|
      assert_in_delta expected, Synth.render(name).size.fdiv(Synth::SAMPLE_RATE), expected * 0.1 + 0.005, name
    end
  end

  def test_rendering_is_deterministic
    Synth::SOUNDS.each { assert_equal Synth.render(it), Synth.render(it), it }
  end

  def test_sounds_differ_from_one_another
    assert_equal Synth::SOUNDS.size, Synth::SOUNDS.map { Synth.render(it) }.uniq.size
  end

  def test_unknown_sound_is_an_error
    assert_raises(ArgumentError) { Synth.render(:bang) }
  end
end
