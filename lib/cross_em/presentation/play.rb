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

      attr_reader :game, :official, :mode, :settings, :time, :units, :motion, :typing

      # +host+ answers sound(name), copy(text) (true if it worked),
      # settings_changed(settings), next_day, dark?, system_theme (:light,
      # :dark or :unknown), read(path) and listen(game) (to sound a game
      # it did not open). +measure+ wraps text for the sheets (SheetLayout).
      #
      # +game+ is the day's official game, the one that is saved. The
      # screen can show instead a practice game of any day, or look back
      # at a past day's finished board; neither is ever saved, and moving
      # between them never changes the official game.
      def initialize(game:, session:, settings:, host:, measure:, clock: Clock.real, touch: false)
        @session, @settings, @host, @measure, @clock, @touch = session, settings, host, measure, clock, touch
        @time = 0.0
        @sheets = []
        @layouts = {}
        @pointers = PointerMap.new(self)
        @sheet_layouts = {}
        @typing = Typing.new(self)
        @good = {}
        self.official = game
      end

      # The day's game, the one that counts, shown at once: at the start,
      # and when a new day's puzzle opens.
      def official=(game)
        @official = game
        show(game, :official)
      end

      def practice? = mode == :practice
      def review? = mode == :review

      # Shows +game+: the official one, a practice game or a look back at
      # a finished one (+mode+). The screen starts afresh for it.
      def show(game, mode)
        @game, @mode = game, mode
        @motion = Motion.new(calm: @settings.calm).tap { it.update(@time) }
        @choreographer&.detach
        @choreographer = Choreographer.new(self, game, @motion)
        @view = nil
        @armed_at = @copied_at = @copy_failed_at = @stats = nil
        @pointers.cancel
        @typing.forget
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
        return @sheet_layouts[kind] ||= ArchiveLayout.build(list: archive_list, safe: safe_rect, units:) if kind == :archive

        @sheet_layouts[kind] ||= SheetLayout.build(blocks: blocks(kind), safe: safe_rect, units:, measure: @measure,
                                                   link: kind == :help ? [:credits, Copy::CREDITS] : nil)
      end

      def status
        return Copy.choosing(typing.choice) if typing.choosing?

        Copy.status(game, keyboard: !@touch)
      end

      # How long after the event being told now its animation and sound
      # wait: the later letters of a typed word leave a little later.
      def event_delay = typing.delay

      def sound(name) = @host.sound(name)

      # The statistics, worked out again once the game ends.
      def stats
        return unless mode == :official

        @stats = [game.status, @session.stats(game.day)] unless @stats&.first == game.status
        @stats.last
      end

      # The clock to the next puzzle, which arrives at Rules::ROLLOVER_HOUR
      # UTC the day after the one being played.
      def countdown = Countdown.between(@clock.now, official.day.ends_at)

      # The day a finished game makes way for, once its clock runs out.
      # A game in progress keeps its day, however late it gets.
      def next_day = official.over? && countdown.done? ? @clock.today : nil

      # Every past puzzle and how the player did, from the saved records.
      def archive_list
        @archive_list ||= ArchiveList.new(today: @clock.today, records: @session.archive, month: units.px(40),
                                          day: units.px(60))
      end

      # How many letters ended up in good words in a saved game, for the
      # archive's list.
      def good_letters(record) = @good[record] ||= @session.review(record).good_letters

      # The results' main button: the share button for the official game,
      # or the way back to it.
      def primary = mode == :official ? :copy : :today

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
        when :again then review? ? Copy::PLAY_IT_AGAIN : Copy::PLAY_AGAIN
        when :archive then Copy::ARCHIVE
        when :today then Copy::BACK_TO_TODAY
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
      def key(key, command: false, shift: false) = KeyMap.key(self, key, command:, shift:)

      # --- Actions, by name, as the buttons and a Script call them ---

      # A tap on the pool or the board changes what a typed word's places
      # were worked out for, so any being chosen among are let go.
      def pick(index)
        disarm
        typing.drop_choice
        game.tap_slot(index)
      end

      def tap_cell(position)
        disarm
        typing.drop_choice
        game.tap_cell(position) if position
      end

      # The letter placed last that is still on the board, however it got
      # there.
      def last_placed = @choreographer.last_placed || game.board.positions.last

      # Backspace: puts down a letter picked up, or else edits what is
      # being typed (Typing#erase), which with nothing typed takes back
      # the last word typed, or the letter placed last.
      def erase
        return pick(game.selected) if game.selected && !typing.drafting? && !typing.choosing?

        typing.erase
      end

      def press_button(name)
        @armed_at = nil unless name == :give_up
        case name
        when :help then open(:help)
        when :archive then open(:archive)
        when :again then play_again
        when :today then back_to_today
        when :theme then change(appearance: Appearance.flip(@settings.appearance, @host.system_theme))
        when :sound then change(muted: !@settings.muted)
        when :shuffle, :reset
          typing.drop_choice
          game.public_send(name)
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

      # A practice game of the day shown: a fresh pool and an empty board.
      def play_again = practice(game.day)

      def practice(day)
        game = @session.practice(day)
        @host.listen(game)
        show(game, :practice)
        @host.sound(:shuffle)
      end

      # Back to the day's official game, as it was left.
      def back_to_today
        @sheets.pop if sheet&.kind == :archive
        show(official, :official) unless mode == :official
        @host.sound(:button)
      end

      # Opens puzzle +number+ from the archive: the official game for its
      # own day, today's when that is another, a look at the board the
      # player finished, or else a practice game. Nothing is saved.
      def open_day(number)
        return back_to_today if number == official.day.number
        return (@sheets.pop && @host.next_day) if number == @clock.today.number

        @sheets.pop if sheet&.kind == :archive
        record = @session.archive[number]
        if record&.finished?
          show(@session.review(record), :review)
          @host.sound(:button)
        else
          practice(Day.numbered(number))
        end
      end

      # Moves the keyboard's place in Past puzzles +by+ days (positive is
      # older), or to the newest (:home) or the oldest (:end), scrolling
      # it into view. The first move lands on the top day in view.
      def move_focus(by)
        layout = sheet_layout
        list = layout.list
        row = case by
              when :home then list.days.first
              when :end then list.days.last
              else
                if sheet.focus then list.step(sheet.focus, by)
                else layout.visible(sheet.scroll).find { it.day? && it.y >= sheet.scroll } || list.days.first
                end
              end
        @sheets[-1] = sheet.with(focus: row.number, scroll: layout.reveal(row, sheet.scroll))
      end

      # A page of days in Past puzzles, for Page Up and Page Down.
      def focus_page = [sheet_layout.body.height / archive_list.days.first.height, 1].max

      # Enter in Past puzzles: opens the day the keyboard is on.
      def open_focus = sheet.focus && open_day(sheet.focus)

      def copy
        return unless game.over? && mode == :official

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

        if kind == :archive
          @archive_list = nil
          @sheet_layouts.delete(:archive)
        end
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

      # Esc: closes a sheet, or goes back from choosing where a word
      # goes, or clears what is typed, or puts down a letter picked up.
      def escape
        if sheet? then close_sheet
        elsif typing.escape then nil
        elsif game.selected then pick(game.selected)
        end
      end

      # Enter: places a typed word, or opens today's puzzle once the
      # finished one's clock has run out.
      def enter = typing.submit || next_puzzle

      # Space: places a typed word, or else shuffles.
      def space
        return if typing.submit

        press_button(:shuffle) if game.playing?
      end

      def toggle_help = sheet&.kind == :help ? close_sheet : open(:help)

      # Enter: today's puzzle, once the finished one's clock has run out.
      def next_puzzle = next_day && @host.next_day

      # Moves the board under the finger at once, the camera stopping
      # wherever it was easing to.
      def pan(dx, dy)
        @view = shown_view.with(viewport: view.viewport, content: view.content, cell: view.cell).pan(dx, dy)
        @motion.camera(nil, @view)
      end

      # Frames the board again, as after a move, easing the camera there:
      # the letters, and any place a typed word is being shown, with
      # +focus+ (a cell, or several) in view.
      def refit(focus: nil)
        before = @motion.view || @view
        cells = typing.cells
        content = BoardView.content_of(game.board, cells)
        focus = cells.empty? ? focus : [cells.last, cells.first]
        @view = BoardView.fit(viewport: layout.board, content:, units:, focus:, previous: @view)
        @motion.camera(before, @view)
      end

      def disarm = @armed_at = nil

      private

      def safe_rect = @safe || Rect.new(x: 0, y: 0, width: @width, height: @height)

      def blocks(kind) = kind == :help ? Copy.instructions(touch: @touch) : Copy.credits(@host.method(:read))

      def settle(settings)
        @settings = settings
        @motion.calm = settings.calm
        @host.settings_changed(settings)
      end
    end
  end
end
