# frozen_string_literal: true

module CrossEm
  module Presentation
    # Every word the game says. The status line always says what the
    # player can do next, in the state they are in; buttons name their
    # action. Nothing else in the presentation spells out a sentence.
    module Copy
      PICK = "Tap a letter to pick it up."
      PLACE = "Now tap a glowing square to place it."
      TYPE = "Or type a word and press Enter."
      DRAFT_HINT = "Enter places it. Esc clears it."
      SHUFFLE = "Shuffle"
      RESET = "Reset"
      GIVE_UP = "Give up"
      CONFIRM_GIVE_UP = "Give up? Tap again"
      CREDITS = "Credits"
      COPY_RESULT = "Copy result"
      COPIED = "Copied"
      COPY_FAILED = "Couldn't copy"
      NEXT_PUZZLE = "Next puzzle in"
      WON = "Solved!"
      LOST = "Game over"
      STAT_LABELS = ["Played", "Win %", "Streak", "Best streak"].freeze

      # How to play's picture: WORD across, and ROW down from its R.
      EXAMPLE = [["W", 0, 0], ["O", 1, 0], ["R", 2, 0], ["D", 3, 0], ["O", 2, 1], ["W", 2, 2]].freeze

      # The credit the word list asks for, word for word.
      WORD_LIST_CREDIT = "Word list based on SCOWL by Kevin Atkinson and the sources it credits, including ENABLE " \
                         "and the UK Advanced Cryptics Dictionary, Copyright (c) J Ross Beresford 1993-1999. All " \
                         "Rights Reserved."

      # What the status line says: a sentence, a smaller +detail+ after
      # it (a list of +reasons+ for problems), and a +tone+ for its color.
      class Status < Data.define(:text, :detail, :reasons, :tone)
        def initialize(text:, detail: nil, reasons: [], tone: :normal) = super
      end

      module_function

      def number(day) = "No. #{day.number}"
      def play_number(day) = "Play No. #{day.number}"

      def letters(count) = count == 1 ? "1 letter" : "#{count} letters"

      # +keyboard+: the player has one, so the empty board also says a
      # word can be typed.
      def status(game, keyboard: false)
        if game.won? then Status.new(text: WON, detail: "All #{Rules::LETTER_COUNT} letters crossed.", tone: :won)
        elsif game.lost? then Status.new(text: LOST, detail: crossed(game), tone: :lost)
        elsif game.selected then Status.new(text: PLACE)
        elsif game.check && !game.check.clean?
          count = game.check.count
          Status.new(text: "#{letters(count)} #{count == 1 ? 'needs' : 'need'} fixing. Tap one to send it back.",
                     reasons: reasons(game.check), tone: :problem)
        elsif game.board.empty? then Status.new(text: PICK, detail: keyboard ? TYPE : nil)
        else
          Status.new(text: PICK, detail: "#{letters(game.pool.unused_count)} left. Tap a placed one to send it back.")
        end
      end

      # While a typed word's places are shown on the board, numbered:
      # how many, and the keys that choose.
      def choosing(choice)
        last = [choice.size, 9].min
        Status.new(text: "#{choice.word} fits #{choice.size} places. Showing #{choice.index + 1}.",
                   detail: "Tab: next · 1–#{last}: pick · Enter: place · Esc: back")
      end

      # Why a typed word went nowhere, calmly and specifically (a
      # WordFit::Misfit).
      def misfit(misfit)
        word = misfit.word
        case misfit.reason
        when :missing then missing(word, misfit.letters)
        when :on_board then "#{word} is already on the board."
        when :empty then ""
        else "#{word} doesn't fit anywhere on the board."
        end
      end

      # "CRAB needs a B that isn't in the pool." When the pool has some of
      # a letter, but not enough: "CRABB needs more Bs than the pool has."
      def missing(word, letters)
        counts = letters.tally
        if counts.keys.all? { word.count(it) == counts[it] }
          names = counts.map { |letter, count| count == 1 ? "#{article(letter)} #{letter}" : "#{count} #{letter}s" }
          verb = letters.size == 1 ? "isn't" : "aren't"
          "#{word} needs #{names.join(' and ')} that #{verb} in the pool."
        else
          "#{word} needs more #{counts.keys.map { "#{it}s" }.join(' and ')} than the pool has."
        end
      end

      # A letter's name begins with a vowel sound for these: an F, an R.
      def article(letter) = "AEFHILMNORSX".include?(letter) ? "an" : "a"

      # The good news after a loss: how many letters ended up in good
      # words.
      def crossed(game) = "#{game.good_letters} of #{Rules::LETTER_COUNT} letters crossed."

      # Why each problem is one, a sentence fragment a word, in reading
      # order, from the words the check named: "AZ is too short", "TCA
      # isn't in the word list", "DOG isn't connected", "Q is on its own".
      def reasons(check)
        check.words.map do |problem|
          word = problem.word
          case problem.reason
          when :too_short then word.length == 1 ? "#{word} is on its own" : "#{word} is too short"
          when :not_a_word then "#{word} isn't in the word list"
          else "#{word} isn't connected"
          end
        end.uniq
      end

      # How to play, as Sheet blocks: every rule, then the settings. The
      # word list's credit is at the top of the Credits, a tap away from
      # here.
      def instructions(touch:)
        [
          Block.body("Make connected words, crossword style, from the day's twelve letters. " \
                     "There are new letters every day."),
          Block.example(EXAMPLE, [3, 1]),
          Block.small("WORD and ROW cross at the R. The glowing square is a place the next letter can go."),
          Block.space,
          Block.bullet("Tap a letter in the pool to pick it up, then tap a glowing square on the grid to place it."),
          Block.bullet("Tap a placed letter to send it back to the pool."),
          Block.bullet("Every word, across and down, must be a real word of 3 letters or more, " \
                       "and all of them must be connected."),
          Block.bullet("Use as many letters as you can. The game ends when all twelve are used in good words, " \
                       "or when you give up."),
          Block.bullet("Shuffle mixes up the pool. Reset sends every letter back."),
          (Block.bullet("On a keyboard, type a letter to pick it up and Esc to put it down. Backspace sends " \
                        "back the letter you placed last.") unless touch),
          Block.space,
          Block.toggle(:calm, "Calm motion", "Gentle fades instead of flights and bounces."),
          Block.space,
          Block.buttons([[:credits, CREDITS, false], [:close, "Play", true]])
        ].compact
      end

      # The credits, as Sheet blocks, the word list's first (its credit,
      # word for word, then its whole copyright file), from the files that
      # ship with the game: +read+ takes a file's path in the game folder and answers its
      # text, which is shown unmodified.
      def credits(read)
        [
          Block.heading("Word list"),
          Block.small(WORD_LIST_CREDIT),
          Block.license(read.("wordlist-COPYRIGHT.txt")),
          Block.heading("Cross ’em"),
          Block.body("A daily word puzzle, made in Ruby. Free software under the GNU Affero General Public " \
                     "License 3.0."),
          Block.heading("Built with Lota and LÖVE"),
          Block.body("Lota, Ruby bindings for LÖVE, by Kerrick Long, under the GNU Affero General Public " \
                     "License 3.0 or later."),
          Block.body("LÖVE, the free 2D game framework, copyright (c) 2006-2026 LÖVE Development Team, under " \
                     "the zlib license."),
          Block.heading("Fonts"),
          Block.body("Zilla Slab, copyright (c) 2017 The Mozilla Foundation, and Atkinson Hyperlegible, " \
                     "copyright (c) 2020 Braille Institute of America, Inc., are used unmodified under the " \
                     "SIL Open Font License 1.1."),
          Block.subheading("Zilla Slab"),
          Block.license(read.("assets/fonts/OFL-zillaslab.txt")),
          Block.subheading("Atkinson Hyperlegible"),
          Block.license(read.("assets/fonts/OFL-atkinsonhyperlegible.txt")),
          Block.space,
          Block.buttons([[:close, "Done", true]])
        ]
      end
    end
  end
end
