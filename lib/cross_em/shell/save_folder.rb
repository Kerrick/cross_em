# frozen_string_literal: true

module CrossEm
  module Shell
    # The game's save folder, as the storage an Archive and the settings
    # keep their files in: it answers +read(name)+ with a file's text, or
    # nil, and +write(name, text)+. Lota's Filesystem never raises for a
    # missing or unwritable file, it answers [nil, message]; anything else
    # that goes wrong is caught too, so a save that fails loses the save,
    # never the game.
    class SaveFolder
      def read(name)
        contents, = ::Lota::Filesystem.read(name)
        contents&.dup&.force_encoding(Encoding::UTF_8)
      rescue StandardError => e
        warn "Cross ’em: could not read #{name}: #{e.message}"
        nil
      end

      def write(name, text)
        saved, message = ::Lota::Filesystem.write(name, text)
        warn "Cross ’em: could not save #{name}: #{message}" unless saved
        text
      rescue StandardError => e
        warn "Cross ’em: could not save #{name}: #{e.message}"
        text
      end

      def path(name) = File.join(::Lota::Filesystem.save_directory, name)
    end
  end
end
