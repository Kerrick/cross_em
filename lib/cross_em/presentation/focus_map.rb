# frozen_string_literal: true

module CrossEm
  module Presentation
    # What the focus can rest on in each state of the Play screen, and
    # what moving it and acting on it do. The regions, in order: the
    # header, the board, the pool, and the controls (or, once the game is
    # over, the results); with a sheet open, the sheet alone.
    #
    # Only what a tap would do something to is a target: pool letters
    # while the game is played; on the board, its letters, and the
    # glowing squares while a letter is picked up (or the first square,
    # on an empty board); live buttons; a sheet's close button, its
    # title-bar button and its controls; in Past puzzles, the days.
    module FocusMap
      # Where the focus may land first, on the main screen and in a sheet.
      SHEET_DEFAULT = [[:sheet, :close]].freeze

      module_function

      # Every Target on the screen now, region by region.
      def targets(play)
        return sheet_targets(play) if play.sheet?

        [*header(play), *board(play), *pool(play), *panel(play)]
      end

      # The targets the stick's cursor can rest on: those in sight, each
      # cut to the part of it that is (a board cell to the board, a
      # sheet's control to its body), so the cursor over the pool is
      # never over a cell half out of the board.
      def pointable(play)
        targets(play).select(&:shown).map do |target|
          clip = case target.region
                 when :board then play.view.viewport
                 when :help, :credits then play.sheet_layout.body if body?(play, target)
                 end
          clip ? target.with(rect: target.rect.intersect(clip)) : target
        end
      end

      # Whether +target+ is one of a sheet's controls that scroll with its
      # body.
      def body?(play, target) = play.sheet_layout.controls.any? { [:control, it.id] == target.id }

      # Where the focus starts when it has never been anywhere: the
      # first letter in the pool; once the game is over, the results'
      # main button; in a sheet, its close button, or in Past puzzles the
      # day the keyboard is on.
      def default(play)
        if play.sheet?
          focus = play.sheet.focus
          return focus ? [[:day, focus], *SHEET_DEFAULT] : SHEET_DEFAULT
        end

        game = play.game
        slot = game.playing? && game.pool.slots.each_index.find { game.pool.letter?(it) }
        [([:slot, slot] if slot), [:button, :next], [:button, play.primary], [:button, :give_up]].compact
      end

      # The first focus in each region, the first time it is jumped to:
      # on the board, a glowing square while a letter is in hand.
      def firsts(play)
        targets = play.game.selected ? play.game.board.targets.min : nil
        targets ? {board: [:cell, targets]} : {}
      end

      # Neighbours spatial navigation would get wrong, pinned:
      # {[id, direction] => id}. See doc/design.md, Controllers.
      #
      # On the results, the clock is not a target until it runs out, so
      # nothing is straight above "Play again" but the header, far off
      # past the board; the share button, up and to the right, is the
      # results' own. Likewise down from the share button, beside the
      # clock, "Past puzzles" is under it and in line, so needs no pin.
      def pins(play)
        results = play.layout.results
        return {} if results.nil? || play.sheet? || play.next_day
        return {} unless results.again.y > results.copy.y

        {[[:button, :again], :up] => [:button, play.primary]}
      end

      # Regions measured by more than their targets: the board by its
      # whole room, whatever few cells can be focused in it.
      def bounds(play) = {board: play.view.viewport}

      def header(play)
        layout = play.layout
        today = play.practice? || play.review? ? [Target.new(id: [:button, :today], region: :header, rect: layout.wordmark)] : []
        today + layout.header_buttons.map { |name, rect| Target.new(id: [:button, name], region: :header, rect:) }
      end

      # The board's letters and, with a letter in hand, its glowing
      # squares (an empty board's one square always), on the camera's
      # resting view. A cell out of sight is not +shown+.
      def board(play)
        game = play.game
        return [] unless game.playing?

        cells = game.board.positions
        cells += game.board.targets.sort if game.selected || game.board.empty?
        view = play.view
        cells.uniq.map do |position|
          rect = view.rect_of(position)
          Target.new(id: [:cell, position], region: :board, rect:,
                     shown: view.viewport.contains?(rect.center_x, rect.center_y))
        end
      end

      def pool(play)
        game = play.game
        return [] unless game.playing?

        play.layout.pool.each_with_index.filter_map do |rect, index|
          Target.new(id: [:slot, index], region: :pool, rect:) if game.pool.letter?(index)
        end
      end

      def panel(play)
        layout = play.layout
        if (results = layout.results)
          buttons = [([:next, results.countdown] if play.next_day && play.countdown?), [play.primary, results.copy],
                     [:again, results.again], [:archive, results.archive]].compact
          return buttons.map { |name, rect| Target.new(id: [:button, name], region: :results, rect:) }
        end

        layout.controls.each.filter_map do |name, rect|
          Target.new(id: [:button, name], region: :controls, rect:) if play.enabled?(name)
        end
      end

      # A sheet's close button, its title-bar button, and its controls
      # where they are scrolled to, those out of the body's sight not
      # +shown+; or Past puzzles' close button and its days in view.
      def sheet_targets(play)
        sheet = play.sheet
        layout = play.sheet_layout
        region = sheet.kind
        close = Target.new(id: [:sheet, :close], region:, rect: layout.close)
        return [close, *days(play, layout, sheet)] if region == :archive

        link = layout.link && Target.new(id: [:control, layout.link.id], region:, rect: layout.link.rect)
        body = layout.body
        controls = layout.controls.map do |control|
          rect = control.rect.offset(body.x, body.y - sheet.scroll)
          Target.new(id: [:control, control.id], region:, rect:,
                     shown: rect.y >= body.y && rect.bottom <= body.bottom)
        end
        [close, link, *controls].compact
      end

      # The days in view, below the pinned month heading, and the day the
      # keyboard is on wherever it is.
      def days(play, layout, sheet)
        pinned = layout.pinned(sheet.scroll)&.last
        rows = layout.visible(sheet.scroll).select(&:day?)
        rows |= [layout.list.day_row(sheet.focus)].compact if sheet.focus
        rows.map do |row|
          rect = layout.row_rect(row, sheet.scroll)
          shown = rect.y >= (pinned&.bottom || layout.body.y) && rect.bottom <= layout.body.bottom
          Target.new(id: [:day, row.number], region: :archive, rect:, shown:)
        end
      end

      # Moves +ring+ towards +direction+ on +play+'s screen. In a sheet
      # whose body scrolls, a control out of sight that way is scrolled
      # to, a step at a time, and with nothing that way the body scrolls.
      # Answers the Target focused after, or nil.
      def move(play, ring, direction)
        return archive_move(play, ring, direction) if play.sheet&.kind == :archive
        return sheet_move(play, ring, direction) if play.sheet?

        ring.move(targets(play), direction, pins: pins(play), default: default(play), bounds: bounds(play))
      end

      # Jumps +by+ regions; in a sheet, to the next control in reading
      # order (wrapping), scrolled into view.
      def hop(play, ring, by)
        targets = targets(play)
        return ring.hop(targets, by, firsts: firsts(play), default: default(play)) unless play.sheet?

        from = ring.current(targets, default: default(play)) or return
        to = targets[(targets.index(from) + by) % targets.size]
        reveal(play, to)
        ring.focus(to)
      end

      def sheet_move(play, ring, direction)
        targets = targets(play)
        from = ring.current(targets, default: default(play)) or return
        to = Spatial.pick(from.rect, direction, targets - [from])
        layout = play.sheet_layout
        if to&.shown
          play.scroll_sheet(reveal_by(layout, to.rect.outset(play.units.px(8)))) if body?(play, to)
          return ring.focus(to)
        end

        step = [layout.body.height / 3, play.units.px(40)].max
        if to && (needed = reveal_by(layout, to.rect.outset(play.units.px(8)))).abs <= step
          play.scroll_sheet(needed)
          return ring.focus(to)
        end
        play.scroll_sheet(%i[up left].include?(direction) ? -step : step) if %i[up down].include?(direction)
        from
      end

      # How far a sheet's body must scroll to bring +rect+ wholly into
      # sight.
      def reveal_by(layout, rect)
        body = layout.body
        if rect.y < body.y then rect.y - body.y
        elsif rect.bottom > body.bottom then rect.bottom - body.bottom
        else 0
        end
      end

      def reveal(play, target)
        return unless play.sheet? && play.sheet.kind != :archive && !target.shown

        play.scroll_sheet(reveal_by(play.sheet_layout, target.rect.outset(play.units.px(8))))
      end

      # Past puzzles: Up and Down walk the days (KeyMap.focus), up from
      # today to the close button and down from it back to the days.
      # Left and right go nowhere.
      def archive_move(play, ring, direction)
        on_close = ring.visible? && ring.id == [:sheet, :close] && ring.region == :archive
        case direction
        when :down
          on_close && play.sheet.focus ? play.move_focus(0) : play.move_focus(1)
        when :up
          return ring.current(targets(play), default: default(play)) if on_close
          if play.sheet.focus == play.archive_list.today.number
            return ring.focus(targets(play).find { it.id == [:sheet, :close] })
          end

          play.move_focus(-1)
        else return ring.current(targets(play), default: default(play))
        end
        day_focus(play, ring)
      end

      # Points the ring at the day Past puzzles' keyboard is on.
      def day_focus(play, ring)
        number = play.sheet&.focus or return
        target = targets(play).find { it.id == [:day, number] }
        target && ring.focus(target)
      end

      # Does what a tap on +target+ would.
      def activate(play, target)
        case target.id
        in [:slot, index] then play.pick(index)
        in [:cell, position] then play.tap_cell(position)
        in [:button, name] then play.press_button(name) if play.enabled?(name)
        in [:sheet, :close] then play.close_sheet
        in [:control, id] then play.sheet_control(id)
        in [:day, number] then play.open_day(number)
        end
      end
    end
  end
end
