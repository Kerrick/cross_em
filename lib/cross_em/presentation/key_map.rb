# frozen_string_literal: true

module CrossEm
  module Presentation
    # What each key does on the Play screen, for a player at a keyboard.
    # A key is turned into a named action (:reset, :give_up, :shuffle,
    # [:type, "C"] ...), which Play#act carries out, so any other input
    # can reach the same actions by name. Letters build a word (Typing),
    # so every other action is on a key that isn't a letter, or on a
    # letter with Ctrl (Cmd on a Mac).
    #
    #   A-Z               type a word
    #   Enter, Space      place it; with nothing typed, Enter goes on from
    #                     the results (the next puzzle, or back to today)
    #   Tab, arrows       while choosing: the next place (Shift+Tab, Up
    #                     and Left the one before); with nothing typed,
    #                     the arrows move the focus ring by direction and
    #                     Tab jumps between the header, the board, the
    #                     pool and the buttons (FocusMap)
    #   Enter, Space      with nothing typed, once the focus ring shows:
    #                     what a click on the focus would do
    #   1-9               while choosing: place it there
    #   Backspace         the last letter typed; with nothing typed, takes
    #                     back the last word placed (then the one before)
    #   Esc               back from choosing, clears what is typed, puts
    #                     down a letter picked up, or closes a sheet
    #   Space             with nothing typed: Shuffle
    #   Shift+Backspace   Reset (Ctrl/Cmd+Backspace too)
    #   Shift+Esc         Give up, pressed twice
    #   Shift+Enter       Play again, once the game is over
    #   Ctrl/Cmd+T        back to today from practice or a look back
    #   Ctrl/Cmd+P        Past puzzles
    #   ?, F1             How to play (and C in it: Credits)
    #   Ctrl/Cmd+D        the page's appearance, light or dark
    #   Ctrl/Cmd+S        sound on or off
    #   Ctrl/Cmd+C        copies the result once the game is over
    #
    # In Past puzzles, Up and Down move from day to day, Page Up, Page
    # Down, Home and End further, and Enter opens the day. In the other
    # sheets the arrows move the focus among their controls, scrolling
    # when there is none that way, and Tab steps through them.
    module KeyMap
      # The keys each named action is on, as keycaps to show beside its
      # button: a String is a key's label, :return and :backspace are
      # drawn, and :command is Ctrl, or Cmd on a Mac. Only the first way
      # to an action is shown.
      KEYCAPS = {
        shuffle: ["Space"], reset: ["Shift", :backspace], give_up: ["Shift", "Esc"], again: ["Shift", :return],
        today: [:command, "T"], archive: [:command, "P"], help: ["?"], credits: ["C"], theme: [:command, "D"],
        sound: [:command, "S"], copy: [:command, "C"], next: [:return]
      }.freeze

      # Ctrl/Cmd with these letters, by the action they name.
      COMMANDS = {t: :today, p: :archive, d: :theme, s: :sound, c: :copy}.freeze

      module_function

      def text(play, text) = (action = text_action(play, text)) && play.act(*action)

      def key(play, key, command: false, shift: false)
        action = key_action(play, key, command:, shift:)
        play.act(*action) if action
      end

      # The action typed +text+ names: [name, argument], or nil.
      def text_action(play, text)
        return [:help] if text == "?"
        return [:credits] if play.sheet&.kind == :help && text.casecmp?("c")
        return if play.sheet?

        if text.match?(/\A[1-9]\z/) then [:choose, Integer(text)]
        elsif (letter = text.upcase).match?(/\A[A-Z]\z/) then [:type, letter]
        end
      end

      # The action +key+ names, with the modifiers held: [name] or
      # [name, argument], or nil.
      def key_action(play, key, command: false, shift: false)
        return [:help] if key == :f1
        return [COMMANDS[key]] if command && COMMANDS.key?(key)
        return sheet_action(play, key, shift:) if play.sheet?

        case key
        when :escape then shift ? [:give_up] : [:escape]
        when :return, :kpenter then shift ? [:again] : (focus?(play) ? [:activate] : [:enter])
        when :space then focus?(play) ? [:activate] : [:space]
        when :backspace, :delete then shift || command ? [:reset] : [:erase]
        when :tab then typing?(play) ? [:cycle, shift ? -1 : 1] : [:hop, shift ? -1 : 1]
        when :up, :left then typing?(play) ? [:cycle, -1] : [:move, key]
        when :down, :right then typing?(play) ? [:cycle, 1] : [:move, key]
        end
      end

      # Whether a word is being typed, or its places chosen among: then
      # Tab and the arrows are the word's (Typing#cycle), not the focus's.
      def typing?(play) = play.typing.drafting? || play.typing.choosing?

      # Whether Enter and Space act on the focus: once its ring shows, and
      # with nothing typed. Until then they place a word, shuffle, or go
      # on from the results, as they always have.
      def focus?(play) = play.focus_visible? && !typing?(play)

      def sheet_action(play, key, shift: false)
        return archive_action(play, key, shift:) if play.sheet.kind == :archive

        case key
        when :escape then [:close]
        when :return, :kpenter then play.focus_visible? ? [:activate] : [:close]
        when :space then [:activate] if play.focus_visible?
        when :up, :down, :left, :right then [:move, key]
        when :tab then [:hop, shift ? -1 : 1]
        when :pageup, :pagedown, :home, :end then [:scroll, key]
        end
      end

      # Past puzzles: the arrows move from day to day, Page Up and Page
      # Down a page, Home and End to the newest and the oldest, and Enter
      # opens the day (or, with the ring on it, closes the sheet). Up from
      # today reaches the close button.
      def archive_action(play, key, shift: false)
        case key
        when :escape then [:close]
        when :return, :kpenter, :space then play.focus_visible? ? [:activate] : (key == :space ? nil : [:open_day])
        when :up, :down then [:move, key]
        when :tab then [:hop, shift ? -1 : 1]
        when :pageup, :pagedown, :home, :end then [:focus, key]
        end
      end

      # Scrolls a sheet for +key+.
      def scroll(play, key)
        step = case key
               when :up, :down then play.units.px(40)
               when :pageup, :pagedown then play.units.px(300)
               else play.sheet_layout.content_height
               end
        play.scroll_sheet(%i[up pageup home].include?(key) ? -step : step)
      end

      # Moves the keyboard's place in Past puzzles for +key+.
      def focus(play, key)
        case key
        when :up, :down then play.move_focus(key == :up ? -1 : 1)
        when :pageup, :pagedown then play.move_focus(key == :pageup ? -play.focus_page : play.focus_page)
        else play.move_focus(key)
        end
      end
    end
  end
end
