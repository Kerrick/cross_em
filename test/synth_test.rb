# frozen_string_literal: true

require "test_helper"
require "cross_em/presentation/synth"

class SynthTest < Minitest::Test
  Synth = CrossEm::Presentation::Synth

  # How a sound's energy spreads over frequency, by a fast Fourier
  # transform of the whole sound.
  module Spectrum
    module_function

    # The share of the energy in +energies+ (from #of) at +frequency+ Hz
    # and above.
    def share_above(energies, frequency)
      split = (frequency * 2 * energies.size / Synth::SAMPLE_RATE.to_f).ceil
      energies[(split - 1)..].sum / energies.sum
    end

    # The energy in each frequency bin of +samples+, padded with silence
    # to a power of two, from the lowest bin to half the sample rate.
    def of(samples)
      size = 1 << (samples.size - 1).bit_length
      real, imaginary = transform(samples + ([0.0] * (size - samples.size)))
      (1..(size / 2)).map { (real[it]**2) + (imaginary[it]**2) }
    end

    def transform(samples)
      return [samples.dup, [0.0] * samples.size] if samples.size == 1

      even_real, even_imaginary = transform(samples.each_slice(2).map(&:first))
      odd_real, odd_imaginary = transform(samples.each_slice(2).map(&:last))
      half = samples.size / 2
      real, imaginary = Array.new(samples.size), Array.new(samples.size)
      half.times do |index|
        angle = -2 * Math::PI * index / samples.size
        cosine, sine = Math.cos(angle), Math.sin(angle)
        turned_real = (cosine * odd_real[index]) - (sine * odd_imaginary[index])
        turned_imaginary = (cosine * odd_imaginary[index]) + (sine * odd_real[index])
        real[index], imaginary[index] = even_real[index] + turned_real, even_imaginary[index] + turned_imaginary
        real[index + half] = even_real[index] - turned_real
        imaginary[index + half] = even_imaginary[index] - turned_imaginary
      end
      [real, imaginary]
    end
  end

  # Roughly how long each sound should last, in seconds.
  DURATIONS = {
    pick: 0.115, place: 0.165, return: 0.09, shuffle: 0.26, check: 0.42,
    problem: 0.23, win: 1.79, loss: 1.32, button: 0.06, copied: 0.44
  }.freeze

  # Each sound, rendered once for the tests that only look at it.
  RENDERED = Hash.new { |sounds, name| sounds[name] = Synth.render(name) }

  def rendered(name) = RENDERED[name]

  SPECTRA = Hash.new { |spectra, name| spectra[name] = Spectrum.of(RENDERED[name]) }

  def spectrum(name) = SPECTRA[name]

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

  # Measures, so the sounds stay soft to the ear: no hiss or crackle
  # above 6 kHz, no click to begin, no offset from zero, and a peak that
  # is part of the sound rather than a spike above it.

  def test_no_sound_has_energy_to_speak_of_above_6_khz
    Synth::SOUNDS.each do |name|
      assert_operator Spectrum.share_above(spectrum(name), 6_000), :<, 0.001, name
    end
  end

  def test_little_of_any_sound_is_above_3_khz
    Synth::SOUNDS.each do |name|
      assert_operator Spectrum.share_above(spectrum(name), 3_000), :<, 0.01, name
    end
  end

  def test_every_sound_is_struck_softly
    attack = Synth::SAMPLE_RATE * 3 / 1000
    Synth::SOUNDS.each do |name|
      samples = rendered(name)

      assert_operator samples.first(attack).map(&:abs).max, :<, samples.map(&:abs).max / 2, name
    end
  end

  def test_no_sound_is_a_spike_or_a_drone
    Synth::SOUNDS.each do |name|
      samples = rendered(name)
      rms = Math.sqrt(samples.sum { it * it } / samples.size)
      crest = 20 * Math.log10(samples.map(&:abs).max / rms)

      assert_includes 6..20, crest.round(1), name
    end
  end

  def test_no_sound_sits_off_zero
    Synth::SOUNDS.each do |name|
      samples = rendered(name)

      assert_in_delta 0.0, samples.sum / samples.size, 1e-4, name
    end
  end

  def test_rendering_everything_takes_well_under_a_second
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Synth::SOUNDS.each { Synth.render(it) }

    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 0.75
  end

  def test_unknown_sound_is_an_error
    assert_raises(ArgumentError) { Synth.render(:bang) }
  end
end
