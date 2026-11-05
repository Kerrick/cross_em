# frozen_string_literal: true

module CrossEm
  module Presentation
    # Every sound in the game, rendered offline as mono Floats in -1.0..1.0.
    # Wooden tiles on a paper page: short, warm, and never harsh. Nothing
    # here touches Lota, so the Speaker only has to copy the samples.
    #
    # A sound is a plain Array of samples. The small tools below (tones,
    # noise, filters, envelopes, mixing) each take and return such arrays,
    # so each recipe reads as a sentence about what the sound is made of.
    module Synth
      SAMPLE_RATE = 44_100
      SOUNDS = %i[pick place return shuffle check problem win loss button copied].freeze

      PEAK = 0.9
      # Long enough to hide the jump to or from silence, short enough to
      # leave the attack of a tock untouched.
      FADE = 0.004

      # Pitches, in Hz.
      E4 = 329.63
      G4 = 392.00
      C5 = 523.25
      E5 = 659.25
      G5 = 783.99
      C6 = 1046.50
      E6 = 1318.51
      A6 = 1760.00

      def self.render(name)
        raise ArgumentError, "unknown sound: #{name.inspect}" unless SOUNDS.include?(name)

        normalise(fade(__send__(:"#{name}_sound")))
      end

      # --- The sounds ---

      # A wooden tock: a tone that drops a little as it dies, with a tick.
      def self.pick_sound
        mix(
          decay(glide(640, 420, seconds(0.06)), 70),
          scale(tick(seconds(0.06), brightness: 2_500, rate: 400), 0.35)
        )
      end

      # A clack: a body tone with a hollow second partial and a knock.
      # Tonal on purpose, so the Speaker can pitch it.
      def self.place_sound
        mix(
          decay(glide(300, 250, seconds(0.09)), 45),
          scale(decay(sine(610, seconds(0.09)), 70), 0.4),
          scale(tick(seconds(0.09), brightness: 3_000, rate: 300), 0.4)
        )
      end

      # The pick-up tock's lighter, higher cousin.
      def self.return_sound
        mix(
          decay(glide(980, 760, seconds(0.06)), 80),
          scale(tick(seconds(0.06), brightness: 3_500, rate: 450), 0.25)
        )
      end

      # Several small clicks at uneven times and pitches, like tiles
      # tumbling in a box. Seeded, so it rattles the same way every time.
      def self.shuffle_sound
        random = Random.new(1720)
        clicks = Array.new(7) do |index|
          pitch = 500 + random.rand * 500
          click = scale(decay(glide(pitch, pitch * 0.7, seconds(0.03)), 140), 0.5 + random.rand * 0.5)
          [index * 0.04 + random.rand * 0.02, click]
        end
        sequence(*clicks, length: seconds(0.3))
      end

      # Paper sliding: soft noise that swells and fades away, with the
      # rustle taken off the top and the rumble off the bottom.
      def self.check_sound
        rustle = highpass(lowpass(noise(seconds(0.4), Random.new(7)), 4_000), 600)
        scale(swell(rustle), 0.5)
      end

      # A muted thunk: low and round, no edge.
      def self.problem_sound
        mix(
          decay(glide(150, 100, seconds(0.15)), 28),
          scale(tick(seconds(0.15), brightness: 700, rate: 60), 0.4)
        )
      end

      # C-E-G-C, rising, each note a small bell that rings into the next.
      def self.win_sound
        notes = [C5, E5, G5, C6].each_with_index.map { |pitch, index| [index * 0.15, bell(pitch, 0.75)] }
        sequence(*notes, length: seconds(1.2))
      end

      # G down to E, softly: the second note answers the first, kindly.
      def self.loss_sound
        sequence(
          [0.0, soft_note(G4, 0.55)],
          [0.3, scale(soft_note(E4, 0.6), 0.8)],
          length: seconds(0.9)
        )
      end

      # The quietest thing in the game: a dry little click.
      def self.button_sound
        mix(
          decay(sine(1_100, seconds(0.03)), 130),
          scale(tick(seconds(0.03), brightness: 3_000, rate: 500), 0.3)
        )
      end

      # Two bright tones, the second higher, like a tiny bell.
      def self.copied_sound
        sequence(
          [0.0, bell(E6, 0.14)],
          [0.08, bell(A6, 0.17)],
          length: seconds(0.25)
        )
      end

      # --- Voices ---

      # A struck bell: a pure tone plus quieter, inharmonic partials that
      # die faster, which is most of what makes it sound like metal.
      def self.bell(pitch, length)
        count = seconds(length)
        mix(
          decay(sine(pitch, count), 5 / length),
          scale(decay(sine(pitch * 2.76, count), 12 / length), 0.25),
          scale(decay(sine(pitch * 2.0, count), 8 / length), 0.15)
        )
      end

      # A rounded, flute-like note: a tone and a faint octave.
      def self.soft_note(pitch, length)
        count = seconds(length)
        decay(mix(sine(pitch, count), scale(sine(pitch * 2, count), 0.15)), 4.5 / length)
      end

      # A knock: very short noise, softened so it thuds rather than hisses.
      def self.tick(count, brightness:, rate:)
        decay(lowpass(noise(count, Random.new(count)), brightness), rate)
      end

      # --- Sources ---

      def self.sine(pitch, count) = glide(pitch, pitch, count)

      # A sine whose pitch slides exponentially from one frequency to
      # another. Summing the phase keeps the wave smooth as it bends.
      def self.glide(from, to, count)
        phase = 0.0
        Array.new(count) do |index|
          pitch = from * (to.fdiv(from)**index.fdiv(count))
          phase += 2 * Math::PI * pitch / SAMPLE_RATE
          Math.sin(phase)
        end
      end

      def self.noise(count, random) = Array.new(count) { random.rand * 2 - 1 }

      # --- Shaping ---

      # Dies away exponentially: +rate+ is the fall per second.
      def self.decay(samples, rate)
        samples.each_with_index.map { |sample, index| sample * Math.exp(-rate * index / SAMPLE_RATE) }
      end

      # Rises then falls in one smooth hump.
      def self.swell(samples)
        samples.each_with_index.map { |sample, index| sample * Math.sin(Math::PI * index / samples.size)**2 }
      end

      def self.scale(samples, gain) = samples.map { it * gain }

      # One-pole low-pass: each sample moves part of the way to the input.
      def self.lowpass(samples, cutoff)
        smoothing = 1 - Math.exp(-2 * Math::PI * cutoff / SAMPLE_RATE)
        level = 0.0
        samples.map { level += smoothing * (it - level) }
      end

      def self.highpass(samples, cutoff) = samples.zip(lowpass(samples, cutoff)).map { |sample, low| sample - low }

      # --- Combining ---

      # Sounds played together, padded with silence to the longest.
      def self.mix(*tracks, length: tracks.map(&:size).max)
        Array.new(length) { |index| tracks.sum { it[index] || 0.0 } }
      end

      # Sounds that begin at given times, each as an [at_seconds, samples] pair.
      def self.sequence(*entries, length: nil)
        tracks = entries.map { |at, samples| [0.0] * seconds(at) + samples }
        mix(*tracks, length: length || tracks.map(&:size).max)
      end

      # --- Finishing ---

      # Ramps in and out so no sound begins or ends with a click.
      def self.fade(samples)
        ramp = [seconds(FADE), samples.size / 2].min
        samples.each_with_index.map do |sample, index|
          distance = [index, samples.size - 1 - index].min
          distance < ramp ? sample * distance / ramp : sample
        end
      end

      def self.normalise(samples)
        peak = samples.map(&:abs).max
        peak.zero? ? samples : scale(samples, PEAK / peak)
      end

      def self.seconds(duration) = (duration * SAMPLE_RATE).round

      private_class_method(*singleton_methods.grep(/_sound\z/), :bell, :soft_note, :tick, :sine, :glide, :noise,
                           :decay, :swell, :scale, :lowpass, :highpass, :mix, :sequence, :fade, :normalise,
                           :seconds)
    end
  end
end
