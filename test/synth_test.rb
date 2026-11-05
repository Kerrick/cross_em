# frozen_string_literal: true

require "test_helper"
require "cross_em/presentation/synth"

class SynthTest < Minitest::Test
  Synth = CrossEm::Presentation::Synth

  # Roughly how long each sound should last, in seconds.
  DURATIONS = {
    pick: 0.115, place: 0.165, return: 0.09, shuffle: 0.26, check: 0.42,
    problem: 0.23, win: 1.79, loss: 1.32, button: 0.06, copied: 0.44
  }.freeze

  # Each sound, rendered once for the tests that only look at it.
  RENDERED = Hash.new { |sounds, name| sounds[name] = Synth.render(name) }

  def rendered(name) = RENDERED[name]

  def test_lists_every_sound = assert_equal DURATIONS.keys.sort, Synth::SOUNDS.sort

  def test_sample_rate = assert_equal 44_100, Synth::SAMPLE_RATE

  def test_every_sound_renders_samples_in_range
    Synth::SOUNDS.each do |name|
      samples = rendered(name)
      refute_empty samples, name
      assert samples.all?(Float), name
      assert samples.all? { it.between?(-1.0, 1.0) }, name
    end
  end

  def test_every_sound_peaks_at_its_own_level
    assert_equal Synth::SOUNDS.sort, Synth::LEVELS.keys.sort
    Synth::SOUNDS.each do |name|
      assert_in_delta 10**(Synth::LEVELS[name] / 20.0), rendered(name).map(&:abs).max, 1e-9, name
    end
  end

  def test_the_more_a_moment_matters_the_louder_its_sound
    levels = Synth::LEVELS

    assert_operator levels[:win], :>, levels[:loss]
    assert_operator levels[:loss], :>, levels[:place]
    assert_operator levels[:place], :>, levels[:pick]
    assert_operator levels[:pick], :>, levels[:button]
  end

  def test_every_sound_starts_and_ends_at_silence
    Synth::SOUNDS.each do |name|
      samples = rendered(name)
      assert_in_delta 0.0, samples.first, 1e-6, name
      assert_in_delta 0.0, samples.last, 1e-6, name
    end
  end

  def test_durations_are_as_designed
    DURATIONS.each do |name, expected|
      assert_in_delta expected, rendered(name).size.fdiv(Synth::SAMPLE_RATE), expected * 0.1 + 0.005, name
    end
  end

  def test_rendering_is_deterministic
    Synth::SOUNDS.each { assert_equal rendered(it), Synth.render(it), it }
  end

  def test_sounds_differ_from_one_another
    assert_equal Synth::SOUNDS.size, Synth::SOUNDS.map { rendered(it) }.uniq.size
  end

  def test_unknown_sound_is_an_error
    assert_raises(ArgumentError) { Synth.render(:bang) }
  end
end
