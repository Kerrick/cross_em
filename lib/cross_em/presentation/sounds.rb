# frozen_string_literal: true

module CrossEm
  module Presentation
    # Which sound each of the Game's events makes, and at what pitch: a
    # tock to pick up, a clack to place that rises a little with each
    # letter on the grid, a tick to return, a rattle to shuffle, a thunk
    # when a check finds problems, a chime to win and a soft phrase to
    # lose. A check that ends the game leaves the sound to the ending.
    module Sounds
      Cue = Data.define(:name, :pitch)

      module_function

      def for(event, game)
        case event
        when Events::Selected then Cue.new(name: :pick, pitch: 1.0)
        when Events::Deselected then Cue.new(name: :pick, pitch: 0.84)
        when Events::Placed then Cue.new(name: :place, pitch: 1.0 + (0.025 * (game.board.size - 1)))
        when Events::Returned then Cue.new(name: :return, pitch: 1.0)
        when Events::Reset then Cue.new(name: :shuffle, pitch: 0.8)
        when Events::Shuffled then Cue.new(name: :shuffle, pitch: 1.0)
        when Events::Checked then Cue.new(name: :problem, pitch: 1.0) unless event.check.clean? || game.over?
        when Events::Won then Cue.new(name: :win, pitch: 1.0)
        when Events::Lost then Cue.new(name: :loss, pitch: 1.0)
        end
      end
    end
  end
end
