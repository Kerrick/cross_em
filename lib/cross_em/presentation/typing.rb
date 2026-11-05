# frozen_string_literal: true

module CrossEm
  module Presentation
    # Playing at a keyboard: the player types a whole word, which builds
    # a draft, and Enter or Space places it where it fits (WordFit). One
    # place, and it goes there at once; several, and the player chooses
    # among them, numbered on the board; none, and the screen says why.
    # Backspace edits the draft, and with nothing typed takes back the
    # last word placed this way, the letters it added and no others.
    #
    # Every letter still goes onto the board through the Game, one at a
    # time, so the rules, saving, events and animations are exactly a
    # tap's. Each letter comes from the first slot holding it.
    class Typing
      # The longest draft: no word can use more letters than there are.
      LONGEST = Rules::LETTER_COUNT

      # Seconds between the letters of one word leaving the pool, so they
      # fly, and clack, one after another.
      STAGGER = 0.07

      # Several places a word fits, and which one is shown.
      class Choice < Data.define(:word, :placements, :index)
        def current = placements[index]
        def size = placements.size
        def cycled(by) = with(index: (index + by) % size)
      end

      attr_reader :draft, :choice, :misfit

      # How long after the event being told its animation and sound
      # should wait: a word's later letters leave a little after its
      # first.
      attr_reader :delay

      def initialize(play)
        @play = play
        @delay = 0.0
        forget
      end

      # Starts afresh, as for another game.
      def forget
        @draft = +""
        @choice = nil
        @misfit = nil
        @words = []
      end

      def drafting? = !@draft.empty?
      def choosing? = !@choice.nil?

      # Adds +letter+ to the draft. A choice being made goes back to the
      # draft first; a letter picked up with a tap is put down.
      def type(letter)
        return unless game.playing?

        if choosing?
          @choice = nil
          @play.refit
        end
        @play.pick(game.selected) if game.selected
        return @play.sound(:button) if @draft.size >= LONGEST

        @draft << letter
        @misfit = nil
      end

      # Backspace: back from a choice to the draft, or the draft's last
      # letter, or, with nothing typed, the last word placed by typing.
      # Answers whether it did any of those.
      def erase
        if choosing? then cancel
        elsif drafting?
          @draft.chop!
          @misfit = nil
          true
        else
          take_back_word
        end
      end

      # Esc: back from a choice to the draft, or clears the draft.
      # Answers whether it did either.
      def escape
        if choosing? then cancel
        elsif drafting?
          clear
          true
        else
          false
        end
      end

      # Enter or Space: places the word being chosen, or looks for where
      # the draft fits. Answers whether there was anything to do.
      def submit
        return confirm if choosing?
        return false unless drafting? && game.playing?

        placements = WordFit.new(board: game.board, pool: game.pool).placements(@draft)
        case placements.size
        when 0 then refuse
        when 1 then place(placements.first)
        else
          @choice = Choice.new(word: @draft.dup, placements:, index: 0)
          @play.sound(:pick)
          @play.refit
        end
        true
      end

      # Tab or an arrow: shows the next (or, +by+ -1, the previous) place.
      def cycle(by)
        return false unless choosing?

        @choice = @choice.cycled(by)
        @play.sound(:button)
        @play.refit
        true
      end

      # 1 to 9: places the word in that numbered place at once.
      def choose(number)
        return false unless choosing? && number.between?(1, @choice.size)

        @choice = @choice.with(index: number - 1)
        confirm
      end

      # The pool slots the draft would draw from, if every letter came
      # from the pool: the first slots holding each letter, as many as
      # the draft has of it. A light mark, not a promise; a word may use
      # letters already on the board instead.
      def pool_marks
        return Set.new unless drafting? && game.playing?

        wanted = @draft.chars.tally
        game.pool.slots.each_index.select { |i| (letter = game.pool[i]) && wanted[letter].to_i.positive? && (wanted[letter] -= 1) }.to_set
      end

      # The cells to keep in view while choosing.
      def cells = choosing? ? @choice.current.positions : []

      # Takes back the letter placed last, by anyone, when no typed word
      # is left to take back.
      def take_back_letter
        last = @play.last_placed
        @play.tap_cell(last) if last
      end

      private

      def game = @play.game

      def confirm
        placement = @choice.current
        @choice = nil
        place(placement)
        true
      end

      def cancel
        @choice = nil
        @play.refit
        true
      end

      def clear
        @draft = +""
        @misfit = nil
      end

      def refuse
        @misfit = WordFit.new(board: game.board, pool: game.pool).misfit(@draft)
        @play.sound(:button)
      end

      # Each fresh letter from the first slot that has it, one after
      # another through the Game, a little later each.
      def place(placement)
        @play.disarm
        placed = []
        placement.fresh.each_with_index do |(position, letter), i|
          index = game.pool.slots.index(letter) or break
          @delay = i * STAGGER
          placed << [position, letter] if game.place_letter(index, position)
        end
        @delay = 0.0
        @words << placed unless placed.empty?
        clear
        @play.refit(focus: placement.positions)
      end

      # The last word placed by typing that still has letters of its own
      # on the board: those go back, last first. With none, the letter
      # placed last goes back, however it was placed.
      def take_back_word
        return false unless game.playing?

        while (word = @words.pop)
          back = word.select { |position, letter| game.board[position] == letter }.map(&:first)
          next if back.empty?

          @play.pick(game.selected) if game.selected
          back.reverse.each_with_index do |position, i|
            @delay = i * Motion::STAGGER
            game.tap_cell(position)
          end
          @delay = 0.0
          return true
        end
        take_back_letter
        true
      end
    end
  end
end
