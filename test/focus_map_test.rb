# frozen_string_literal: true

require "presentation_helper"

# The focus over the real Play screen: on a phone and a desktop, while
# playing, on the results and in the sheets, driven as a controller and a
# keyboard drive it.
class FocusMapTest < Minitest::Test
  include PresentationTest

  PHONE = [390, 844].freeze
  DESKTOP = [1280, 800].freeze

  def setup
    @host = FakeHost.new
    @session = Session.new(archive: Archive.new(Archive::Memory.new), referee:)
  end

  def play(game: game(), size: PHONE, clock: Clock.pretending(Day.numbered(1720).date), touch: false)
    Play.new(game:, session: @session, settings: Settings.default.with(instructions_seen: true), host: @host,
             measure: FakeMeasure.new, clock:, touch:).tap { resize(it, size) }
  end

  def resize(play, (width, height)) = play.resize(width:, height:, units: units)

  def id(play) = play.focused&.id

  def press(play, *buttons) = buttons.each { play.pad(it) }

  def tap(play, x, y)
    play.press(Pointer.new(phase: :pressed, id: :mouse, x:, y:))
    play.release(Pointer.new(phase: :released, id: :mouse, x:, y:))
  end

  # --- Playing on a phone ---

  def test_the_first_press_shows_the_ring_on_the_first_letter_without_moving
    play = play()

    refute_predicate play, :focus_visible?
    press(play, :dpright)

    assert_predicate play, :focus_visible?
    assert_equal [:slot, 0], id(play)
    press(play, :dpright)

    assert_equal [:slot, 1], id(play)
  end

  def test_on_a_phone_the_dpad_walks_pool_controls_board_and_header
    play = play()
    press(play, :dpdown)

    assert_equal [:slot, 0], id(play)
    press(play, :dpdown)

    assert_equal [:slot, 6], id(play), "the pool's second row"
    press(play, :dpdown)

    assert_equal [:button, :shuffle], id(play), "Reset has nothing to do yet, so it is passed over"
    press(play, :dpright)

    assert_equal [:button, :give_up], id(play)
    press(play, :dpup, :dpup, :dpup)

    assert_equal [:cell, Position::ORIGIN], id(play), "up from the pool: the empty board's square"
    press(play, :dpup)

    assert_equal :header, play.focused.region
  end

  # Every target can be left by some direction, and every one reached
  # from the first by the d-pad alone.
  def assert_all_reachable(play, label)
    targets = FocusMap.targets(play)
    ring = play.ring
    key = ->(target) { [target.region, target.id] }
    edges = targets.to_h do |from|
      [key.(from), Spatial::DIRECTIONS.filter_map do |direction|
        ring.focus(from)
        FocusMap.move(play, ring, direction)&.then(&key)
      end]
    end
    edges.each { |id, to| refute_empty to, "#{label}: #{id.inspect} is a dead end" }
    reached = Set.new
    queue = [key.(targets.first)]
    until queue.empty?
      id = queue.shift
      queue.concat(edges.fetch(id)) if reached.add?(id)
    end

    assert_equal targets.to_set(&key), reached, "#{label}: some can't be reached"
  end

  def test_every_target_can_be_reached_and_left_by_the_dpad
    sizes = {"phone" => PHONE, "phone on its side" => PHONE.reverse, "desktop" => DESKTOP, "iPad" => [1024, 1366],
             "small" => [320, 568]}
    sizes.each do |name, size|
      play = play(game: game(board: board("CAT", ".G."), pool: "...SDO.TAGCA"), size:)
      assert_all_reachable(play, "#{name}, playing")
      play.pick(4)
      assert_all_reachable(play, "#{name}, a letter in hand")
      play.give_up(confirmed: true)
      assert_all_reachable(play, "#{name}, the results")
      play.play_again
      assert_all_reachable(play, "#{name}, practice")
    end
  end

  def test_the_results_with_the_next_puzzle_ready_can_all_be_reached
    clock = Clock.starting_at(Time.utc(2026, 11, 6, 8, 59, 0))
    play = play(clock:)
    play.give_up(confirmed: true)
    clock = Clock.starting_at(Time.utc(2026, 11, 6, 9, 30, 0))
    play.instance_variable_set(:@clock, clock)

    refute_nil play.next_day
    assert_all_reachable(play, "next puzzle ready")
  end

  def test_a_pad_picks_up_a_letter_jumps_to_the_board_places_it_and_jumps_back
    play = play()
    press(play, :a)

    assert_nil play.game.selected, "the first press only shows the ring"
    press(play, :a)

    assert_equal 0, play.game.selected
    press(play, :leftshoulder)

    assert_equal [:cell, Position::ORIGIN], id(play), "LB: the board, before the pool"
    press(play, :a)

    assert_equal "C", play.game.board[Position::ORIGIN]
    assert_equal [:cell, Position::ORIGIN], id(play), "the focus stays on the letter just placed"
    press(play, :rightshoulder)

    assert_equal [:slot, 1], id(play), "back to the pool: slot 0 is empty now, so its neighbour"
    press(play, :a, :leftshoulder)

    assert_equal [:cell, Position::ORIGIN], id(play), "the board, where the focus was left"
    press(play, :dpright, :a)

    assert_equal "A", play.game.board[at(1, 0)]
  end

  def test_a_on_a_placed_letter_sends_it_back_and_b_puts_down_a_letter
    play = play(game: game(board: board("C"), pool: ".ATSDOGTAGCA"))
    play.ring.focus(FocusMap.targets(play).find { it.id == [:cell, Position::ORIGIN] })
    play.ring.show
    press(play, :a)

    assert_predicate play.game.board, :empty?
    press(play, :rightshoulder, :a)

    refute_nil play.game.selected
    press(play, :b)

    assert_nil play.game.selected
  end

  def test_regions_hop_in_order_and_wrap
    play = play(game: game(board: board("CAT"), pool: "...SDOGTAGCA"))
    press(play, :rightshoulder)

    assert_equal :pool, play.focused.region, "the first press shows the ring where it is"
    regions = 4.times.map do
      press(play, :rightshoulder)
      play.focused.region
    end

    assert_equal %i[controls header board pool], regions
    press(play, :leftshoulder)

    assert_equal :board, play.focused.region
  end

  def test_the_camera_pans_to_a_cell_out_of_sight
    across = "CATSDOGTAGCA"
    play = play(game: game(board: board(across), pool: "............"), size: [390, 700])

    assert_predicate play.view, :pannable?
    press(play, :leftshoulder, :leftshoulder, :dpright)
    target = play.focused

    assert_equal :board, target.region
    11.times { press(play, :dpright) }

    assert_equal [:cell, at(11, 0)], id(play)
    assert play.view.visible?(at(11, 0)), "the camera followed the focus"
  end

  def test_the_focus_survives_a_rotation
    play = play()
    press(play, :dpright, :dpright, :dpdown)

    assert_equal [:slot, 7], id(play)
    resize(play, PHONE.reverse)

    assert_predicate play.layout, :landscape
    assert_equal [:slot, 7], id(play)
    assert_equal play.layout.pool[7], play.focused.rect
  end

  def test_a_tap_hides_the_ring_and_the_next_press_shows_it_where_it_was
    play = play()
    press(play, :dpright, :dpright)
    slot = play.layout.pool[5]
    tap(play, slot.center_x, slot.center_y)

    refute_predicate play, :focus_visible?
    assert_equal :pointer, play.input
    press(play, :dpdown)

    assert_equal [:slot, 5], id(play), "the focus went to what was tapped, and shows there"
    press(play, :dpdown)

    assert_equal [:slot, 11], id(play)
  end

  # --- A desktop, wide ---

  def test_on_a_desktop_left_from_the_pool_reaches_the_board_and_right_comes_back
    play = play(game: game(board: board("CAT"), pool: "...SDOGTAGCA"), size: DESKTOP)

    assert play.layout.landscape
    press(play, :dpdown)

    assert_equal [:slot, 3], id(play)
    press(play, :dpleft)

    assert_equal [:cell, at(2, 0)], id(play), "slots 0 to 2 are empty: on to the board's nearest letter"
    press(play, :dpright)

    assert_equal [:slot, 6], id(play), "back to the nearest slot"
    press(play, :dpup)

    assert_equal [:button, :archive], id(play), "the column's top is under the header's buttons"
    press(play, :dpdown)

    assert_equal :pool, play.focused.region
  end

  # --- The results ---

  def test_the_results_start_on_the_share_button_and_walk_their_buttons
    play = play()
    play.give_up(confirmed: true)
    press(play, :dpdown)

    assert_equal [:button, :copy], id(play)
    press(play, :dpdown)

    assert_equal [:button, :archive], id(play)
    press(play, :dpleft)

    assert_equal [:button, :again], id(play)
    press(play, :dpup)

    assert_equal [:button, :copy], id(play), "the clock isn't a button until it runs out"
    press(play, :a)

    assert_equal 1, @host.copied.size
    press(play, :dpdown, :dpleft, :a)

    assert_predicate play, :practice?
  end

  def test_on_the_results_x_plays_again_and_y_copies
    play = play()
    play.give_up(confirmed: true)
    press(play, :y)

    assert_equal 1, @host.copied.size
    press(play, :x)

    assert_predicate play, :practice?
  end

  # --- Buttons ---

  def test_x_shuffles_back_resets_y_gives_up_twice_and_start_opens_how_to_play
    play = play(game: game(board: board("C"), pool: ".ATSDOGTAGCA"))
    before = play.game.pool.slots
    srand(1)
    press(play, :x)

    refute_equal before, play.game.pool.slots
    press(play, :back)

    assert_predicate play.game.board, :empty?
    press(play, :y)

    assert_predicate play, :armed?
    press(play, :y)

    assert_predicate play.game, :over?
    press(play, :start)

    assert_equal :help, play.sheet.kind
    press(play, :b)

    refute_predicate play, :sheet?
  end

  # --- Sheets ---

  def test_in_how_to_play_the_dpad_reaches_its_controls_scrolling_to_them
    play = play()
    press(play, :start)

    assert_equal [:sheet, :close], id(play), "the close button first"
    steps = 0
    until id(play) == [:control, :calm] || steps > 30
      press(play, :dpdown)
      steps += 1
    end

    assert_equal [:control, :calm], id(play)
    assert_operator play.sheet.scroll, :>, 0
    assert play.focused.shown, "scrolled into sight"
    press(play, :a)

    assert_predicate play.settings, :calm
    press(play, :dpdown, :a)

    refute_predicate play, :sheet?, "Play closes it"
  end

  def test_in_how_to_play_left_from_close_is_credits
    play = play()
    press(play, :start, :dpleft)

    assert_equal [:control, :credits], id(play)
    press(play, :a)

    assert_equal :credits, play.sheet.kind
  end

  def test_past_puzzles_walk_from_today_up_to_close_and_back
    play = play()
    play.open(:archive)
    press(play, :dpdown)

    assert_equal [:day, 1720], id(play)
    assert_equal 1720, play.sheet.focus
    press(play, :dpdown)

    assert_equal [:day, 1719], id(play)
    press(play, :dpup, :dpup)

    assert_equal [:sheet, :close], id(play)
    press(play, :dpdown)

    assert_equal [:day, 1720], id(play)
    press(play, :rightshoulder)

    assert_operator play.sheet.focus, :<, 1719, "RB pages down"
    press(play, :a)

    assert_predicate play, :practice?
  end

  def test_after_a_sheet_closes_the_focus_is_where_it_was
    play = play()
    press(play, :rightshoulder, :rightshoulder, :rightshoulder)

    assert_equal :header, play.focused.region
    press(play, :dpright)
    before = id(play)
    press(play, :a)

    assert_predicate play, :sheet?
    press(play, :b)

    assert_equal before, id(play)
  end

  # --- Sticks ---

  def test_the_left_stick_moves_a_cursor_that_focuses_what_it_is_over_and_settles
    play = play()
    play.pad(:dpright)
    start = play.focused.rect
    play.stick(:left, 1.0, 0.0)
    play.update(0.05)

    assert_predicate play.cursor, :visible?
    assert_operator play.cursor.x, :>, start.center_x
    30.times { play.update(1.0 / 60) }
    play.stick(:left, 0.0, 0.0)
    play.update(1.0 / 60)

    assert_equal :pool, play.focused.region
    refute_equal [:slot, 0], id(play)
    slot = id(play).last
    10.times { play.update(1.0 / 60) }

    assert_in_delta play.layout.pool[slot].center_x, play.cursor.x, 1e-6, "it glided onto the slot it settled on"
  end

  def test_the_dpad_carries_the_cursor_with_the_focus
    play = play()
    press(play, :dpright, :dpright, :dpright)
    rect = play.focused.rect

    assert_equal [rect.center_x, rect.center_y], [play.cursor.x, play.cursor.y]
    refute_predicate play.cursor, :visible?
  end

  def test_the_right_stick_pans_a_big_board
    play = play(game: game(board: board("CATSDOGTAGCA"), pool: "............"), size: [390, 700])
    before = play.shown_view.x
    play.stick(:right, 1.0, 0.0)
    play.update(0.1)

    assert_operator play.shown_view.x, :<, before, "the board moves left to show more on its right"
    assert_equal :pad, play.input
  end

  def test_the_right_stick_scrolls_a_sheet
    play = play()
    play.open(:help)
    play.stick(:right, 0.0, 1.0)
    play.update(0.1)

    assert_operator play.sheet.scroll, :>, 0
  end

  # --- Hints ---

  def test_buttons_show_glyphs_while_a_controller_was_last_used
    play = play()

    assert_equal ["Space"], play.keycaps(:shuffle)
    play.pad(:dpright, family: :playstation)

    assert_equal :pad, play.hints
    assert_equal [PadGlyph.new(button: :x, family: :playstation)], play.keycaps(:shuffle)
    assert_equal :square, play.keycaps(:shuffle).first.label
    play.key(:space)

    assert_equal :keys, play.hints
    assert_equal ["Space"], play.keycaps(:shuffle)
  end

  def test_a_touch_screen_shows_glyphs_only_while_a_controller_is_used
    play = play(touch: true)

    assert_nil play.keycaps(:shuffle)
    play.pad(:dpright)

    assert_equal "X", play.keycaps(:shuffle).first.label
    tap(play, 1, 1)

    assert_nil play.keycaps(:shuffle)
  end

  def test_the_focused_header_icon_names_itself
    play = play(touch: true)
    press(play, :leftshoulder, :leftshoulder, :leftshoulder)
    text, _keys, rect = play.tooltip

    assert_equal :header, play.focused.region
    assert_equal play.focused.rect, rect
    refute_nil text
  end

  def test_how_to_play_mentions_the_controller_once_one_is_connected
    play = play()
    play.open(:help)
    words = -> { play.sheet_layout.lines.map(&:text).join(" ") }

    refute_match(/controller/, words.())
    play.pads = [:xbox]

    assert_match(/controller/, words.())
  end

  # --- Controllers' glyphs ---

  def test_families_and_their_labels
    assert_equal :playstation, PadMap.family(:ps5)
    assert_equal :nintendo, PadMap.family(:switchpro)
    assert_equal :nintendo, PadMap.family(:joyconpair)
    assert_equal :xbox, PadMap.family(:xboxone)
    assert_equal :xbox, PadMap.family(:unknown)
    assert_equal "B", PadMap.label(:a, :nintendo), "the bottom button is B on a Nintendo controller"
    assert_equal "LB", PadMap.label(:leftshoulder, :xbox)
    assert_equal :cross, PadMap.label(:a, :playstation)
    assert_predicate PadGlyph.new(button: :y, family: :xbox), :round?
    refute_predicate PadGlyph.new(button: :back, family: :xbox), :round?
  end

  # --- The keyboard ---

  def test_space_shuffles_until_the_arrows_show_the_ring_then_acts_on_the_focus
    play = play()
    srand(2)
    before = play.game.pool.slots
    play.key(:space)

    refute_equal before, play.game.pool.slots, "Space shuffles"
    play.key(:right)
    play.key(:space)

    assert_equal 0, play.game.selected, "now Space picks up the focused letter"
    play.key(:return)

    assert_nil play.game.selected, "and Enter puts it down"
  end

  def test_typing_a_word_hides_the_ring_and_the_arrows_are_the_words_again
    play = play(game: game(board: board("C"), pool: ".ATSDOGTAGCA"))
    play.key(:down)

    assert_predicate play, :focus_visible?
    play.text("a")

    refute_predicate play, :focus_visible?
    play.key(:down)

    refute_predicate play, :focus_visible?, "while a word is typed, the arrows don't move the focus"
    play.key(:escape)
    play.key(:tab)

    assert_predicate play, :focus_visible?
  end

  def test_enter_still_goes_on_from_the_results_until_the_ring_shows
    play = play()
    play.give_up(confirmed: true)
    play.play_again
    play.give_up(confirmed: true)
    play.key(:return)

    assert_equal :official, play.mode, "Enter: back to today"
  end

  def test_tab_hops_regions
    play = play()
    play.key(:tab)

    assert_equal :pool, play.focused.region
    play.key(:tab)

    assert_equal :controls, play.focused.region
    play.key(:tab, shift: true)

    assert_equal :pool, play.focused.region
  end
end
