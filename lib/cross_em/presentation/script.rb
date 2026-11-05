# frozen_string_literal: true

module CrossEm
  module Presentation
    # A few moves to play by themselves at startup, for screenshots and
    # trying things out (CROSS_EM_SCRIPT). Steps are separated by commas,
    # and a step's arguments by colons:
    #
    #   pick:K             picks up the first K in the pool
    #   slot:3             taps pool slot 3 (from 0)
    #   tap:0:1            taps the cell at column 0, row 1
    #   word:MILK:0:0:down places MILK from (0, 0) down (or across),
    #                      using a letter already there where it fits
    #   shuffle  reset     press those buttons
    #   giveup             gives up, confirming at once
    #   arm                presses Give up once, so it asks to confirm
    #   help  credits      open those sheets; close closes one
    #   scroll:400         scrolls a sheet, or pans the board, by points
    #   copy               copies the result
    #   wait:1.5           waits that many seconds before the next step
    class Script < Data.define(:steps)
      class Step < Data.define(:name, :args); end

      def self.parse(text)
        steps = text.to_s.split(",").map(&:strip).reject(&:empty?).map do |step|
          name, *args = step.split(":")
          Step.new(name: name.downcase.to_sym, args:)
        end
        new(steps: steps.freeze)
      end

      # The steps due by +elapsed+ seconds, and the script that is left.
      # A wait holds back every step after it until its time has passed.
      def due(elapsed, started_at = 0.0)
        ready = []
        left = steps.dup
        clock = started_at
        while (step = left.first)
          if step.name == :wait
            ends = clock + Float(step.args.first || 0, exception: false).to_f
            break if elapsed < ends

            clock = ends
            left.shift
          else
            ready << left.shift
          end
        end
        [ready, Script.new(steps: left.freeze), clock]
      end

      def empty? = steps.empty?
    end
  end
end
