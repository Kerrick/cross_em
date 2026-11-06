# frozen_string_literal: true

module CrossEm
  module Presentation
    # Every word the game says, and there are few. In play the board, the
    # tiles and their marks show what can be done (doc/design.md, Words):
    # words are kept for what nothing else can say: buttons, which name
    # their action, the result's heading, a problem's reason, counts,
    # dates and the clock, How to play and the Credits.
    module Copy
      SHUFFLE = "Shuffle"
      RESET = "Reset"
      GIVE_UP = "Give up"
      CONFIRM_GIVE_UP = "Give up?"
      CREDITS = "Credits"
      COPY_RESULT = "Copy result"
      COPIED = "Copied"
      COPY_FAILED = "Couldn't copy"
      NEXT_PUZZLE = "Next puzzle"
      PLAY_AGAIN = "Play again"
      ARCHIVE = "Past puzzles"
      BACK_TO_TODAY = "Back to today"
      PRACTICE = "Practice"
      REVIEW = "Your board"
      WON = "Solved!"
      LOST = "Game over"
      TODAY = "Today"
      STAT_LABELS = ["Played", "Win %", "Streak", "Best streak"].freeze

      # What a typed word that fits nowhere says, beside its marks, when
      # its letters are all there (a missing letter is marked on the
      # draft and needs no words).
      MISFITS = {on_board: "Already there", nowhere: "No room"}.freeze

      # The header's buttons, named in a tooltip when the mouse rests on
      # one, as what a click does.
      TIPS = {archive: "Past puzzles", help: "How to play", light: "Light page", dark: "Dark page",
              mute: "Sound off", unmute: "Sound on", today: BACK_TO_TODAY}.freeze

      # How to play's picture: WORD across, and ROW down from its R.
      EXAMPLE = [["W", 0, 0], ["O", 1, 0], ["R", 2, 0], ["D", 3, 0], ["O", 2, 1], ["W", 2, 2]].freeze

      # The credit the word list asks for, word for word.
      WORD_LIST_CREDIT = "Word list based on SCOWL by Kevin Atkinson and the sources it credits, including ENABLE " \
                         "and the UK Advanced Cryptics Dictionary, Copyright (c) J Ross Beresford 1993-1999. All " \
                         "Rights Reserved."

      module_function

      def number(day) = "No. #{day.number}"

      # A day's date as the archive lists it: "Thu 5 Nov 2026".
      def date(date) = date.strftime("%a %-d %b %Y")
      def month(date) = date.strftime("%B %Y")

      def play_number(day) = "Play No. #{day.number}"

      # A count out of the twelve letters, as the archive and the results
      # show it beside their glyphs: "7/12".
      def tally(count) = "#{count}/#{Rules::LETTER_COUNT}"

      # Which place a typed word is shown in, of how many: "1/3".
      def of(index, size) = "#{index + 1}/#{size}"

      def heading(game) = game.won? ? WON : LOST

      # The misfit's few words, or nil when the draft's marks say it.
      def misfit(misfit) = misfit && MISFITS[misfit.reason]

      # Why each problem word is one, as briefly as it can be said, in
      # reading order: "AZ: too short", "TCA: not a word", "DOG: not
      # joined", "Q: alone". A word whose letters are problems only
      # because a bad word crosses it is not blamed.
      def reasons(check)
        check.words.map do |problem|
          word = problem.word
          case problem.reason
          when :too_short then word.length == 1 ? "#{word}: alone" : "#{word}: too short"
          when :not_a_word then "#{word}: not a word"
          else "#{word}: not joined"
          end
        end.uniq
      end

      # How to play, as Sheet blocks: every rule, then the settings, in
      # the verbs of the player's device (tap on a touch screen, click
      # with a mouse). The Credits are a button in the title bar.
      def instructions(touch:)
        tap = touch ? "Tap" : "Click"
        [
          Block.body("Make connected words, crossword style, from the day's twelve letters. " \
                     "There are new letters every day."),
          Block.example(EXAMPLE, [3, 1]),
          Block.small("WORD and ROW cross at the R. The glowing square is a place the next letter can go."),
          Block.space,
          Block.bullet("#{tap} a letter in the pool to pick it up, then #{tap.downcase} a glowing square on the grid " \
                       "to place it."),
          Block.bullet("#{tap} a placed letter to send it back to the pool."),
          Block.bullet("Every word, across and down, must be a real word of 3 letters or more, " \
                       "and all of them must be connected. Words are checked once all twelve letters are down."),
          Block.bullet("Use as many letters as you can. The game ends when all twelve are used in good words, " \
                       "or when you give up."),
          Block.bullet("Shuffle mixes up the pool. Reset sends every letter back."),
          (Block.bullet("On a keyboard, type a word and press Enter to place it. A hatched letter is one you " \
                        "don't have. If the word fits more than one place, Tab shows each. Backspace takes back " \
                        "the last word. Every button shows its keys.") unless touch),
          Block.space,
          Block.toggle(:calm, "Calm motion", "Gentle fades instead of flights and bounces."),
          Block.space,
          Block.buttons([[:close, "Play", true]])
        ].compact
      end

      # The credits, as Sheet blocks: the game's own first, then the word
      # list's (its credit, word for word, then its whole copyright
      # file), Lota's and LÖVE's, and the fonts', from the files that ship
      # with the game: +read+ takes a file's path in the game folder and
      # answers its text, which is shown unmodified.
      def credits(read)
        [
          Block.heading("Cross ’em"),
          Block.body("A remake of a daily word puzzle, by Kerrick Long, made in Ruby. Free software under the " \
                     "GNU Affero General Public License 3.0 or later."),
          Block.heading("Word list"),
          Block.small(WORD_LIST_CREDIT),
          Block.license(read.("wordlist-COPYRIGHT.txt")),
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
