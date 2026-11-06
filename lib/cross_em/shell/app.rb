# frozen_string_literal: true

module CrossEm
  module Shell
    # The game running in Lota's window. main.rb hands each of Lota's
    # callbacks to one of these methods. The App puts the parts together,
    # answers Play's requests for the world outside the screen (it is
    # Play's host), and runs the development settings main.rb lists.
    class App
      ROOT = File.expand_path("../../..", __dir__)
      Look = Presentation::Look
      TOUCH_SYSTEMS = %w[iOS Android].freeze

      def initialize(env = ENV)
        @env = env
        @elapsed = 0.0
        @pads = {}
        @axes = {}
      end

      def load
        @os = ::Lota::System.os
        @folder = SaveFolder.new
        theme = @env["CROSS_EM_THEME"]&.then { Presentation::Appearance.parse(it) }
        @settings_store = SettingsStore.new(@folder, appearance: theme)
        settings = @settings_store.load
        @clock = clock
        dictionary = Dictionary.parse(File.read(File.join(ROOT, Dictionary::FILE), encoding: Encoding::UTF_8))
        @session = Session.new(archive: archive, referee: Referee.new(dictionary))
        @cues = []
        @speaker = Speaker.new(muted: settings.muted, enabled: @env["CROSS_EM_MUTE"] != "1")
        @clipboard = Clipboard.new
        @system_theme = read_system_theme
        @fonts = FontBook.new(Look::TYPE)
        @play = Presentation::Play.new(game: open_game(@clock.today), session: @session,
                                       settings:, host: self, measure: nil, clock: @clock,
                                       touch: TOUCH_SYSTEMS.include?(@os),
                                       command_key: ["OS X", "macOS"].include?(@os) ? "Cmd" : "Ctrl")
        resize
        @play.open(:help, sound: false) unless settings.instructions_seen
        development_settings
        ::Lota::Window.set_fullscreen(true, :desktop) if TOUCH_SYSTEMS.include?(@os)
        listen_for_typing
      end

      def update(seconds)
        @speaker.warm
        @play.update(seconds)
        cue_sounds
        development(seconds)
      end

      def draw
        @pen.palette = palette
        @renderer.draw(@play, dark: dark?, muted: @play.settings.muted)
      end

      # --- Lota's input, as the player's pointers and keys ---

      def mouse(phase, x, y, button, istouch)
        pointer = Presentation::InputRouter.mouse(phase, x, y, button:, istouch:)
        @play.pointer(pointer) if pointer
      end

      def mouse_moved(x, y, istouch)
        pointer = Presentation::InputRouter.mouse(:moved, x, y, button: 1, istouch:)
        return unless pointer

        @play.pointer(pointer)
        @play.hover(pointer.x, pointer.y)
        cursor(@play.cursor_at(pointer.x, pointer.y))
      end

      def touch(phase, id, x, y, devicetype, mouse)
        pointer = Presentation::InputRouter.touch(phase, id, x, y, devicetype, mouse)
        @play.pointer(pointer) if pointer
      end

      def wheel(x, y) = @play.wheel(x.to_f, y.to_f)

      def key_pressed(key)
        command = ::Lota::Keyboard.down?(:lgui, :rgui, :lctrl, :rctrl)
        shift = ::Lota::Keyboard.down?(:lshift, :rshift)
        return toggle_fullscreen if key == :f11 && !touch?

        @play.key(key, command:, shift:)
      end

      def text_input(text) = @play.text(text)

      # --- Game controllers ---
      #
      # Only a joystick SDL knows as a gamepad is a controller: on iOS the
      # accelerometer can arrive as a joystick too, and is left alone.
      # The controllers are kept as they come and go, never listed again
      # each frame (listing them every frame once crashed a Lota build
      # on iOS); one that sends a button before it was announced is taken
      # on then.

      def joystick_added(joystick)
        return unless gamepad?(joystick)

        @pads[joystick] = Presentation::PadMap.family(joystick.gamepad_type)
        @play.pads = @pads.values
      rescue StandardError => e
        warn "Cross ’em: a controller couldn't be used (#{e.message})"
      end

      def joystick_removed(joystick)
        return unless @pads.delete(joystick)

        @axes.delete(joystick)
        @play.pads = @pads.values
        %i[left right].each { @play.stick(it, 0.0, 0.0) }
      end

      def gamepad_pressed(joystick, button)
        family = pad(joystick) or return
        @play.pad(button, family:)
      end

      # A stick's axis moved: the stick's whole position goes to Play.
      def gamepad_axis(joystick, axis, value)
        pad(joystick) or return
        side = {leftx: :left, lefty: :left, rightx: :right, righty: :right}[axis] or return
        axes = (@axes[joystick] ||= Hash.new(0.0))
        axes[axis] = value.to_f
        @play.stick(side, axes[:"#{side}x"], axes[:"#{side}y"])
      end

      def theme_changed = @system_theme = read_system_theme

      # The window changed size, or moved to a screen of another density:
      # everything is measured again, and fonts are made at the new size
      # (a big window draws the design larger; Units.for_window).
      def resize
        return unless @play

        width, height = ::Lota::Graphics.dimensions
        units = Presentation::Units.for_window(density:, width:, height:)
        @fonts.forget if @units && @units.scale != units.scale
        @units = units
        @type = Typesetter.new(@fonts, units)
        @pen = Pen.new(units:, type: @type, palette:)
        @renderer = Renderer.new(@pen)
        @play.resize(width:, height:, units:, safe: safe_area(width, height), measure: @type)
      end

      # --- Play's host ---

      def sound(name, pitch: 1.0) = @speaker.play(name, pitch:)
      def copy(text) = @clipboard.copy(text)
      def dark? = Presentation::Appearance.dark?(@play.settings.appearance, @system_theme)
      def system_theme = @system_theme
      def read(path) = File.read(File.join(ROOT, path), encoding: Encoding::UTF_8)

      def settings_changed(settings)
        @speaker.muted = settings.muted
        @speaker.stop_all if settings.muted
        @settings_store.save(settings)
      end

      # Today's puzzle, once the finished one's clock has run out, without
      # starting the game again.
      def next_day
        @play.official = open_game(@clock.today)
      end

      # Sounds +game+'s events: the official game's, and a practice
      # game's, which Play opens itself.
      def listen(game)
        game.subscribe do |event|
          delay = @play&.event_delay.to_f
          Presentation::Sounds.for(event, game).each { |cue| @cues << [@elapsed + delay + cue.delay, cue] }
        end
      end

      private

      def touch? = TOUCH_SYSTEMS.include?(@os)

      # The family of the controller +joystick+, taking it on if it is a
      # gamepad not yet announced; nil if it is not a gamepad.
      def pad(joystick)
        @pads[joystick] || (joystick_added(joystick) && @pads[joystick])
      end

      def gamepad?(joystick) = joystick.respond_to?(:gamepad?) && joystick.gamepad?

      # Plays the sounds whose time has come, some a little after their
      # event (Presentation::Sounds).
      def cue_sounds
        due, @cues = @cues.partition { |at, _| at <= @elapsed }
        due.each { |_, cue| sound(cue.name, pitch: cue.pitch) }
      end

      def open_game(day) = listen(@session.open(day))

      # The records (Archive.open keeps a damaged file aside and begins a
      # fresh one, so the game always opens and saves).
      def archive = Archive.open(@folder, warn: ->(message) { warn "Cross ’em: #{message}" })

      def palette = Presentation::Palette.for(dark?)

      def read_system_theme
        ::Lota::Window.system_theme
      rescue StandardError
        :unknown
      end

      # Pixels to a point: the screen's own density, or CROSS_EM_DENSITY's.
      def density
        Float(@env.fetch("CROSS_EM_DENSITY", ""), exception: false) || ::Lota::Window.native_dpi_scale
      end

      def safe_area(width, height)
        x, y, w, h = ::Lota::Window.safe_area
        return Presentation::Rect.new(x: 0, y: 0, width:, height:) unless w.to_i.positive? && h.to_i.positive?

        Presentation::Rect.new(x: x.to_i, y: y.to_i, width: w.to_i, height: h.to_i)
      end

      # Shows the system's +name+ cursor, if this computer has cursors.
      def cursor(name)
        return if name == @cursor || touch?

        @cursor = name
        @cursors ||= {}
        ::Lota::Mouse.cursor = (@cursors[name] ||= ::Lota::Mouse.system_cursor(name))
      rescue StandardError
        @cursor = name
      end

      def toggle_fullscreen
        fullscreen, = ::Lota::Window.fullscreen
        ::Lota::Window.set_fullscreen(!fullscreen, :desktop)
      end

      # Typed letters reach Lota.textinput only while text input is on,
      # and the window opens with it off, even on a computer. A phone or
      # tablet leaves it off, since turning it on raises the on-screen
      # keyboard over the board.
      def listen_for_typing
        ::Lota::Keyboard.text_input = true unless touch?
      rescue StandardError => e
        warn "Cross ’em: typing a word won't work (#{e.message})"
      end

      # --- Development settings (main.rb lists them) ---

      # CROSS_EM_TODAY=2026-11-07 for that date at the real time of day, or
      # CROSS_EM_TODAY=2026-11-07T23:59:50Z for that moment, running on.
      def clock
        text = @env.fetch("CROSS_EM_TODAY")
        return Presentation::Clock.starting_at(Time.iso8601(text)) if text.include?("T")

        Presentation::Clock.pretending(Date.iso8601(text))
      rescue KeyError, ArgumentError, Date::Error
        Presentation::Clock.real
      end

      def development_settings
        @shots = Presentation::ShotSchedule.parse(@env["CROSS_EM_SHOTS"])
        @quit_after = Float(@env.fetch("CROSS_EM_QUIT_AFTER", ""), exception: false)
        @script = Presentation::Script.parse(@env["CROSS_EM_SCRIPT"])
        @script_clock = 0.0
        @holds = {}
      end

      def development(seconds)
        before = @elapsed
        @elapsed += seconds
        release_sticks
        unless @script.empty?
          steps, @script, @script_clock = @script.due(@elapsed, @script_clock)
          steps.each { run(it) }
        end
        @shots.due(before, @elapsed).each { screenshot(it) }
        ::Lota::Event.quit(0) if @quit_after && @elapsed >= @quit_after
      end

      def screenshot(number)
        name = "shot-#{number}.png"
        ::Lota::Graphics.capture_screenshot(name)
        puts "Cross ’em: screenshot #{@folder.path(name)}"
      end

      # One step of CROSS_EM_SCRIPT (Presentation::Script).
      def run(step)
        args = step.args
        case step.name
        when :pick then pick_letter(args.fetch(0).upcase)
        when :type then args.fetch(0).each_char { @play.text(it) }
        when :key then press_key(args.fetch(0))
        when :slot then @play.pick(Integer(args.fetch(0)))
        when :tap then @play.tap_cell(position(args[0], args[1]))
        when :word then place_word(args.fetch(0).upcase, position(args[1], args[2]), args[3].to_s.start_with?("d"))
        when :shuffle, :reset then @play.press_button(step.name)
        when :giveup then @play.give_up(confirmed: true)
        when :arm then @play.press_button(:give_up)
        when :help, :credits, :archive then @play.open(step.name)
        when :again then @play.play_again
        when :today then @play.back_to_today
        when :day then @play.open_day(Integer(args.fetch(0)))
        when :close then @play.close_sheet
        when :copy then @play.copy
        when :calm then @play.toggle(:calm)
        when :next then @play.press_button(:next)
        when :scroll then scroll(@units.px(Float(args.fetch(0))))
        when :pad then press_pad(*args)
        when :stick, :rstick then hold_stick(step.name == :stick ? :left : :right, *args.first(3).map { Float(it) })
        else warn "Cross ’em: no script step #{step.name}"
        end
      rescue StandardError => e
        warn "Cross ’em: script step #{step.name}:#{step.args.join(':')} failed: #{e.message}"
      end

      # pad:a, pad:lb, pad:x:playstation: a controller's button.
      def press_pad(button, family = nil)
        name = button.downcase
        @play.pad(Presentation::Script::BUTTONS.fetch(name, name).to_sym, family: family&.to_sym)
      end

      # stick:0.8:0:0.5 tilts the left stick to (0.8, 0) for half a
      # second (rstick the right one), as a controller's would be.
      def hold_stick(side, x, y, seconds)
        @play.stick(side, x, y)
        @holds[side] = @elapsed + seconds
      end

      def release_sticks
        @holds.select { |_, time| @elapsed >= time }.each_key do |side|
          @play.stick(side, 0.0, 0.0)
          @holds.delete(side)
        end
      end

      def position(column, row) = Position.new(column: Integer(column), row: Integer(row))

      def pick_letter(letter)
        slot = @play.game.pool.slots.index(letter)
        @play.pick(slot) if slot
      end

      # key:return, key:tab, key:shift+tab, key:cmd+c: a key as Lota names
      # it, with any modifiers before a +.
      def press_key(text)
        *modifiers, key = text.downcase.split("+")
        @play.key(key.to_sym, command: modifiers.intersect?(%w[cmd ctrl]), shift: modifiers.include?("shift"))
      end

      # Places +word+ from +start+, a letter at a time, each as soon as its
      # cell is a target, so a word can grow from a letter in its middle.
      def place_word(word, start, down)
        cells = word.chars.each_with_index.map do |letter, i|
          [letter, down ? start.with(row: start.row + i) : start.with(column: start.column + i)]
        end
        loop do
          board = @play.game.board
          next_cell = cells.find { |letter, cell| board[cell] != letter && board.target?(cell) }
          break unless next_cell

          letter, at = next_cell
          slot = @play.game.pool.slots.index(letter)
          break warn("Cross ’em: no #{letter} left for #{word}") unless slot

          @play.pick(slot) unless @play.game.selected == slot
          @play.tap_cell(at)
          break if @play.game.board.size == board.size
        end
      end

      def scroll(pixels)
        @play.sheet? ? @play.scroll_sheet(pixels) : @play.pan(0, -pixels)
      end
    end
  end
end
