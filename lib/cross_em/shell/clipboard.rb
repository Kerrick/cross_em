# frozen_string_literal: true

module CrossEm
  module Shell
    # The system's clipboard, for "Copy result". A clipboard that will not
    # take the text loses it, never the game.
    class Clipboard
      def copy(text)
        ::Lota::System.clipboard_text = text
        true
      rescue StandardError => e
        warn "Cross ’em: could not copy to the clipboard: #{e.message}"
        false
      end
    end
  end
end
