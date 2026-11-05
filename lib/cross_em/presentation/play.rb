# frozen_string_literal: true

module CrossEm
  module Presentation
    # The Play screen's state and what a tap, a drag, a scroll or a key
    # does to it. It owns no window: the shell tells it the window's size
    # and hands it the player's pointers and keys, and it changes the
    # Game, opens and closes the sheets, and asks its +host+ for whatever
    # reaches outside the screen: sounds, the clipboard, the settings
    # file, the appearance, the next day's game.
    #
    # The rules change on the tap. Nothing here waits for an animation.
    class Play
      M = Look::METRICS
      T = Look::TIMING

      attr_reader :game, :settings, :gesture, :time, :units, :motion

      # +host+ answers sound(name), copy(text) (true if it worked),
      # settings_changed(settings),
      # next_day, dark? and read(path). +measure+ wraps text for the sheets (SheetLayout).
      def initialize(game:, session:, settings:, host:, measure:, clock: Clock.real, touch: false)
        @session, @settings, @host, @measure, @clock, @touch = session, settings, host, measure, clock, touch
        @time = 0.0
        @sheets = []
        @layouts = {}
        @sheet_layouts = {}
        self.game = game
      end

      def game=(game)
        @game = game
        @placed = []
        @motion = Motion.new(calm: @settings.calm).tap { it.update(@time) }
        @view = nil
        @armed_at = @copied_at = @copy_failed_at = @stats = nil
        @gesture = @lifted_slot = nil
        game.subscribe { changed(it) }
      end

      # The window's size and safe area in pixels, its Units, and the
      # +measure+ for sheets made at that density.
      def resize(width:, height:, units:, safe: nil, measure: @measure)
        @width, @height, @safe, @units, @measure = width, height, safe, units, measure
        @layouts.clear
        @sheet_layouts.clear
        @sheets.map! { it.with(scroll: 0) }
        @view = nil
      end

      def update(seconds)
        @time += seconds
        @motion.update(@time)
      end

      # --- What the painters read ---

      def layout
        over = game.over?
        pool = !over || !game.pool.empty?
        @layouts[[over, pool]] ||= Layout.for(width: @width, height: @height, safe: @safe, units:, over:, pool:)
      end

      # The board's view, refitted whenever the board's room changes.
      def view
        refit if @view.nil? || @view.viewport != layout.board
        @view
      end

      # The view as the board is drawn this frame: on its way to #view
      # while the camera eases.
      def shown_view
        target = view
        @motion.view || target
      end

      def sheet = @sheets.last
      def sheet? = !@sheets.empty?

      def sheet_layout
        kind = sheet&.kind or return
        @sheet_layouts[kind] ||= SheetLayout.build(blocks: blocks(kind), safe: safe_rect, units:, measure: @measure)
      end

      def status = Copy.status(game)

      def stats = @stats ||= @session.stats(game.day)

      # The clock to the next puzzle, which is the next UTC midnight after
      # the day being played.
      def countdown = Countdown.between(@clock.now, game.day.ends_at)

      # The day a finished game makes way for, once its clock runs out.
      # A game in progress keeps its day, however late it gets.
      def next_day = game.over? && countdown.done? ? @clock.today : nil

      def armed? = @armed_at && @time - @armed_at < T.give_up_confirm
      def copied? = @copied_at && @time - @copied_at < T.copied
      def copy_failed? = @copy_failed_at && @time - @copy_failed_at < T.copied

      def enabled?(control)
        case control
        when :shuffle, :give_up then game.playing?
        when :reset then game.playing? && !game.board.empty?
        else true
        end
      end

      def label(control)
        case control
        when :shuffle then Copy::SHUFFLE
        when :reset then Copy::RESET
        when :give_up then armed? ? Copy::CONFIRM_GIVE_UP : Copy::GIVE_UP
        when :copy
          if copied? then Copy::COPIED
          elsif copy_failed? then Copy::COPY_FAILED
          else Copy::COPY_RESULT
          end
        end
      end

      # --- Pointers ---

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
        pick(target[1]) if target[0] == :slot
      end

      def move(pointer)
        return unless @gesture&.id == pointer.id

        before = @gesture
        @gesture = before.moved(pointer.x, pointer.y, units.px(M.drag))
        return unless @gesture.dragging

        from_x, from_y = before.dragging ? [before.x, before.y] : [before.start_x, before.start_y]
        drag(@gesture.target, pointer.x - from_x, pointer.y - from_y)
      end

      def release(pointer)
        return unless @gesture&.id == pointer.id

        gesture = @gesture.moved(pointer.x, pointer.y, units.px(M.drag))
        @gesture = nil
        tapped(gesture) if gesture.tap?
      end

      # A mouse wheel or a trackpad's two fingers: scrolls a sheet, or pans
      # the board.
      def wheel(dx, dy)
        step = units.px(40)
        if sheet? then scroll_sheet(-dy * step)
        else pan(-dx * step, dy * step)
        end
      end

      # --- Keys (KeyMap) ---

      def text(text) = KeyMap.text(self, text)
      def key(key, command: false) = KeyMap.key(self, key, command:)

      # --- Actions, by name, as the buttons and a Script call them ---

      def pick(index)
        disarm
        game.tap_slot(index)
      end

      def pick_letter(letter)
        slots = game.pool.slots.each_index.select { game.pool[it] == letter }
        return if slots.empty?

        current = slots.index(game.selected)
        if current.nil? then pick(slots.first)
        elsif slots.size == 1 then pick(game.selected) # puts it down
        else pick(slots[(current + 1) % slots.size])
        end
      end

      def tap_cell(position)
        disarm
        game.tap_cell(position) if position
      end

      # Backspace: puts down a letter picked up, or else sends back the
      # letter placed last.
      def take_back
        return pick(game.selected) if game.selected

        last = @placed.reverse.find { game.board.occupied?(it) } || game.board.positions.last
        tap_cell(last) if last
      end

      # What the mouse pointer should look like over (+x+, +y+): a hand
      # over anything a click would do something to, a four-way arrow over
      # a board that pans, else the arrow.
      def cursor_at(x, y)
        case target_at(x, y)
        in [:button, name] then enabled?(name) ? :hand : :arrow
        in [:slot, index] then game.playing? && game.pool.letter?(index) ? :hand : :arrow
        in [:board] then board_cursor(shown_view.cell_at(x, y))
        in [:sheet, :close | :scrim] then :hand
        in [:sheet, :body] then sheet_layout.control_at(x, y, sheet.scroll) ? :hand : :arrow
        else :arrow
        end
      end

      def press_button(name)
        @armed_at = nil unless name == :give_up
        case name
        when :help then open(:help)
        when :theme then change(appearance: Appearance.next(@settings.appearance))
        when :sound then change(muted: !@settings.muted)
        when :shuffle then game.shuffle
        when :reset then game.reset
        when :give_up then give_up
        when :copy then copy
        when :next then @host.next_day if next_day
        end
      end

      # The first press asks to confirm; a second within a few seconds
      # gives up.
      def give_up(confirmed: false)
        return unless game.playing?

        if armed? || confirmed
          @armed_at = nil
          game.give_up
        else
          @armed_at = @time
          @host.sound(:button)
        end
      end

      def copy
        return unless game.over?

        if @host.copy(ShareText.for(game, dark: @host.dark?).to_s)
          @copied_at, @copy_failed_at = @time, nil
          @host.sound(:copied)
        else
          @copied_at, @copy_failed_at = nil, @time
          @host.sound(:button)
        end
      end

      def open(kind, sound: true)
        @armed_at = nil
        return if sheet&.kind == kind

        @sheets << Sheet.open(kind)
        @host.sound(:button) if sound
      end

      # Closes the sheet on top. Closing How to play counts as having read
      # it, so it does not open by itself again.
      def close_sheet
        closed = @sheets.pop or return
        settle(@settings.with(instructions_seen: true)) if closed.kind == :help && !@settings.instructions_seen
        @host.sound(:button)
      end

      def toggle(setting)
        change(setting => !@settings.public_send(setting)) if setting == :calm
      end

      # Changes a setting and tells the host, which applies and saves it.
      def change(**changes)
        settle(@settings.with(**changes))
        @host.sound(:button)
      end

      def scroll_sheet(by)
        return unless sheet?

        @sheets[-1] = sheet.scrolled(by.round, sheet_layout)
      end

      # Moves the board under the finger at once, the camera stopping
      # wherever it was easing to.
      # Esc: closes a sheet, or puts down a letter picked up.
      def escape
        if sheet? then close_sheet
        elsif game.selected then pick(game.selected)
        end
      end

      def toggle_help = sheet&.kind == :help ? close_sheet : open(:help)

      # Enter: today's puzzle, once the finished one's clock has run out.
      def next_puzzle = next_day && @host.next_day

      def pan(dx, dy)
        @view = shown_view.with(viewport: view.viewport, content: view.content, cell: view.cell).pan(dx, dy)
        @motion.camera(nil, @view)
      end

      private

      def safe_rect = @safe || Rect.new(x: 0, y: 0, width: @width, height: @height)

      def blocks(kind) = kind == :help ? Copy.instructions(touch: @touch) : Copy.credits(@host.method(:read))

      def settle(settings)
        @settings = settings
        @motion.calm = settings.calm
        @host.settings_changed(settings)
      end

      def disarm = @armed_at = nil

      # What is under (+x+, +y+): a sheet's part while one is open, else a
      # button, a pool slot, the board, or nothing.
      def target_at(x, y)
        return sheet_target_at(x, y) if sheet?

        layout.header_buttons.each { |name, rect| return [:button, name] if rect.contains?(x, y) }
        layout.controls&.each { |name, rect| return [:button, name] if rect.contains?(x, y) }
        if (results = layout.results)
          return [:button, :copy] if results.copy.contains?(x, y)
          return [:button, :next] if results.countdown.contains?(x, y) && next_day
        end
        layout.pool.each_with_index { |rect, i| return [:slot, i] if rect.contains?(x, y) }
        return [:board] if layout.board.contains?(x, y)

        [:none]
      end

      def sheet_target_at(x, y)
        sheet = sheet_layout
        if sheet.close.contains?(x, y) then [:sheet, :close]
        elsif sheet.body.contains?(x, y) then [:sheet, :body]
        elsif sheet.card.contains?(x, y) then [:sheet, :card]
        else [:sheet, :scrim]
        end
      end

      def board_cursor(cell)
        if game.playing? && cell && (game.selected ? game.board.target?(cell) : game.board.occupied?(cell)) then :hand
        elsif shown_view.pannable? then :sizeall
        else :arrow
        end
      end

      def drag(target, dx, dy)
        case target
        in [:board] then pan(dx, dy)
        in [:sheet, _] then scroll_sheet(-dy)
        else nil
        end
      end

      def tapped(gesture)
        case gesture.target
        in [:board] then tap_cell(shown_view.cell_at(gesture.start_x, gesture.start_y))
        in [:button, name] then press_button(name) if target_at(gesture.x, gesture.y) == gesture.target
        in [:sheet, :close | :scrim] then close_sheet
        in [:sheet, :body]
          control = sheet_layout.control_at(gesture.x, gesture.y, sheet.scroll)
          sheet_control(control.id) if control
        else nil
        end
      end

      def sheet_control(id)
        case id
        when :close then close_sheet
        when :credits then open(:credits)
        else toggle(id)
        end
      end

      # Each change is shown arriving from where it came from, measured on
      # the screen as it was; after every move the board is framed again,
      # keeping the letter just placed in view.
      def changed(event)
        case event
        when Events::Selected then selected(event.index)
        when Events::Deselected then deselected(event.index)
        when Events::Placed then placed(event)
        when Events::Returned then returned([event])
        when Events::Reset then returned(event.returns)
        when Events::Shuffled then shuffled(event.order)
        when Events::Checked then @motion.checked(game.board.bounds, event.check.problems.keys)
        when Events::Won, Events::Lost then ended(event)
        end
      end

      def selected(index)
        @motion.selected(index, @lifted_slot)
        @lifted_slot = index
      end

      def deselected(index)
        @motion.lowered(index)
        @lifted_slot = nil
      end

      def placed(event)
        @placed << event.position
        slot = layout.pool[event.index]
        lift = units.px(Look::METRICS.lift) * @motion.lift(event.index)
        @motion.left(event.index)
        @lifted_slot = nil
        @motion.fly([:cell, event.position], slot.offset(0, -lift.round), :place)
        refit(focus: event.position)
      end

      def returned(returns)
        from = returns.to_h { [it.index, shown_view.tile_rect(it.position)] }
        @lifted_slot = nil
        refit
        returns.each_with_index { |back, i| @motion.fly([:slot, back.index], from[back.index], :return, delay: i * Motion::STAGGER) }
      end

      def shuffled(order)
        @lifted_slot = game.selected
        @motion.moved_lift(game.selected)
        order.each_with_index do |old, new|
          @motion.fly([:slot, new], layout.pool[old], :shuffle) if game.pool.letter?(new) && old != new
        end
      end

      def ended(event)
        @stats = nil
        @lifted_slot = nil
        event.is_a?(Events::Won) ? @motion.won(game.board.bounds) : @motion.lost
      end

      def refit(focus: nil)
        before = @motion.view || @view
        @view = BoardView.fit(viewport: layout.board, content: BoardView.content_of(game.board), units:, focus:,
                              previous: @view)
        @motion.camera(before, @view)
      end
    end
  end
end
