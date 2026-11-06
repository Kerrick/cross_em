# frozen_string_literal: true

module CrossEm
  module Presentation
    # A controller's button, drawn beside a button's label as a keycap
    # is at a keyboard: +button+ by SDL's name for it (:a, :leftshoulder,
    # :back ...), in the +family+'s style (:xbox, :playstation or
    # :nintendo).
    class PadGlyph < Data.define(:button, :family)
      # What is printed on it: a letter or a short name, or a Symbol for
      # a shape drawn instead (:cross, :circle, :square, :triangle, :view,
      # :menu).
      def label = PadMap.label(button, family)

      # Round, as a face button is, or a pill, as a bumper or Back is.
      def round? = %i[a b x y].include?(button)
    end

    # What each button on a game controller does on the Play screen. A
    # button is turned into one of the named actions KeyMap's keys name
    # (:shuffle, :give_up, :escape ...) or the focus's own (:move,
    # :hop, :activate, :page), which Play#act carries out, so the
    # controller reaches every action the same way a key or a click
    # does, and only when its button is live.
    #
    #   D-pad             moves the focus by direction; while a typed
    #                     word's places are shown, the next or the one
    #                     before
    #   A                 the focused thing: picks up or places a letter,
    #                     sends one back, presses a button, opens a day;
    #                     places a typed word
    #   B                 back: puts down a letter picked up, goes back
    #                     from choosing a place, closes a sheet
    #   X                 Shuffle; once the game is over, Play again
    #   Y                 Give up, pressed twice; once the game is over,
    #                     Copy result
    #   Back (View)       Reset
    #   Start (Menu)      How to play
    #   LB, RB            the region before or after: the header, the
    #                     board, the pool, the buttons; in a sheet, a page
    #                     up or down
    #   Left stick        a cursor that settles on the nearest thing
    #   Right stick       pans the board, or scrolls a sheet
    #
    # SDL names the buttons by where they are on an Xbox controller, so
    # :a is always the bottom face button; GLYPHS label it as the player's
    # own controller does.
    module PadMap
      # The button each action is on, to show beside its button while a
      # controller is in use. As with keycaps, only the first way to an
      # action is shown; A, which acts on whatever is focused, is not.
      GLYPHS = {shuffle: :x, again: :x, give_up: :y, copy: :y, reset: :back, help: :start}.freeze

      # What each family prints on its buttons. SDL's names are by
      # position, so on a Nintendo controller the bottom button (:a) is
      # labelled B, and the left one (:x) Y.
      LABELS = {
        xbox: {a: "A", b: "B", x: "X", y: "Y", leftshoulder: "LB", rightshoulder: "RB", back: :view, start: :menu},
        playstation: {a: :cross, b: :circle, x: :square, y: :triangle, leftshoulder: "L1", rightshoulder: "R1",
                      back: :view, start: :menu},
        nintendo: {a: "B", b: "A", x: "Y", y: "X", leftshoulder: "L", rightshoulder: "R", back: "−", start: "+"}
      }.freeze

      DIRECTIONS = {dpup: :up, dpdown: :down, dpleft: :left, dpright: :right}.freeze

      module_function

      # The family a controller of SDL's gamepad type +type+ (as
      # Joystick#gamepad_type gives it: :ps5, :switchpro, :xboxone ...)
      # belongs to, for its glyphs. Anything unknown looks like an Xbox
      # controller, whose names SDL uses.
      def family(type)
        name = type.to_s
        if name.start_with?("ps") then :playstation
        elsif name.start_with?("switch", "joycon") then :nintendo
        else :xbox
        end
      end

      def label(button, family) = LABELS.fetch(family, LABELS[:xbox]).fetch(button, button.to_s.upcase)

      def press(play, button)
        action = action(play, button)
        play.act(*action) if action
      end

      # The action +button+ names: [name] or [name, argument], or nil.
      def action(play, button)
        if (direction = DIRECTIONS[button])
          return play.typing.choosing? && !play.sheet? ? [:cycle, %i[up left].include?(direction) ? -1 : 1] : [:move, direction]
        end

        case button
        when :a then typing?(play) ? [:enter] : [:activate]
        when :b then [:escape]
        when :start then [:help]
        when :leftshoulder, :rightshoulder
          by = button == :leftshoulder ? -1 : 1
          play.sheet? ? [:page, by] : [:hop, by]
        else play.sheet? ? nil : game_action(play, button)
        end
      end

      # A word typed at a keyboard, or its places being chosen among: A
      # places it, as Enter would.
      def typing?(play) = !play.sheet? && (play.typing.drafting? || play.typing.choosing?)

      def game_action(play, button)
        over = play.game.over?
        case button
        when :x then over ? [:again] : [:shuffle]
        when :y then over ? [:copy] : [:give_up]
        when :back then over ? nil : [:reset]
        end
      end

      # The glyphs to show beside +name+'s button, for +family+, or nil.
      def glyphs(name, family)
        button = GLYPHS[name] or return
        [PadGlyph.new(button:, family:)]
      end
    end
  end
end
