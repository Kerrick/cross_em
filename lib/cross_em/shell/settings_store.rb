# frozen_string_literal: true

module CrossEm
  module Shell
    # The player's Settings, in a small JSON file of their own beside the
    # records.
    class SettingsStore
      def initialize(folder)
        @folder = folder
      end

      # The settings, or the defaults when they cannot be read.
      def load
        Presentation::Settings.parse(@folder.read(Presentation::Settings::FILE))
      rescue Archive::Unreadable => e
        warn "Cross ’em: #{e.message}; using the default settings"
        Presentation::Settings.default
      end
      def save(settings) = @folder.write(Presentation::Settings::FILE, settings.to_json)
    end
  end
end
