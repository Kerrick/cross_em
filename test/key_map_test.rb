# frozen_string_literal: true

require "presentation_helper"

class KeyMapTest < Minitest::Test
  include PresentationTest

  def setup
    @host = FakeHost.new
    @session = Session.new(archive: Archive.new(Archive::Memory.new), referee:)
  end

  def play(game: game(), touch: false)
    Play.new(game:, session: @session, settings: Settings.default.with(instructions_seen: true), host: @host,
             measure: FakeMeasure.new, touch:, command_key: "Cmd").tap { it.resize(width: 390, height: 844, units: units) }
  end

  def action(play, key, command: false, shift: false) = KeyMap.key_action(play, key, command:, shift:)

  def test_letters_type_and_other_text_names_its_action
    play = play()

    assert_equal [:type, "C"], KeyMap.text_action(play, "c")
    assert_equal [:choose, 3], KeyMap.text_action(play, "3")
    assert_equal [:help], KeyMap.text_action(play, "?")
    play.act(:help)

    assert_equal [:credits], KeyMap.text_action(play, "c"), "in How to play, C opens the Credits"
  end

  def test_every_button_has_a_key_that_is_not_a_bare_letter
    play = play()
    expected = {
      [:space, false, false] => [:space], [:backspace, false, true] => [:reset], [:backspace, true, false] => [:reset],
      [:backspace, false, false] => [:erase], [:escape, false, true] => [:give_up], [:escape, false, false] => [:escape],
      [:return, false, true] => [:again], [:return, false, false] => [:enter], [:tab, false, false] => [:hop, 1],
      [:tab, false, true] => [:hop, -1], [:f1, false, false] => [:help], [:t, true, false] => [:today],
      [:p, true, false] => [:archive], [:d, true, false] => [:theme], [:s, true, false] => [:sound],
      [:c, true, false] => [:copy]
    }
    expected.each do |(key, command, shift), named|
      assert_equal named, action(play, key, command:, shift:), "#{key} command:#{command} shift:#{shift}"
    end
    assert_nil action(play, :p), "a letter alone types; it never acts"
  end

  def test_shift_backspace_resets_a_full_board_with_problems
    play = play(game: game(pool: "C...........", board: board("AZ")))
    "caz".each_char { play.text(it) }
    play.key(:return)

    assert_equal 3, play.game.board.size
    refute_predicate play.game.check, :clean?, "every letter is down, and CAZ isn't a word"
    play.key(:backspace, shift: true)

    assert_predicate play.game.board, :empty?
  end

  def test_shift_esc_gives_up_when_pressed_twice
    play = play()
    play.key(:escape, shift: true)

    assert_predicate play, :armed?
    assert_predicate play.game, :playing?
    play.key(:escape, shift: true)

    assert_predicate play.game, :over?
  end

  def test_after_the_game_shift_enter_plays_again_and_enter_goes_back_to_today
    play = play()
    play.give_up(confirmed: true)
    play.key(:return, shift: true)

    assert_predicate play, :practice?
    play.give_up(confirmed: true)
    play.key(:return)

    assert_equal :official, play.mode
  end

  def test_the_chips_key_goes_back_to_today_during_practice
    play = play()
    play.give_up(confirmed: true)
    play.play_again
    play.key(:t, command: true)

    assert_equal :official, play.mode
  end

  def test_the_headers_keys_open_past_puzzles_how_to_play_and_switch_the_page_and_sound
    play = play()
    play.key(:p, command: true)

    assert_equal :archive, play.sheet.kind
    play.key(:escape)
    play.key(:f1)

    assert_equal :help, play.sheet.kind
    play.text("c")

    assert_equal :credits, play.sheet.kind
    play.key(:escape)
    play.key(:escape)
    play.key(:d, command: true)

    refute_nil @host.settings&.appearance
    play.key(:s, command: true)

    assert @host.settings.muted
  end

  def test_space_shuffles_and_a_button_that_is_not_live_ignores_its_key
    play = play(game: game(pool: "CATSDOGTAGCA"))
    events = []
    play.game.subscribe { events << it }
    play.key(:space)

    assert_kind_of Events::Shuffled, events.last
    before = play.game.board
    play.key(:backspace, shift: true)

    assert_same before, play.game.board, "nothing on the board to reset"
  end

  def test_keycaps_show_on_a_computer_only_with_the_systems_command_key
    assert_equal ["Shift", :backspace], play.keycaps(:reset)
    assert_equal ["Cmd", "P"], play.keycaps(:archive)
    assert_nil play(touch: true).keycaps(:reset)
  end
end
