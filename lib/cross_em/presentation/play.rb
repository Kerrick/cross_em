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

      # The one focus a keyboard's arrows and a controller move (FocusRing),
      # and the left stick's cursor (StickCursor).
      attr_reader :ring, :cursor

      # The family of the controller last used, for its glyphs: :xbox,
      # :playstation or :nintendo (PadMap.family).
      attr_reader :pad_family

      # The left stick's fastest, and the right stick's, in points a
      # second at full tilt.
      CURSOR_SPEED = 1100
      LOOK_SPEED = 900

      # +host+ answers sound(name), copy(text) (true if it worked),
      # settings_changed(settings), next_day, dark?, system_theme (:light,
      # :dark or :unknown), read(path) and listen(game) (to sound a game
      # it did not open). +measure+ wraps text for the sheets (SheetLayout).
      #
      # +game+ is the day's official game, the one that is saved. The
      # screen can show instead a practice game of any day, or look back
      # at a past day's finished board; neither is ever saved, and moving
      # between them never changes the official game.
      def initialize(game:, session:, settings:, host:, measure:, clock: Clock.real, touch: false, command_key: "Ctrl")
        @session, @settings, @host, @measure, @clock, @touch = session, settings, host, measure, clock, touch
        @command_key = command_key
        @time = 0.0
        @sheets = []
        @layouts = {}
        @pointers = PointerMap.new(self)
        @sheet_layouts = {}
        @typing = Typing.new(self)
        @good = {}
        @ring = FocusRing.new
        @cursor = StickCursor.new(speed: CURSOR_SPEED)
        @sticks = {left: [0.0, 0.0], right: [0.0, 0.0]}
        @scroll_rest = 0.0
        @input = nil
        @pads = []
        @pad_family = :xbox
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
        @cursor.speed = units.px(CURSOR_SPEED)
      end

      def update(seconds)
        @time += seconds
        @motion.update(@time)
        steer(seconds)
      end

      # --- What the painters read ---

      # Where everything goes. Once the pool is empty, during play as
      # after it, its sockets give their room to the board.
      def layout = layout_for(pool: !game.pool.empty?)

      # Where pool slot +index+ is, even while the pool is hidden: where
      # the twelfth letter leaves from as the pool gives way.
      def pool_slot(index) = layout_for(pool: true).pool[index]

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
                                                   link: kind == :help ? [:credits, Copy::CREDITS, @touch ? 88 : 116] : nil)
      end

      # Whether the player is at a computer, with a keyboard and a mouse,
      # rather than a touch screen.
      def keyboard? = !@touch

      # A tooltip for the button the mouse has rested on, on a computer:
      # [text, keycaps, the button's rect]. A header button's names what
      # it does, since it is an icon; every button's shows its keys.
      #
      # While the focus ring is shown on one of the header's icons, the
      # tooltip is that icon's, so a player at a controller can tell
      # them apart too.
      def tooltip
        return if sheet? || gesture

        if @ring.visible? && (target = focused)&.region == :header
          name, rect = target.id.last, target.rect
        else
          return if @touch

          resting = @pointers.resting(@time, Look::TIMING.tooltip) or return
          name, rect = resting
        end
        text = tip(name, rect)
        keys = keycaps(name)
        [text, keys, rect] if text || keys
      end

      # What a header button does, as its tooltip names it.
      def tip(name, rect)
        case name
        when :theme then Copy::TIPS[@host.dark? ? :light : :dark]
        when :sound then Copy::TIPS[@settings.muted ? :unmute : :mute]
        when :archive, :help then Copy::TIPS[name] if layout.header_buttons.any? { it.last == rect }
        when :today then Copy::TIPS[:today] if rect == layout.wordmark
        end
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

      # Whether the results show the clock (or, once it has run out, the
      # button to the next puzzle). After a practice game or a look back,
      # while the day's game is still unfinished past its day, the clock
      # would sit at 00:00:00 with nothing to follow it, so it is left
      # out: "Back to today" is the way on.
      def countdown? = mode == :official || !!next_day || !countdown.done?

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
        when :shuffle then game.playing? && !game.pool.empty?
        when :give_up then game.playing?
        when :reset then game.playing? && !game.board.empty?
        else true
        end
      end

      def label(control)
        case control
        when :shuffle then Copy::SHUFFLE
        when :reset then Copy::RESET
        when :give_up then armed? ? Copy::CONFIRM_GIVE_UP : Copy::GIVE_UP
        when :again then Copy::PLAY_AGAIN
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

      def pointer(event)
        pointed(event) if event.phase == :pressed
        @pointers.pointer(event)
      end

      def hover(x, y) = @pointers.hover(x, y, @time)

      def press(pointer)
        pointed(pointer)
        @pointers.press(pointer)
      end

      def move(pointer) = @pointers.move(pointer)
      def release(pointer) = @pointers.release(pointer)
      def wheel(dx, dy) = @pointers.wheel(dx, dy)
      def gesture = @pointers.gesture

      # What the mouse pointer should look like over (+x+, +y+).
      def cursor_at(x, y) = @pointers.cursor_at(x, y)

      def text(text)
        @input = :keys
        KeyMap.text(self, text)
      end

      def key(key, command: false, shift: false)
        @input = :keys
        KeyMap.key(self, key, command:, shift:)
      end

      # A controller's +button+ (PadMap), from a controller of +family+.
      # Any use of a controller shows the focus ring.
      def pad(button, family: nil)
        @input = :pad
        @pad_family = family if family
        PadMap.press(self, button)
        @ring.show
      end

      # A controller's stick, :left or :right, tilted to (+x+, +y+), each
      # from -1 to 1. #update moves the cursor or the board by it.
      def stick(side, x, y)
        @sticks[side] = [x.to_f, y.to_f]
      end

      # The families of the controllers connected now (PadMap.family). How
      # to play tells a player with one how to use it.
      def pads=(families)
        return if families == @pads

        @pads = families
        @sheet_layouts.delete(:help)
      end

      def pads? = !@pads.empty?

      # What the player last played with: :pad, :keys, :pointer, or nil.
      attr_reader :input

      # Which hints the buttons show: a controller's glyphs while one was
      # the last thing used, else keycaps at a computer, and none on a
      # touch screen.
      def hints
        return :pad if @input == :pad

        @touch ? nil : :keys
      end

      # Carries out a named action, whichever input asked for it: a key
      # (KeyMap), or anything else that names actions. The buttons'
      # actions go through #press_button, so a key does exactly what a
      # click does, only when the button would be live.
      def act(action, arg = nil)
        case action
        when :type
          @ring.hide
          typing.type(arg)
        when :choose then typing.choose(arg)
        when :cycle then typing.cycle(arg)
        when :enter then enter
        when :space then space
        when :erase then erase
        when :escape then escape
        when :help then toggle_help
        when :credits then open(:credits)
        when :close then close_sheet
        when :scroll then KeyMap.scroll(self, arg)
        when :focus then KeyMap.focus(self, arg)
        when :open_day then open_focus
        when :move then navigate(arg)
        when :hop then hop(arg)
        when :activate then activate
        when :page then page(arg)
        else press_button(action) if button?(action)
        end
      end

      # Whether +name+'s button is on screen and live, so its key may act.
      def button?(name)
        case name
        when :shuffle, :reset, :give_up then game.playing? && enabled?(name)
        when :again then game.over?
        when :today then mode != :official
        when :copy then game.over? && mode == :official
        when :next then !next_day.nil?
        when :archive, :theme, :sound then true
        else false
        end
      end

      # The keys for +name+'s action, as keycaps to show by its button
      # (KeyMap::KEYCAPS), on a computer; nil on a touch screen.
      #
      # While a controller is in use, its glyphs instead (PadMap).
      def keycaps(name)
        case hints
        when :pad then PadMap.glyphs(name, @pad_family)
        when :keys then KeyMap::KEYCAPS[name]&.map { it == :command ? @command_key : it }
        end
      end

      # --- The focus (FocusMap) ---

      # The focused Target, found again on the screen as it is now.
      def focused = @ring.current(FocusMap.targets(self), default: FocusMap.default(self))

      def focus_visible? = @ring.visible?

      # Where to draw the focus ring, while it is shown: [rect, shape,
      # clip], the shape :tile, :button, :icon or :row, and +clip+ the
      # rect to draw it inside, or nil. A board cell's ring moves with the
      # camera as it eases.
      def focus_mark
        return unless @ring.visible?

        target = focused or return
        case target.id
        in [:cell, position] then [shown_view.tile_rect(position), :tile, shown_view.viewport]
        in [:slot, _] then [target.rect, :tile, nil]
        in [:day, _] then [target.rect, :row, archive_clip]
        in [:control, _] if FocusMap.body?(self, target)
          [target.rect, :button, sheet_layout.body]
        in [:button, :today] | [:control, _] then [target.rect, :button, nil]
        else [target.rect, target.region == :header ? :icon : :button, nil]
        end
      end

      # Moves the focus by +direction+ (:up, :down, :left or :right). The
      # first press after a tap or a click only shows where it is.
      def navigate(direction)
        shown = @ring.visible?
        @ring.show
        follow(shown || sheet? ? FocusMap.move(self, @ring, direction) : focused)
      end

      # Jumps +by+ regions (Tab, LB and RB); in a sheet, +by+ controls.
      def hop(by)
        shown = @ring.visible?
        @ring.show
        follow(shown ? FocusMap.hop(self, @ring, by) : focused)
      end

      # A or Enter: does what a tap on the focus would. The first press
      # after a tap or a click only shows where the focus is.
      def activate
        return @ring.show unless @ring.visible?

        target = focused or return
        FocusMap.activate(self, target)
      end

      # A page up (+by+ -1) or down in a sheet: LB and RB.
      def page(by)
        key = by.negative? ? :pageup : :pagedown
        sheet&.kind == :archive ? KeyMap.focus(self, key) : KeyMap.scroll(self, key)
      end

      # A tap on a sheet's control, or A or Enter on it.
      def sheet_control(id)
        case id
        in [:day, number] then open_day(number)
        in :close then close_sheet
        in :credits then open(:credits)
        else toggle(id)
        end
      end

      # --- Actions, by name, as the buttons and a Script call them ---

      # A tap on the pool or the board changes what a typed word's places
      # were worked out for, so any being chosen among are let go.
      def pick(index)
        disarm
        typing.drop_choice
        game.tap_slot(index)
      end

      # A tap on the board; while a typed word's places are shown, a tap
      # on one of them places the word there.
      def tap_cell(position)
        disarm
        return if position && typing.choose_at(position)

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
        @ring.show
        FocusMap.day_focus(self, @ring)
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

      # Enter: places a typed word, or, from the results, opens today's
      # puzzle once the finished one's clock has run out, or goes back to
      # today from practice or a look back.
      def enter
        return true if typing.submit
        return next_puzzle if next_day
        return back_to_today if game.over? && mode != :official
      end

      # Space: places a typed word, or else shuffles.
      def space
        return if typing.submit

        press_button(:shuffle) if enabled?(:shuffle)
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

      # A tap or a click: the focus ring hides until the keyboard's arrows
      # or a controller are used again, and the focus moves to what was
      # pressed, if anything, so they go on from there.
      def pointed(pointer)
        @input = :pointer
        @ring.hide
        pressed = FocusMap.pointable(self).find { it.rect.contains?(pointer.x, pointer.y) }
        @ring.focus(pressed) if pressed
      end

      # After the focus moved by direction or by region: the camera pans
      # to a board cell out of sight, and the stick's cursor goes on from
      # the focus.
      def follow(target)
        return unless target

        if target.id.first == :cell
          position = target.id.last
          refit(focus: position) unless view.reveal(position) == view
          target = focused || target
        end
        @cursor.place(target.rect.center_x, target.rect.center_y)
        target
      end

      # The sticks, each frame: the left one moves the cursor, which moves
      # the focus; the right one pans the board or scrolls a sheet.
      def steer(seconds)
        look(seconds)
        lx, ly = @sticks[:left]
        tilted = StickCursor.shaped(lx, ly) != [0.0, 0.0]
        return unless tilted || @cursor.moving? || @cursor.visible?

        if tilted && !@cursor.moving? && !@cursor.visible?
          start = focused
          @cursor.place(start.rect.center_x, start.rect.center_y) if start
        end
        if tilted
          @input = :pad
          @ring.show
        end
        bounds = Rect.new(x: 0, y: 0, width: @width, height: @height)
        event = @cursor.update(seconds, lx, ly, FocusMap.pointable(self), bounds)
        @ring.focus(event.last) if event
      end

      def look(seconds)
        x, y = StickCursor.shaped(*@sticks[:right])
        return if x.zero? && y.zero?

        @input = :pad
        speed = units.px(LOOK_SPEED) * Math.hypot(x, y) * seconds
        return pan(-x * speed, -y * speed) unless sheet?

        @scroll_rest += y * speed
        whole = @scroll_rest.truncate
        @scroll_rest -= whole
        scroll_sheet(whole) unless whole.zero?
      end

      def archive_clip
        layout = sheet_layout
        top = layout.pinned(sheet.scroll)&.last&.bottom || layout.body.y
        layout.body.with(y: top, height: layout.body.bottom - top)
      end

      def layout_for(pool:)
        over = game.over?
        @layouts[[over, pool]] ||= Layout.for(width: @width, height: @height, safe: @safe, units:, over:, pool:)
      end

      def safe_rect = @safe || Rect.new(x: 0, y: 0, width: @width, height: @height)

      def blocks(kind) = kind == :help ? Copy.instructions(touch: @touch, pad: pads?) : Copy.credits(@host.method(:read))

      def settle(settings)
        @settings = settings
        @motion.calm = settings.calm
        @host.settings_changed(settings)
      end
    end
  end
end
