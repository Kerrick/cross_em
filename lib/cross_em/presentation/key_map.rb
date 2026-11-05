# frozen_string_literal: true

module CrossEm
  module Presentation
    # What each key does on the Play screen, for a player at a keyboard.
    # Typed letters build a word (Typing), which Enter or Space places;
    # when it fits several places, Tab or the arrows show each and 1 to 9
    # pick one. Named keys otherwise edit, take back, shuffle, copy,
    # scroll a sheet and move on.
    #
    #   A-Z           type a word
    #   Enter, Space  place it (with nothing typed: Enter plays the next
    #                 puzzle when it is ready, Space shuffles)
    #   Backspace     the last letter typed; with nothing typed, takes
    #                 back the last word placed (then the one before)
    #   Esc           back from choosing, clears what is typed, puts down
    #                 a letter picked up, or closes a sheet
    #   Tab, arrows   while choosing: the next place (Shift+Tab, Up and
    #                 Left the one before); on a sheet, arrows scroll
    #   1-9           while choosing: place it there
    #   ?             How to play
    #   Ctrl/Cmd+C    copies the result once the game is over
    module KeyMap
      module_function

      def text(play, text)
        return play.toggle_help if text == "?"
        return if play.sheet?

        if text.match?(/\A[1-9]\z/) then play.typing.choose(Integer(text))
        elsif (letter = text.upcase).match?(/\A[A-Z]\z/) then play.typing.type(letter)
        end
      end

      def key(play, key, command: false, shift: false)
        return sheet_key(play, key) if play.sheet? && key != :c

        case key
        when :escape then play.escape
        when :c then play.copy if command && play.game.over?
        when :return, :kpenter then play.enter
        when :space then play.space
        when :backspace, :delete then play.erase
        when :tab then play.typing.cycle(shift ? -1 : 1)
        when :up, :left then play.typing.cycle(-1)
        when :down, :right then play.typing.cycle(1)
        end
      end

      def sheet_key(play, key)
        case key
        when :escape, :return, :kpenter then play.close_sheet
        when :up, :pageup, :down, :pagedown, :home, :end then scroll(play, key)
        end
      end

      def scroll(play, key)
        step = case key
               when :up, :down then play.units.px(40)
               when :pageup, :pagedown then play.units.px(300)
               else play.sheet_layout.content_height
               end
        play.scroll_sheet(%i[up pageup home].include?(key) ? -step : step)
      end
    end
  end
end
