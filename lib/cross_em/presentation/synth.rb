# frozen_string_literal: true

module CrossEm
  module Presentation
    # Every sound in the game, rendered offline as mono Floats in -1.0..1.0.
    # Felt-covered wooden tiles on a table and a soft marimba: warm and
    # round, with presence but no edge. Nothing here touches Lota, so the
    # Speaker only has to copy the samples.
    #
    # Three rules keep the sounds kind to the ear, and to one another:
    #
    # - Every voice is sines: a body and a few gentle partials, struck with
    #   a soft attack (8 ms or more) and dying exponentially, then low-passed
    #   again. There are no square, saw or raw noise transients.
    # - Every pitch is from one scale, C major pentatonic, so any two sounds
    #   that happen to ring together agree.
    # - Each sound is as loud as it matters (LEVELS), not as loud as it can
    #   be, which leaves headroom for the sounds that overlap.
    #
    # A sound is a plain Array of samples. The small tools below (tones,
    # filters, envelopes, mixing) each take and return such arrays, so each
    # recipe reads as a sentence about what the sound is made of.
    module Synth
      SAMPLE_RATE = 44_100
      SOUNDS = %i[pick place return shuffle check problem win loss button copied].freeze

      # Each sound's peak, in dB below full scale: quiet ticks for the
      # interface, a fuller clack for a placed letter, and the most for
      # the win. Even the loudest moments of a game sum to under full
      # scale (see SoundsTest's mix of a whole game).
      LEVELS = {
        button: -20, pick: -18, return: -18, shuffle: -17, place: -14,
        check: -19, problem: -16, copied: -16, loss: -12, win: -8
      }.freeze

      # The end of every sound fades over this long, so it slips into silence.
      TAIL = 0.012

      # C major pentatonic, in Hz, over the three octaves the game uses.
      C3 = 130.81
      A3 = 220.00
      C4 = 261.63
      D4 = 293.66
      E4 = 329.63
      G4 = 392.00
      A4 = 440.00
      C5 = 523.25
      D5 = 587.33
      E5 = 659.25
      G5 = 783.99
      A5 = 880.00

      def self.render(name)
        raise ArgumentError, "unknown sound: #{name.inspect}" unless SOUNDS.include?(name)

        finish(__send__(:"#{name}_sound"), LEVELS.fetch(name))
      end

      # What the Speaker would put out for +plays+, each [at_seconds, name,
      # pitch], played at full volume, every sound pitched as the Speaker
      # pitches it (faster and shorter). For tests and previews: nothing
      # here clips, so a sum over 1.0 shows where the game would.
      def self.mixdown(plays, rendered: Hash.new { |sounds, name| sounds[name] = render(name) })
        sequence(*plays.map { |at, name, pitch| [at, repitch(rendered[name], pitch)] })
      end

      # Plays +samples+ +pitch+ times as fast, as a voice's pitch does.
      def self.repitch(samples, pitch)
        return samples if pitch == 1

        Array.new((samples.size / pitch).floor) do |index|
          position = index * pitch
          whole = position.floor
          following = samples[whole + 1] || 0.0
          samples[whole] + ((following - samples[whole]) * (position - whole))
        end
      end

      # --- The sounds ---

      # A wooden tock as a tile lifts: a short, soft marimba G.
      def self.pick_sound = lowpass(bar(G4, decay: 40), 3_000)

      # A tile set down on felt: a marimba C with a little thump of wood
      # under it. The Speaker pitches it up the scale as the grid fills.
      def self.place_sound
        lowpass(mix(bar(C4, decay: 28), scale(thump(C4 / 2, decay: 45), 0.5)), 2_800)
      end

      # The tock's lighter, higher cousin, as a tile goes home.
      def self.return_sound = lowpass(bar(D5, decay: 50), 3_200)

      # Four soft taps tumbling, like tiles turned over in a box. They are
      # chosen so that the lower reset (3/4 the pitch) is in the scale too.
      def self.shuffle_sound
        taps = [[0.0, G4, 1.0], [0.05, C5, 0.8], [0.1, A4, 0.7], [0.16, D4, 0.6]]
        lowpass(sequence(*taps.map { |at, pitch, gain| [at, scale(bar(pitch, decay: 45), gain)] }), 3_000)
      end

      # A breath of paper under the sweep of light: noise kept to a band
      # well below the hiss, that swells and dies away.
      def self.check_sound
        breath = bandpass(noise(seconds(0.42), Random.new(7)), 900)
        swell(lowpass(lowpass(breath, 2_200), 2_200))
      end

      # A muted wooden thunk, low and round: something to look at.
      def self.problem_sound
        lowpass(mix(bar(A3, decay: 20, partials: [[1, 1.0], [2, 0.25]]), scale(thump(A3 / 2, decay: 30), 0.6)), 1_500)
      end

      # C, E, G and C rising, rounded bells in the middle of the piano,
      # each ringing into the next, landing on a low C underneath.
      def self.win_sound
        notes = [C4, E4, G4].each_with_index.map { |pitch, index| [index * 0.13, scale(bell(pitch, 1.2), 0.8)] }
        lowpass(sequence(*notes, [0.39, bell(C5, 1.4)], [0.39, scale(soft_note(C3, 1.4), 0.45)]), 4_000)
      end

      # E falling to C, softly, the C resting on its octave below: the
      # phrase settles, rather than mourns.
      def self.loss_sound
        lowpass(sequence(
          [0.0, soft_note(E4, 0.9)],
          [0.32, scale(soft_note(C4, 1.0), 0.9)],
          [0.32, scale(soft_note(C3, 1.0), 0.35)]
        ), 3_000)
      end

      # The quietest thing in the game: a tiny tap.
      def self.button_sound = lowpass(bar(A4, decay: 80), 3_000)

      # Two small bells, the second higher: done.
      def self.copied_sound
        lowpass(sequence([0.0, scale(bell(E5, 0.3), 0.8)], [0.09, bell(A5, 0.35)]), 4_000)
      end

      # --- Voices ---

      # A struck wooden bar, as on a marimba: a body and a soft second and
      # third partial, each dying faster than the one below. It lasts until
      # it has fallen about 40 dB.
      def self.bar(pitch, decay:, partials: [[1, 1.0], [2, 0.12], [3, 0.05]])
        strike(pitch, partials.map { |ratio, gain| [ratio, gain, ratio] }, decay:, length: 4.6 / decay)
      end

      # A rounded bell: a pure tone, a soft octave, and a faint inharmonic
      # partial that dies quickly, which is enough to say "metal".
      def self.bell(pitch, length)
        strike(pitch, [[1, 1.0, 1], [2, 0.1, 2.5], [2.76, 0.05, 4]], decay: 4.6 / length, length:)
      end

      # A flute-like note: a tone and a faint octave, swelling in gently.
      def self.soft_note(pitch, length)
        strike(pitch, [[1, 1.0, 1], [2, 0.12, 1.5]], decay: 4.0 / length, length:, attack: 0.03)
      end

      # The weight of wood meeting felt: a low sine whose pitch drops an
      # octave as it dies, so it lands like a thud, not a click.
      def self.thump(pitch, decay:)
        count = seconds(4.6 / decay)
        soften(decay(glide(pitch, pitch / 2, count), decay), 0.008)
      end

      # Partials of +pitch+, each [ratio, gain, how much faster it dies],
      # struck together with a soft attack and an exponential decay.
      def self.strike(pitch, partials, decay:, length:, attack: 0.01)
        samples = Array.new(seconds(length), 0.0)
        partials.each { |ratio, gain, faster| ring(samples, pitch * ratio, decay * faster, gain) }
        soften(samples, attack)
      end

      # Adds to +samples+ a sine at +pitch+ falling +decay+ per second from
      # +gain+. Each sample follows from the two before it (a damped
      # resonator), which is much quicker than sin and exp for each one.
      def self.ring(samples, pitch, decay, gain)
        step = 2 * Math::PI * pitch / SAMPLE_RATE
        fall = Math.exp(-decay.fdiv(SAMPLE_RATE))
        a1, a2 = 2 * fall * Math.cos(step), fall * fall
        before, last = 0.0, gain * fall * Math.sin(step)
        (1...samples.size).each do |index|
          samples[index] += last
          before, last = last, (a1 * last) - (a2 * before)
        end
        samples
      end

      # --- Sources ---

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

      # Eases the first +attack+ seconds in from silence, so the sound is
      # struck softly rather than snapped on.
      def self.soften(samples, attack)
        count = [seconds(attack), samples.size].min
        count.times { |index| samples[index] *= rise(index.fdiv(count)) }
        samples
      end

      # Half a cosine, from 0 to 1: a ramp with no corners.
      def self.rise(fraction) = 0.5 - (0.5 * Math.cos(Math::PI * fraction))

      # Rises then falls in one smooth hump, the rise the shorter.
      def self.swell(samples)
        samples.each_with_index.map { |sample, index| sample * Math.sin(Math::PI * (index.fdiv(samples.size)**0.75))**2 }
      end

      def self.scale(samples, gain) = samples.map { it * gain }

      # Two-pole filters (from Robert Bristow-Johnson's cookbook), gentle
      # enough to leave no ring: a Butterworth low- and high-pass, and a
      # band-pass that keeps its middle at full level.
      def self.lowpass(samples, cutoff)
        cosine, alpha = shape(cutoff, Math.sqrt(0.5))
        biquad(samples, [(1 - cosine) / 2, 1 - cosine, (1 - cosine) / 2], cosine, alpha)
      end

      def self.highpass(samples, cutoff)
        cosine, alpha = shape(cutoff, Math.sqrt(0.5))
        biquad(samples, [(1 + cosine) / 2, -(1 + cosine), (1 + cosine) / 2], cosine, alpha)
      end

      def self.bandpass(samples, centre, quality: 0.7)
        cosine, alpha = shape(centre, quality)
        biquad(samples, [alpha, 0.0, -alpha], cosine, alpha)
      end

      def self.shape(frequency, quality)
        angle = 2 * Math::PI * frequency / SAMPLE_RATE
        [Math.cos(angle), Math.sin(angle) / (2 * quality)]
      end

      def self.biquad(samples, (b0, b1, b2), cosine, alpha)
        a0 = 1 + alpha
        b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, -2 * cosine / a0, (1 - alpha) / a0
        x1 = x2 = y1 = y2 = 0.0
        samples.map do |x|
          y = (b0 * x) + (b1 * x1) + (b2 * x2) - (a1 * y1) - (a2 * y2)
          x2, x1, y2, y1 = x1, x, y1, y
          y
        end
      end

      # --- Combining ---

      # Sounds played together, padded with silence to the longest.
      def self.mix(*tracks) = sequence(*tracks.map { [0.0, it] })

      # Sounds that begin at given times, each as an [at_seconds, samples] pair.
      def self.sequence(*entries)
        starts = entries.map { |at, _| seconds(at) }
        out = Array.new(entries.zip(starts).map { |(_, samples), start| start + samples.size }.max, 0.0)
        entries.zip(starts).each do |(_, samples), start|
          samples.each_with_index { |sample, index| out[start + index] += sample }
        end
        out
      end

      # --- Finishing ---

      # Takes off any rumble below hearing (and so any offset from zero),
      # eases the end into silence, and sets the peak to +level+ dBFS.
      def self.finish(samples, level)
        samples = highpass(samples, 30)
        tail = [seconds(TAIL), samples.size / 2].min
        samples = samples.each_with_index.map do |sample, index|
          left = samples.size - 1 - index
          left < tail ? sample * rise(left.fdiv(tail)) : sample
        end
        scale(samples, (10**(level / 20.0)) / samples.map(&:abs).max)
      end

      def self.seconds(duration) = (duration * SAMPLE_RATE).round

      private_class_method(*singleton_methods.grep(/_sound\z/), :bar, :bell, :soft_note, :thump, :strike, :glide,
                           :ring, :noise, :decay, :soften, :rise, :swell, :scale, :lowpass, :highpass, :bandpass, :shape,
                           :biquad, :mix, :sequence, :finish, :seconds, :repitch)
    end
  end
end
