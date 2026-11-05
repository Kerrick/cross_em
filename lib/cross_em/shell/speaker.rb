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
    class Speaker
      VOICES = 3
      VOLUME = 0.8

      attr_accessor :muted

      # +enabled+ false makes no sound at all, not even an audio device
      # (CROSS_EM_MUTE=1).
      def initialize(muted: false, enabled: true)
        @muted = muted
        @voices = {}
        @next = Hash.new(0)
        @working = enabled && defined?(::Lota::Audio::Source) ? true : false
        @pending = synth && @working ? synth::SOUNDS.dup : []
      end

      # Makes the next sound not yet made; call once a frame.
      def warm
        name = @pending.shift
        build(name) if name
      end

      # Plays +name+ at +pitch+ (1 is as rendered).
      def play(name, pitch: 1.0)
        return if @muted || !@working

        voices = @voices[name] || build(name) or return
        voice = voices[@next[name] % voices.size]
        @next[name] += 1
        voice.stop
        voice.pitch = pitch
        voice.play
      rescue StandardError => e
        warn "Cross ’em: could not play #{name}: #{e.message}"
      end

      def stop_all = @voices.each_value { |voices| voices.each(&:stop) }

      private

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
