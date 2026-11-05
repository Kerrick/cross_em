# frozen_string_literal: true

module CrossEm
  module Presentation
    # What a press, a drag, a release and a scroll do on the Play screen.
    # A press on a pool letter picks it up at once; a press anywhere else
    # becomes a tap when it is released without having moved far, or a
    # drag that pans the board or scrolls a sheet. One pointer at a time.
    class PointerMap
      M = Look::METRICS

      attr_reader :gesture

      def initialize(play)
        @play = play
        @gesture = nil
      end

      # Lets go of any press, as when a new day's game opens.
      def cancel = @gesture = nil

      def pointer(event)
        case event.phase
        when :pressed then press(event)
        when :moved then move(event)
        when :released then release(event)
        end
      end

      def press(pointer)
        return if @gesture

        target = target_at(pointer.x, pointer.y)
        @gesture = Gesture.start(pointer, target)
        @play.pick(target[1]) if target[0] == :slot
      end

      def move(pointer)
        return unless @gesture&.id == pointer.id

        before = @gesture
        @gesture = before.moved(pointer.x, pointer.y, @play.units.px(M.drag))
        return unless @gesture.dragging

        from_x, from_y = before.dragging ? [before.x, before.y] : [before.start_x, before.start_y]
        drag(@gesture.target, pointer.x - from_x, pointer.y - from_y)
      end

      def release(pointer)
        return unless @gesture&.id == pointer.id

        gesture = @gesture.moved(pointer.x, pointer.y, @play.units.px(M.drag))
        @gesture = nil
        tapped(gesture) if gesture.tap?
      end

      # A mouse wheel or a trackpad's two fingers: scrolls a sheet, or pans
      # the board.
      def wheel(dx, dy)
        step = @play.units.px(40)
        if @play.sheet? then @play.scroll_sheet(-dy * step)
        else @play.pan(-dx * step, dy * step)
        end
      end

      # What the mouse pointer should look like over (+x+, +y+): a hand
      # over anything a click would do something to, a four-way arrow over
      # a board that pans, else the arrow.
      def cursor_at(x, y)
        case target_at(x, y)
        in [:button, name] then @play.enabled?(name) ? :hand : :arrow
        in [:slot, index] then @play.game.playing? && @play.game.pool.letter?(index) ? :hand : :arrow
        in [:board] then board_cursor(@play.shown_view.cell_at(x, y))
        in [:sheet, :close | :scrim | :link] then :hand
        in [:sheet, :body] then @play.sheet_layout.control_at(x, y, @play.sheet.scroll) ? :hand : :arrow
        else :arrow
        end
      end

      private

      # What is under (+x+, +y+): a sheet's part while one is open, else a
      # button, a pool slot, the board, or nothing.
      def target_at(x, y)
        return sheet_target_at(x, y) if @play.sheet?

        @play.layout.header_buttons.each { |name, rect| return [:button, name] if rect.contains?(x, y) }
        @play.layout.controls&.each { |name, rect| return [:button, name] if rect.contains?(x, y) }
        if (results = @play.layout.results)
          return [:button, @play.primary] if results.copy.contains?(x, y)
          return [:button, :again] if results.again.contains?(x, y)
          return [:button, :archive] if results.archive.contains?(x, y)
          return [:button, :next] if results.countdown.contains?(x, y) && @play.next_day
        end
        @play.layout.pool.each_with_index { |rect, i| return [:slot, i] if rect.contains?(x, y) }
        return [:board] if @play.layout.board.contains?(x, y)

        [:none]
      end

      def sheet_target_at(x, y)
        sheet = @play.sheet_layout
        if sheet.close.contains?(x, y) then [:sheet, :close]
        elsif sheet.link&.rect&.contains?(x, y) then [:sheet, :link]
        elsif sheet.body.contains?(x, y) then [:sheet, :body]
        elsif sheet.card.contains?(x, y) then [:sheet, :card]
        else [:sheet, :scrim]
        end
      end

      def board_cursor(cell)
        game = @play.game
        if game.playing? && cell && (game.selected ? game.board.target?(cell) : game.board.occupied?(cell)) then :hand
        elsif @play.shown_view.pannable? then :sizeall
        else :arrow
        end
      end

      def drag(target, dx, dy)
        case target
        in [:board] then @play.pan(dx, dy)
        in [:sheet, _] then @play.scroll_sheet(-dy)
        else nil
        end
      end

      def tapped(gesture)
        case gesture.target
        in [:board] then @play.tap_cell(@play.shown_view.cell_at(gesture.start_x, gesture.start_y))
        in [:button, name] then @play.press_button(name) if target_at(gesture.x, gesture.y) == gesture.target
        in [:sheet, :close | :scrim] then @play.close_sheet
        in [:sheet, :link] then sheet_control(@play.sheet_layout.link.id)
        in [:sheet, :body]
          control = @play.sheet_layout.control_at(gesture.x, gesture.y, @play.sheet.scroll)
          sheet_control(control.id) if control
        else nil
        end
      end

      def sheet_control(id)
        case id
        in [:day, number] then @play.open_day(number)
        in :close then @play.close_sheet
        in :credits then @play.open(:credits)
        else @play.toggle(id)
        end
      end
    end
  end
end
