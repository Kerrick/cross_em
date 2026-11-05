# frozen_string_literal: true

require "presentation_helper"

class PlayTest < Minitest::Test
  include PresentationTest

  def setup
    @host = FakeHost.new(dark: true)
    @session = Session.new(archive: Archive.new(Archive::Memory.new), referee:)
  end

  def play(game: game(), clock: Clock.real, settings: Settings.default)
    Play.new(game:, session: @session, dictionary:, settings:, host: @host, measure: FakeMeasure.new, clock:).tap do
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

  def test_typing_a_letter_picks_it_up_and_again_picks_the_next_one
    play = play(game: game(pool: "CATSDOGTAGCA"))
    play.text("a")

    assert_equal 1, play.game.selected
    play.text("A")

    assert_equal 8, play.game.selected
    play.key(:escape)

    assert_nil play.game.selected
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

  def test_the_header_buttons_change_settings
    play = play()
    tap_rect(play, play.layout.sound_button)

    assert @host.settings.muted
    tap_rect(play, play.layout.theme_button)

    assert_equal :light, @host.settings.appearance
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
end
