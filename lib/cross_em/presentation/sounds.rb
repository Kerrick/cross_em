# frozen_string_literal: true

module CrossEm
  module Presentation
    # Which sounds each of the Game's events makes, at what pitch, and how
    # long after the event: a tock to pick up, a clack to place that rises
    # a little with each letter on the grid, a tick to return, a rattle to
    # shuffle, a paper swish as a check sweeps the board and a thunk as it
    # finds problems, a chime as a win's wave begins and a soft phrase
    # for a loss. Each event's sounds come in a list, so a check can swish
    # now and thunk once its sweep has passed.
    module Sounds
      Cue = Data.define(:name, :pitch, :delay) do
        def initialize(name:, pitch: 1.0, delay: 0.0) = super
      end

      module_function

      def for(event, game)
        case event
        when Events::Selected then [Cue.new(name: :pick)]
        when Events::Deselected then [Cue.new(name: :pick, pitch: 0.84)]
        when Events::Placed then [Cue.new(name: :place, pitch: 1.0 + (0.025 * (game.board.size - 1)))]
        when Events::Returned then [Cue.new(name: :return)]
        when Events::Reset then [Cue.new(name: :shuffle, pitch: 0.8)]
        when Events::Shuffled then [Cue.new(name: :shuffle)]
        when Events::Checked then checked(event.check, game)
        when Events::Won then [Cue.new(name: :win, delay: Motion::SWEEP)]
        when Events::Lost then [Cue.new(name: :loss, delay: Motion::SWEEP)]
        else []
        end
      end

      # The check sweeps the board; problems found while the game goes on
      # thunk as the sweep ends. The end of a game has its own sound.
      def checked(check, game)
        swish = Cue.new(name: :check)
        return [swish] if check.clean? || game.over? || check.problems.empty?

        [swish, Cue.new(name: :problem, delay: Motion::SWEEP * 0.85)]
      end
    end
  end
end
