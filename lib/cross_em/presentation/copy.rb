# frozen_string_literal: true

module CrossEm
  module Presentation
    # Every word the game says. The status line always says what the
    # player can do next, in the state they are in; buttons name their
    # action. Nothing else in the presentation spells out a sentence.
    module Copy
      PICK = "Tap a letter to pick it up."
      PLACE = "Now tap a glowing square to place it."
      SHUFFLE = "Shuffle"
      RESET = "Reset"
      GIVE_UP = "Give up"
      CONFIRM_GIVE_UP = "Give up? Tap again"
      COPY_RESULT = "Copy result"
      COPIED = "Copied"
      COPY_FAILED = "Couldn't copy"
      COPIED_NOTE = "Copied. Paste it anywhere."
      NEXT_PUZZLE = "Next puzzle in"
      WON = "Solved!"
      LOST = "Game over"
      STAT_LABELS = ["Played", "Win %", "Streak", "Best streak"].freeze

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

      def status(game, dictionary)
        if game.won? then Status.new(text: WON, detail: "All #{Rules::LETTER_COUNT} letters crossed.", tone: :won)
        elsif game.lost? then Status.new(text: LOST, detail: crossed(game), tone: :lost)
        elsif game.selected then Status.new(text: PLACE)
        elsif game.check && !game.check.clean?
          count = game.check.count
          Status.new(text: "#{letters(count)} #{count == 1 ? 'needs' : 'need'} fixing. Tap one to send it back.",
                     reasons: reasons(game.board, game.check, dictionary), tone: :problem)
        elsif game.board.empty? then Status.new(text: PICK)
        else
          Status.new(text: PICK, detail: "#{letters(game.pool.unused_count)} left. Tap a placed one to send it back.")
        end
      end

      # The good news after a loss: how many letters ended up in good
      # words.
      def crossed(game) = "#{game.good_letters} of #{Rules::LETTER_COUNT} letters crossed."

      # Why each problem is one, a sentence fragment a word, in reading
      # order: "AZ is too short", "TCA isn't in the word list", "DOG isn't
      # connected". A word whose letters are problems only because of a
      # word crossing it is not listed; that word is.
      def reasons(board, check, dictionary)
        board.words.sort_by { it.positions.first }.filter_map do |word|
          next unless word.positions.any? { check.problem?(it) }

          if word.length == 1 then "#{word} is on its own"
          elsif word.length < Rules::MINIMUM_WORD_LENGTH then "#{word} is too short"
          elsif !dictionary.include?(word.text) then "#{word} isn't in the word list"
          elsif word.positions.all? { check.reason(it) == :disconnected } then "#{word} isn't connected"
          end
        end.uniq
      end

      # How to play, as Sheet blocks: every rule, then the settings and
      # the word list's credit.
      def instructions(touch:)
        [
          Block.body("Make connected words, crossword style, from the day's twelve letters. " \
                     "There are new letters every day."),
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
          Block.small(WORD_LIST_CREDIT),
          Block.space,
          Block.buttons([[:credits, "Credits", false], [:close, "Play", true]])
        ].compact
      end

      # The credits, as Sheet blocks, from the files that ship with the
      # game: +read+ takes a file's path in the game folder and answers its
      # text, which is shown unmodified.
      def credits(read)
        [
          Block.heading("Cross ’em"),
          Block.body("A daily word puzzle, made in Ruby. Free software under the GNU Affero General Public " \
                     "License 3.0."),
          Block.heading("Built with Lota and LÖVE"),
          Block.body("Lota, Ruby bindings for LÖVE, by Kerrick Long, under the GNU Affero General Public " \
                     "License 3.0 or later."),
          Block.body("LÖVE, the free 2D game framework, copyright (c) 2006-2026 LÖVE Development Team, under " \
                     "the zlib license."),
          Block.heading("Word list"),
          Block.small(WORD_LIST_CREDIT),
          Block.license(read.("wordlist-COPYRIGHT.txt")),
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
