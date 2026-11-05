# frozen_string_literal: true

require_relative "presentation"

module CrossEm
  # Cross ’em on Lota: the thin layer that draws the Presentation in the
  # window, plays its sounds, saves to the save folder, and turns Lota's
  # callbacks into the player's pointers and keys. Everything that can be
  # decided without Lota is decided in Presentation; this layer only
  # carries it out.
  module Shell
  end
end

%w[
  save_folder settings_store clipboard speaker font_book type pen tile_painter board_painter pool_painter
  header_painter button_painter panel_painter sheet_painter flight_painter confetti_painter renderer app
].each { require_relative "shell/#{it}" }
