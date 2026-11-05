# frozen_string_literal: true

module CrossEm
  module Shell
    # The player's Settings, in a small JSON file of their own beside the
    # records.
    class SettingsStore
      def initialize(folder)
        @folder = folder
      end

      def load = Presentation::Settings.parse(@folder.read(Presentation::Settings::FILE))
      def save(settings) = @folder.write(Presentation::Settings::FILE, settings.to_json)
    end
  end
end
