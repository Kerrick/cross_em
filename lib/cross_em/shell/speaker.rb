# frozen_string_literal: true

begin
  require_relative "../presentation/synth"
rescue LoadError
  # Without the synthesizer the game is silent, and plays the same.
end

module CrossEm
  module Shell
    # Plays the game's sounds, which the Synth renders in Ruby, so there
    # are no audio files. Rendering every sound takes a moment, so they are
    # made one a frame as the game starts (#warm), or at once when one is
    # wanted first. Each sound has a few voices, so quick taps overlap
    # rather than cut each other off. Muted, without the Synth, or without
    # an audio device, it plays nothing, and the game goes on.
    #
    # The Synth sets each sound's level and leaves headroom, so the voices
    # play at full volume. Two things keep sounds from piling up: the same
    # sound asked for twice at once plays once, and the end of a game
    # (a win or a loss) fades whatever else still rings, so it is heard
    # alone.
    class Speaker
      VOICES = 3
      VOLUME = 1.0

      # A sound asked for again sooner than this is the same sound.
      GAP = 0.03

      # Sounds that have the stage to themselves.
      FINALE = %i[win loss].freeze

      # How much of its volume a fading voice keeps each frame: gone in
      # about eight frames, an eighth of a second.
      FADE = 0.6

      attr_accessor :muted

      # +enabled+ false makes no sound at all, not even an audio device
      # (CROSS_EM_MUTE=1).
      def initialize(muted: false, enabled: true)
        @muted = muted
        @voices = {}
        @next = Hash.new(0)
        @last = {}
        @fading = []
        @working = enabled && defined?(::Lota::Audio::Source) ? true : false
        @pending = synth && @working ? synth::SOUNDS.dup : []
      end

      # Makes the next sound not yet made, and fades voices on their way
      # out; call once a frame.
      def warm
        fade
        name = @pending.shift
        build(name) if name
      end

      # Plays +name+ at +pitch+ (1 is as rendered).
      def play(name, pitch: 1.0)
        return if @muted || !@working || again?(name)

        voices = @voices[name] || build(name) or return
        quiet_all_but(name) if FINALE.include?(name)
        voice = free_voice(name, voices)
        @fading.delete(voice)
        voice.stop
        voice.volume = VOLUME
        voice.pitch = pitch
        voice.play
      rescue StandardError => e
        warn "Cross ’em: could not play #{name}: #{e.message}"
      end

      def stop_all
        @fading.clear
        @voices.each_value { |voices| voices.each(&:stop) }
      end

      private

      def again?(name)
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        last, @last[name] = @last[name], now
        last && now - last < GAP
      end

      # A voice that is not playing, if there is one; otherwise, in turn,
      # one that has had the longest to die away.
      def free_voice(name, voices)
        turn = voices.rotate(@next[name] % voices.size)
        @next[name] += 1
        turn.find { !it.playing? } || turn.first
      end

      def quiet_all_but(name)
        @voices.each do |other, voices|
          next if other == name

          voices.each { |voice| @fading << voice if voice.playing? && !@fading.include?(voice) }
        end
      end

      def fade
        @fading.reject! do |voice|
          voice.volume *= FADE
          next false if voice.volume > 0.02

          voice.stop
          voice.volume = VOLUME
          true
        end
      end

      def synth = defined?(Presentation::Synth) && Presentation::Synth

      def build(name)
        return unless @working && synth&.const_get(:SOUNDS)&.include?(name)

        @pending.delete(name)
        source = ::Lota::Audio::Source.new(sound_data(synth.render(name)), :static)
        source.volume = VOLUME
        @voices[name] = [source] + Array.new(VOICES - 1) { source.clone }
      rescue StandardError => e
        warn "Cross ’em: playing without sound (#{e.message})"
        @working = false
        nil
      end

      def sound_data(samples)
        sound = ::Lota::Sound::SoundData.new(samples.size, synth::SAMPLE_RATE, 16, 1)
        samples.each_with_index { |value, i| sound.sample = [i, value] }
        sound
      end
    end
  end
end
