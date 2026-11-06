# frozen_string_literal: true

require "presentation_helper"

class PlayTest < Minitest::Test
  include PresentationTest

  def setup
    @host = FakeHost.new(dark: true)
    @session = Session.new(archive: Archive.new(Archive::Memory.new), referee:)
  end

  def play(game: game(), clock: Clock.real, settings: Settings.default)
    Play.new(game:, session: @session, settings:, host: @host, measure: FakeMeasure.new, clock:).tap do
      it.resize(width: 390, height: 844, units: units)
    end
  end

  def tap(play, x, y, id: :mouse)
    play.press(Pointer.new(phase: :pressed, id:, x:, y:))
    play.release(Pointer.new(phase: :released, id:, x:, y:))
  end

  def tap_rect(play, rect) = tap(play, rect.center_x, rect.center_y)

  def test_a_tap_on_a_pool_letter_then_a_target_places_it
    play = play()
    tap_rect(play, play.layout.pool[2])

    assert_equal 2, play.game.selected
    tap_rect(play, play.view.rect_of(Position::ORIGIN))

    assert_equal "T", play.game.board[Position::ORIGIN]
  end

  def test_a_tap_on_a_placed_letter_sends_it_back
    play = play(game: game(pool: ".ATSDOGTAGCA", board: board("C")))
    tap_rect(play, play.view.rect_of(Position::ORIGIN))

    assert_predicate play.game.board, :empty?
    assert_equal "C", play.game.pool[0]
  end

  def test_a_drag_on_the_board_pans_and_is_not_a_tap
    play = play(game: game(pool: "............", board: board("CATSDOGTAGCATS")))
    before = play.view
    start = play.view.rect_of(at(7, 0))
    play.press(Pointer.new(phase: :pressed, id: 1, x: start.center_x, y: start.center_y))
    play.move(Pointer.new(phase: :moved, id: 1, x: start.center_x - 60, y: start.center_y))
    play.release(Pointer.new(phase: :released, id: 1, x: start.center_x - 60, y: start.center_y))

    assert_equal before.x - 60, play.view.x
    assert_equal 14, play.game.board.size, "nothing was sent back"
  end

  def test_give_up_asks_again_and_forgets_after_three_seconds
    play = play()
    give_up = play.layout.controls.give_up
    tap_rect(play, give_up)

    assert_predicate play, :armed?
    assert_equal Copy::CONFIRM_GIVE_UP, play.label(:give_up)
    play.update(3.1)

    refute_predicate play, :armed?
    tap_rect(play, give_up)
    play.update(1)
    tap_rect(play, give_up)

    assert_predicate play.game, :lost?
  end

  def test_after_the_game_the_result_can_be_copied_in_the_current_appearance
    play = play()
    play.give_up(confirmed: true)
    tap_rect(play, play.layout.results.copy)

    assert_equal ShareText.for(play.game, dark: true).to_s, @host.copied.last
    assert_equal Copy::COPIED, play.label(:copy)
    assert_includes @host.sounds, :copied
  end

  def test_the_controls_stop_working_once_the_game_is_over
    play = play()
    play.give_up(confirmed: true)

    refute play.enabled?(:shuffle)
    assert_nil play.layout.controls
  end

  def type(play, text) = text.each_char { play.text(it) }

  def test_a_typed_word_that_fits_one_place_goes_there_through_the_game
    play = play(game: game(pool: "CATSDOGTAGCA"))
    events = events_of(play.game)
    type(play, "cat")

    assert_equal "CAT", play.typing.draft
    assert_predicate play.game.board, :empty?, "nothing is placed while typing"
    play.key(:return)

    assert_equal "CAT", play.game.board.words.first.text
    assert_equal [0, 1, 2], events.grep(Events::Placed).map(&:index), "each letter from the first slot holding it"
    assert_equal "", play.typing.draft
  end

  def test_space_places_a_typed_word_and_with_nothing_typed_shuffles
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAT")
    play.key(:space)

    assert_equal 3, play.game.board.size
    before = play.game.pool
    play.key(:space)

    refute_equal before, play.game.pool
  end

  def test_extending_a_word_places_only_the_new_letter
    play = play(game: game(pool: "CATSXXXXXXXX"))
    type(play, "CAT")
    play.key(:return)
    type(play, "CATS")
    play.key(:return)

    assert_equal %w[CATS], play.game.board.words.map(&:text)
  end

  def test_several_places_are_offered_numbered_and_tab_and_digits_choose
    # CAT across; TA fits down through CAT's A (adding a T above it) or
    # down from its T (adding an A below), and only those cross.
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAT")
    play.key(:return)
    type(play, "TA")
    play.key(:return)

    assert_predicate play.typing, :choosing?
    assert_equal 2, play.typing.choice.size
    play.key(:tab)

    assert_equal 1, play.typing.choice.index
    play.key(:tab, shift: true)

    assert_equal 0, play.typing.choice.index
    play.text("2")

    refute_predicate play.typing, :choosing?
    assert_equal "A", play.game.board[at(2, 1)], "the second place, in reading order"
    assert_equal 4, play.game.board.size
  end

  def test_a_tap_lets_go_of_the_places_being_chosen_so_enter_looks_again
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAT")
    play.key(:return)
    type(play, "TA")
    play.key(:return)
    tap_rect(play, play.view.rect_of(Position::ORIGIN)) # sends the C back

    refute_predicate play.typing, :choosing?
    assert_equal "TA", play.typing.draft, "the draft stays"
    assert_empty play.typing.cells
    play.key(:return)

    assert play.typing.choosing? || play.typing.draft.empty?, "Enter worked out where it fits now"
  end

  def test_a_shuffle_lets_go_of_the_places_being_chosen
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAT")
    play.key(:return)
    type(play, "TA")
    play.key(:return)
    play.press_button(:shuffle)

    refute_predicate play.typing, :choosing?
  end

  def test_a_tap_on_a_place_shown_places_the_word_there
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAT")
    play.key(:return)
    type(play, "TA")
    play.key(:return)
    other = play.typing.choice.placements[1]
    play.update(1.0) # the camera settles on the places
    tap_rect(play, play.view.rect_of(other.fresh_positions.first))

    refute_predicate play.typing, :choosing?
    assert_equal "A", play.game.board[at(2, 1)], "the second place, tapped"
  end

  def test_shuffle_waits_for_letters_in_the_pool
    play = play(game: game(pool: "C...........", board: board("AT")))

    assert play.enabled?(:shuffle)
    play.game.place_letter(0, at(2, 0))

    assert_predicate play.game.pool, :empty?
    refute play.enabled?(:shuffle)
    before = @host.sounds.size
    play.key(:space)

    assert_equal before, @host.sounds.size, "Space does nothing either"
  end

  def test_with_every_letter_down_the_pool_gives_way_and_letters_still_fly_from_their_slots
    play = play(game: game(pool: "C...........", board: board("AT")))
    play.game.place_letter(0, at(2, 0))

    assert_empty play.layout.pool
    refute_nil play.pool_slot(0)
    tap_rect(play, play.view.rect_of(at(2, 0)))

    assert_equal 12, play.layout.pool.size, "a letter sent back brings the pool back"
  end

  def test_the_practice_chip_goes_back_to_today
    play = play()
    finish_official(play)
    play.play_again
    tap_rect(play, play.layout.wordmark)

    assert_equal :official, play.mode
  end

  def test_a_resting_mouse_names_a_header_button
    play = play(settings: Settings.default.with(instructions_seen: true))
    button = play.layout.help_button
    play.hover(button.center_x, button.center_y)

    assert_nil play.tooltip, "not at once"
    play.update(1.0)

    assert_equal [Copy::TIPS[:help], button], play.tooltip
    play.hover(1, play.layout.height - 1)

    assert_nil play.tooltip
  end

  def test_esc_goes_back_from_choosing_to_the_draft_then_clears_it
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAT")
    play.key(:return)
    type(play, "TA")
    play.key(:return)
    play.key(:escape)

    refute_predicate play.typing, :choosing?
    assert_equal "TA", play.typing.draft
    play.key(:escape)

    assert_equal "", play.typing.draft
    assert_equal 3, play.game.board.size
  end

  def test_a_word_that_fits_nowhere_says_why_and_keeps_the_draft
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "crab")
    play.key(:return)

    assert_equal :missing, play.typing.misfit.reason
    assert_equal [1, 3], play.typing.short, "the R and the B are marked, before and after Enter"
    assert_equal "CRAB", play.typing.draft
    assert_equal :problem, @host.sounds.last, "a thunk, with the draft's shake"
    assert_in_delta play.time, play.typing.refused_at
    play.key(:backspace)

    assert_nil play.typing.misfit, "editing the word clears it"
    assert_equal "CRA", play.typing.draft
  end

  def test_backspace_with_nothing_typed_takes_back_the_last_typed_word_then_the_one_before
    play = play(game: game(pool: "CATSXXXXXXXX"))
    type(play, "CAT")
    play.key(:return)
    type(play, "CATS")
    play.key(:return)
    play.key(:backspace)

    assert_equal %w[CAT], play.game.board.words.map(&:text), "only the S it added"
    play.key(:backspace)

    assert_predicate play.game.board, :empty?
  end

  def test_space_never_shuffles_while_choosing
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAT")
    play.key(:return)
    type(play, "TA")
    play.key(:return)
    pool = play.game.pool
    play.key(:space)

    assert_equal 4, play.game.board.size, "space placed the word shown"
    assert_equal pool.slots.compact.size - 1, play.game.pool.slots.compact.size
  end

  def test_typing_puts_down_a_letter_picked_up_with_a_tap
    play = play()
    play.pick(3)
    type(play, "C")

    assert_nil play.game.selected
    assert_equal "C", play.typing.draft
  end

  def test_a_typed_word_that_fills_the_board_is_checked_and_wins_as_taps_do
    play = play(game: game(pool: "WORDSMITHING"))
    type(play, "wordsmithing")
    play.key(:return)

    assert_predicate play.game, :won?
  end

  def test_typing_does_nothing_once_the_game_is_over_or_under_a_sheet
    play = play()
    play.open(:help)
    type(play, "CAT")

    assert_equal "", play.typing.draft
    play.close_sheet
    play.give_up(confirmed: true)
    type(play, "CAT")

    assert_equal "", play.typing.draft
  end

  def test_the_pool_marks_the_letters_a_draft_would_use
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAA")

    assert_equal Set[0, 1, 8], play.typing.pool_marks
  end

  def test_choosing_keeps_the_place_shown_in_the_boards_frame
    play = play(game: game(pool: "CATSDOGTAGCA"))
    type(play, "CAT")
    play.key(:return)
    type(play, "TA")
    play.key(:return)
    content = play.view.content

    play.typing.choice.current.positions.each { assert content.include?(it), "#{it} framed" }
  end

  def test_closing_how_to_play_remembers_it_was_read
    play = play()
    play.open(:help)
    play.key(:escape)

    refute_predicate play, :sheet?
    assert @host.settings.instructions_seen
  end

  def test_credits_open_over_how_to_play_and_close_back_to_it
    play = play()
    play.open(:help)
    play.open(:credits)

    assert_equal :credits, play.sheet.kind
    play.close_sheet

    assert_equal :help, play.sheet.kind
  end

  def test_a_tap_outside_a_sheet_closes_it_and_reaches_nothing_else
    play = play()
    play.open(:help)
    tap(play, 1, 843)

    refute_predicate play, :sheet?
    assert_nil play.game.selected
  end

  def test_credits_are_two_taps_from_the_header
    play = play(settings: Settings.default.with(instructions_seen: true))
    tap_rect(play, play.layout.help_button)
    tap_rect(play, play.sheet_layout.link.rect)

    assert_equal :credits, play.sheet.kind
  end

  def test_the_header_buttons_change_settings
    play = play()
    tap_rect(play, play.layout.sound_button)

    assert @host.settings.muted
    tap_rect(play, play.layout.theme_button)

    assert_equal :light, @host.settings.appearance
  end

  def test_flipping_the_page_back_to_the_systems_follows_the_system_again
    @host = FakeHost.new(dark: false, system_theme: :dark) # the player chose the light page
    play = play(settings: Settings.default.with(appearance: :light))
    tap_rect(play, play.layout.theme_button)

    assert_equal :system, @host.settings.appearance
  end

  def test_the_next_puzzle_is_offered_only_once_its_day_has_come
    day = Day.numbered(1720)
    play = play(game: game(day:), clock: Clock.pretending(day.date))
    play.give_up(confirmed: true)

    assert_nil play.next_day
    tomorrow = play(game: game(day:), clock: Clock.pretending(day.succ.date))
    tomorrow.give_up(confirmed: true)

    assert_equal day.succ, tomorrow.next_day
    tap_rect(tomorrow, tomorrow.layout.results.countdown)

    assert_equal 1, @host.next_days
  end

  def test_backspace_puts_down_a_letter_then_sends_back_the_last_placed
    play = play()
    play.pick(0)
    play.tap_cell(Position::ORIGIN)
    play.pick(1)
    play.tap_cell(at(1, 0))
    play.pick(2)
    play.key(:backspace)

    assert_nil play.game.selected
    play.key(:backspace)

    assert_equal ["C"], play.game.board.cells.values
  end

  def test_the_pointer_is_a_hand_over_what_a_click_would_change
    play = play()
    slot = play.layout.pool[0]

    assert_equal :hand, play.cursor_at(slot.center_x, slot.center_y)
    reset = play.layout.controls.reset

    assert_equal :arrow, play.cursor_at(reset.center_x, reset.center_y), "nothing to reset yet"
  end

  def test_a_game_in_progress_keeps_its_day_past_midnight
    day = Day.numbered(1720)
    play = play(game: game(day:), clock: Clock.pretending(day.succ.date))
    play.key(:return)
    play.press_button(:next)

    assert_nil play.next_day
    assert_equal 0, @host.next_days
  end

  def test_a_copy_that_fails_says_so_and_does_not_ding
    @host = FakeHost.new(clipboard: false)
    play = play()
    play.give_up(confirmed: true)
    play.copy

    assert_equal Copy::COPY_FAILED, play.label(:copy)
    refute_includes @host.sounds, :copied
  end

  def test_a_new_game_forgets_the_press_and_the_lift_of_the_last
    play = play()
    play.press(Pointer.new(phase: :pressed, id: 1, x: 5.0, y: 300.0))
    play.pick(0)
    play.official = game(day: Day.numbered(1721))

    assert_nil play.gesture
    tap_rect(play, play.layout.pool[3])

    assert_equal 3, play.game.selected, "a tap is heard at once"
  end

  def finish_official(play)
    play.give_up(confirmed: true)
    play.game
  end

  def test_play_again_starts_practice_of_the_same_day_and_never_saves_it
    play = play(game: @session.open(Day.numbered(1720)))
    official = play.official
    official.place_letter(0, Position::ORIGIN)
    finish_official(play)
    saved = @session.archive[official.day.number]
    tap_rect(play, play.layout.results.again)

    assert_predicate play, :practice?
    assert_equal official.day, play.game.day
    assert_predicate play.game.board, :empty?
    assert_equal 12, play.game.pool.unused_count
    type(play, "cat")
    play.key(:return)
    play.give_up(confirmed: true)

    assert_same saved, @session.archive[official.day.number], "the record is untouched"
    assert_equal 1, @session.stats(official.day).played
    assert_same official, play.official
    assert_equal 1, official.board.size
  end

  def test_practice_shows_no_statistics_and_no_share_button
    play = play()
    finish_official(play)
    play.play_again
    play.give_up(confirmed: true)

    assert_nil play.stats
    assert_equal :today, play.primary
    assert_equal Copy::BACK_TO_TODAY, play.label(:today)
    play.copy
    play.key(:c, command: true)

    assert_empty @host.copied, "a practice result is never shared as a real one"
  end

  def test_practice_hides_a_run_out_clock_while_the_days_game_is_unfinished
    yesterday = Day.numbered(1719)
    play = play(game: game(day: yesterday), clock: Clock.pretending(Day.numbered(1720).date))
    play.play_again
    play.give_up(confirmed: true)

    assert_predicate play.countdown, :done?
    assert_nil play.next_day, "the day's game is unfinished, so no new puzzle yet"
    refute_predicate play, :countdown?, "no 00:00:00 with nothing after it"
    assert_equal :today, play.primary, "Back to today is the way on"
  end

  def test_back_to_today_returns_to_the_official_game_as_it_was
    play = play()
    official = finish_official(play)
    play.play_again
    play.give_up(confirmed: true)
    tap_rect(play, play.layout.results.copy) # in practice, "Back to today"

    assert_equal :official, play.mode
    assert_same official, play.game
  end

  def test_the_header_opens_past_puzzles_listing_today_first
    play = play(settings: Settings.default.with(instructions_seen: true))
    tap_rect(play, play.layout.archive_button)

    assert_equal :archive, play.sheet.kind
    assert_equal play.official.day.number, play.sheet_layout.list.days.first.number
  end

  def past_day_finished(number, status: :lost)
    day = Day.numbered(number)
    @session.archive.save(Record.new(day:, pool: Pool.new(slots: day.letters.drop(1) + [nil]),
                                     board: Board.new(cells: {Position::ORIGIN => day.letters.first}), status:))
  end

  def test_a_finished_past_day_opens_its_board_to_look_at_and_play_it_again
    play = play(clock: Clock.pretending(Day.numbered(1720).date))
    past_day_finished(1700)
    saved = @session.archive[1700]
    play.open(:archive)
    play.open_day(1700)

    assert_predicate play, :review?
    refute_predicate play, :sheet?
    assert_predicate play.game, :lost?
    assert_equal saved.board, play.game.board
    assert_equal Copy::PLAY_AGAIN, play.label(:again)
    play.press_button(:again)

    assert_predicate play, :practice?
    assert_equal 1700, play.game.day.number
    assert_predicate play.game.board, :empty?
    assert_same saved, @session.archive[1700]
  end

  def test_a_past_day_never_finished_opens_as_practice_and_stays_unplayed
    play = play(clock: Clock.pretending(Day.numbered(1720).date))
    play.open_day(1500)

    assert_predicate play, :practice?
    play.give_up(confirmed: true)

    assert_nil @session.archive[1500]
  end

  def test_today_in_past_puzzles_is_the_official_game
    play = play(game: game(day: Day.numbered(1720)), clock: Clock.pretending(Day.numbered(1720).date))
    official = play.official
    play.open_day(1500)
    play.open(:archive)
    play.open_day(1720)

    assert_same official, play.game
    refute_predicate play, :sheet?
  end

  def test_the_keyboard_walks_past_puzzles_and_opens_a_day
    play = play(clock: Clock.pretending(Day.numbered(1720).date))
    play.open(:archive)
    play.key(:down)

    assert_equal 1720, play.sheet.focus, "the first move lands on the top day"
    play.key(:down)
    play.key(:down)

    assert_equal 1718, play.sheet.focus
    play.key(:end)

    assert_equal 0, play.sheet.focus
    assert_equal play.sheet_layout.most_scroll, play.sheet.scroll, "the oldest is scrolled into view"
    play.key(:home)

    assert_equal 1720, play.sheet.focus
    assert_equal 0, play.sheet.scroll
    play.key(:pagedown)
    play.key(:return)

    assert_predicate play, :practice?
    assert_operator play.game.day.number, :<, 1720
  end

  def test_a_tap_on_a_day_in_past_puzzles_opens_it
    play = play(clock: Clock.pretending(Day.numbered(1720).date))
    play.open(:archive)
    layout = play.sheet_layout
    row = layout.list.day_row(1719)
    tap_rect(play, layout.row_rect(row, play.sheet.scroll))

    assert_predicate play, :practice?
    assert_equal 1719, play.game.day.number
  end
end
