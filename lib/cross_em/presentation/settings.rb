# frozen_string_literal: true

module CrossEm
  module Presentation
    # What the player has chosen, apart from the game: whether they have
    # read how to play, sound on or off, the appearance, and calm motion.
    # Kept as a small JSON file of its own, so a damaged one costs only
    # these, and anything unreadable in it falls back to the default.
    class Settings < Data.define(:instructions_seen, :muted, :appearance, :calm)
      FILE = "settings.json"

      def self.default = new(instructions_seen: false, muted: false, appearance: :system, calm: false)

      def self.parse(text)
        hash = JSON.parse(text.to_s)
        return default unless hash.is_a?(Hash)

        new(instructions_seen: hash["instructions_seen"] == true, muted: hash["muted"] == true,
            appearance: Appearance.parse(hash["appearance"]), calm: hash["calm"] == true)
      rescue JSON::ParserError
        default
      end

      def to_json(*) = JSON.pretty_generate(to_h.transform_keys(&:to_s).merge("appearance" => appearance.to_s))
    end
  end
end
