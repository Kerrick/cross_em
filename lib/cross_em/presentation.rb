# frozen_string_literal: true

require_relative "../cross_em"

module CrossEm
  # How Cross ’em looks, sounds and answers a tap, apart from Lota: the
  # palette and type, units and layout, the board's view, the words, the
  # sheets, the sounds' recipes and the Play screen's state. None of it
  # draws or plays anything, so all of it runs, and is tested, without a
  # window; CrossEm::Shell carries it out with Lota.
  module Presentation
  end
end

%w[
  units rect color palette appearance settings look layout board_view copy reflow sheet input clock shot_schedule
  script archive_list sounds ease confetti motion choreographer typing spatial focus_ring
  key_map pointer_map play
].each { require_relative "presentation/#{it}" }
