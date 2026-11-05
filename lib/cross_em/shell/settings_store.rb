# frozen_string_literal: true

module CrossEm
  module Shell
    # The player's Settings, in a small JSON file of their own beside the
    # records. An +appearance+ given for a development run
    # (CROSS_EM_THEME) is shown but never saved, unless the player picks
    # another one, which is theirs.
    class SettingsStore
      def initialize(folder, appearance: nil)
        @folder = folder
        @override = appearance
      end

      # The settings, or the defaults when they cannot be read.
      def load
        @stored = read
        @override ? @stored.with(appearance: @override) : @stored
      end

      def save(settings)
        settings = settings.with(appearance: stored.appearance) if @override && settings.appearance == @override
        @folder.write(Presentation::Settings::FILE, settings.to_json)
      end

      private

      def stored = @stored ||= read

      def read
        Presentation::Settings.parse(@folder.read(Presentation::Settings::FILE))
      rescue Archive::Unreadable => e
        warn "Cross ’em: #{e.message}; using the default settings"
        Presentation::Settings.default
      end
    end
  end
end
