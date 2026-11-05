# frozen_string_literal: true

module CrossEm
  module Presentation
    # What each key does on the Play screen: everything a tap can do, for
    # a player at a keyboard. Typed text picks up letters; named keys put
    # them down, take them back, shuffle, copy, scroll a sheet and move on.
    module KeyMap
      module_function

      # Typed text: a letter picks up that letter (again, the next one of
      # the same letter, or puts it down), and "?" opens How to play.
      def text(play, text)
        return play.toggle_help if text == "?"
        return if play.sheet?

        letter = text.upcase
        play.pick_letter(letter) if letter.match?(/\A[A-Z]\z/)
      end

      def key(play, key, command: false)
        case key
        when :escape then play.escape
        when :c then play.copy if command && play.game.over?
        when :return, :kpenter then play.sheet? ? play.close_sheet : play.next_puzzle
        when :space then play.press_button(:shuffle) unless play.sheet?
        when :backspace, :delete then play.take_back unless play.sheet?
        when :up, :pageup, :down, :pagedown then scroll(play, key)
        end
      end

      def scroll(play, key)
        return unless play.sheet?

        step = play.units.px(%i[up down].include?(key) ? 40 : 300)
        play.scroll_sheet(%i[up pageup].include?(key) ? -step : step)
      end
    end
  end
end
