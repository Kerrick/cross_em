# frozen_string_literal: true

module CrossEm
  module Shell
    # The game's save folder, as the storage an Archive and the settings
    # keep their files in: it answers +read(name)+ with a file's text, or
    # nil, and +write(name, text)+. Lota's Filesystem never raises for a
    # missing or unwritable file, it answers [nil, message]; a write that
    # fails is reported and lost, never the game.
    class SaveFolder
      # The file's text, or nil when there is no such file. A file that is
      # there but cannot be read raises Archive::Unreadable, so the records
      # are never written over for want of reading them.
      def read(name)
        contents, message = ::Lota::Filesystem.read(name)
        return contents.dup.force_encoding(Encoding::UTF_8) if contents
        return if ::Lota::Filesystem.info(name).nil?

        raise Archive::Unreadable, "#{name}: #{message}"
      rescue Archive::Unreadable
        raise
      rescue StandardError => e
        raise Archive::Unreadable, "#{name}: #{e.message}"
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
