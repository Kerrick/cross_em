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
      T = Look::TIMING

      attr_reader :game, :settings, :time, :units, :motion

      # +host+ answers sound(name), copy(text) (true if it worked),
      # settings_changed(settings), next_day, dark?, system_theme (:light,
      # :dark or :unknown) and read(path). +measure+ wraps text for the sheets (SheetLayout).
      def initialize(game:, session:, settings:, host:, measure:, clock: Clock.real, touch: false)
        @session, @settings, @host, @measure, @clock, @touch = session, settings, host, measure, clock, touch
        @time = 0.0
        @sheets = []
        @layouts = {}
        @pointers = PointerMap.new(self)
        @sheet_layouts = {}
        self.game = game
      end

      def game=(game)
        @game = game
        @motion = Motion.new(calm: @settings.calm).tap { it.update(@time) }
        @choreographer = Choreographer.new(self, game, @motion)
        @view = nil
        @armed_at = @copied_at = @copy_failed_at = @stats = nil
        @pointers.cancel
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
        @sheet_layouts[kind] ||= SheetLayout.build(blocks: blocks(kind), safe: safe_rect, units:, measure: @measure,
                                                   link: kind == :help ? [:credits, Copy::CREDITS] : nil)
      end

      def status = Copy.status(game)

      # The statistics, worked out again once the game ends.
      def stats
        @stats = [game.status, @session.stats(game.day)] unless @stats&.first == game.status
        @stats.last
      end

      # The clock to the next puzzle, which arrives at Rules::ROLLOVER_HOUR
      # UTC the day after the one being played.
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

      # --- Pointers (PointerMap) and keys (KeyMap) ---

      def pointer(event) = @pointers.pointer(event)
      def press(pointer) = @pointers.press(pointer)
      def move(pointer) = @pointers.move(pointer)
      def release(pointer) = @pointers.release(pointer)
      def wheel(dx, dy) = @pointers.wheel(dx, dy)
      def gesture = @pointers.gesture

      # What the mouse pointer should look like over (+x+, +y+).
      def cursor_at(x, y) = @pointers.cursor_at(x, y)

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

        last = @choreographer.last_placed || game.board.positions.last
        tap_cell(last) if last
      end

      def press_button(name)
        @armed_at = nil unless name == :give_up
        case name
        when :help then open(:help)
        when :theme then change(appearance: Appearance.flip(@settings.appearance, @host.system_theme))
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

      # Frames the board again, as after a move, easing the camera there.
      def refit(focus: nil)
        before = @motion.view || @view
        @view = BoardView.fit(viewport: layout.board, content: BoardView.content_of(game.board), units:, focus:,
                              previous: @view)
        @motion.camera(before, @view)
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
    end
  end
end
