# frozen_string_literal: true

module CrossEm
  module Presentation
    # Which sounds each of the Game's events makes, at what pitch, and how
    # long after the event: a tock to pick up, a clack to place that climbs
    # the scale as the grid fills, a tick to return, a rattle to
    # shuffle, a paper swish as a check sweeps the board and a thunk as it
    # finds problems, a chime as a win's wave begins and a soft phrase
    # for a loss. Each event's sounds come in a list, so a check can swish
    # now and thunk once its sweep has passed.
    module Sounds
      Cue = Data.define(:name, :pitch, :delay) do
        def initialize(name:, pitch: 1.0, delay: 0.0) = super
      end

      # The steps of the Synth's pentatonic scale, as ratios to its C: the
      # pitches a placed letter's clack climbs through as the grid fills.
      SCALE = [1, 9 / 8r, 5 / 4r, 3 / 2r, 5 / 3r, 2, 9 / 4r, 5 / 2r].freeze

      # Down a third (G to E) and down a fourth, which keep the Synth's
      # pick and shuffle in the scale too.
      PUT_DOWN = 5 / 6r
      RESET = 3 / 4r

      # How many letters a full grid holds.
      LETTERS = 12

      module_function

      def for(event, game)
        case event
        when Events::Selected then [Cue.new(name: :pick)]
        when Events::Deselected then [Cue.new(name: :pick, pitch: PUT_DOWN.to_f)]
        when Events::Placed then [Cue.new(name: :place, pitch: placed(game.board.size))]
        when Events::Returned then [Cue.new(name: :return)]
        when Events::Reset then [Cue.new(name: :shuffle, pitch: RESET.to_f)]
        when Events::Shuffled then [Cue.new(name: :shuffle)]
        when Events::Checked then checked(event.check, game)
        when Events::Won then [Cue.new(name: :win, delay: Motion::SWEEP)]
        when Events::Lost then [Cue.new(name: :loss, delay: Motion::SWEEP)]
        else []
        end
      end

      # The pitch of the clack for the +count+th letter on the grid: up the
      # scale, a step every letter or two, from C to the E an octave above.
      def placed(count)
        step = ((count - 1).clamp(0, LETTERS - 1) * (SCALE.size - 1)).fdiv(LETTERS - 1).round
        SCALE[step].to_f
      end

      # The check sweeps the board; problems found by placing the last
      # letter thunk as the sweep ends. The end of a game has its own
      # sound, and giving up with letters still to place says enough with
      # it: a thunk there would land on top of the phrase.
      def checked(check, game)
        swish = Cue.new(name: :check)
        return [swish] if check.clean? || game.over? || !game.pool.empty? || check.problems.empty?

        [swish, Cue.new(name: :problem, delay: Motion::SWEEP * 0.85)]
      end
    end
  end
end
