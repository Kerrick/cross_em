# frozen_string_literal: true

require "presentation_helper"
require "cross_em/presentation/synth"

class SoundsTest < Minitest::Test
  include PresentationTest

  def cues_of(game) = [].tap { |cues| game.subscribe { cues.concat(Sounds.for(it, game)) } }

  # Each sound rendered once, for the mixes below.
  RENDERED = Hash.new { |sounds, name| sounds[name] = Synth.render(name) }

  # A whole game played +gap+ seconds a tap, as [at, name, pitch] plays:
  # every letter placed with the last two swapped, a check that finds
  # them, both sent back, placed again, and the win.
  def plays_of_a_game(gap)
    game = game(pool: "WORDSMITHING")
    now = 0.0
    plays = []
    game.subscribe { |event| Sounds.for(event, game).each { plays << [now + it.delay, it.name, it.pitch] } }
    tap = ->(&action) { action.call && (now += gap) }
    [*0..9, 11, 10].each_with_index do |slot, column|
      tap.call { game.tap_slot(slot) }
      tap.call { game.tap_cell(at(column, 0)) }
    end
    tap.call { game.tap_cell(at(10, 0)) }
    tap.call { game.tap_cell(at(11, 0)) }
    [[1, 10], [0, 11]].each do |slot, column|
      tap.call { game.tap_slot(slot) }
      tap.call { game.tap_cell(at(column, 0)) }
    end

    assert_predicate game, :won?
    plays
  end

  def peak(samples) = samples.map(&:abs).max

  def test_a_whole_game_never_comes_near_full_scale
    [0.08, 0.15, 0.4].each do |gap|
      plays = plays_of_a_game(gap)

      assert_equal %i[check problem], plays.map { it[1] }.select { %i[check problem].include?(it) }.first(2)
      assert_operator peak(Synth.mixdown(plays, rendered: RENDERED)), :<, 10**(-3 / 20.0), "#{gap} s a tap"
    end
  end

  # Even if the sounds that one tap and the taps just before it can ring
  # together all peaked at the same instant, the sum would not clip.
  def test_the_last_tap_and_all_it_could_overlap_cannot_clip
    loudest = %i[button pick place check win].sum { peak(RENDERED[it]) }

    assert_operator loudest, :<, 1.0
  end

  def test_the_win_is_the_loudest_moment_of_a_game
    plays = plays_of_a_game(0.15)
    win = plays.find { it[1] == :win }.first
    mix = Synth.mixdown(plays, rendered: RENDERED)
    before = mix.first((win * Synth::SAMPLE_RATE).round)

    assert_operator peak(before), :<, peak(mix) * (10**(-5 / 20.0))
  end

  def test_placed_letters_climb_the_scale_from_c_to_the_e_above
    pitches = (1..12).map { Sounds.placed(it) }

    assert_equal 1.0, pitches.first
    assert_equal 2.5, pitches.last
    assert_equal pitches.sort, pitches
    assert pitches.all? { |pitch| Sounds::SCALE.any? { it == pitch } }
  end

  def test_putting_down_and_resetting_stay_in_the_scale
    assert_equal [5 / 6r, 3 / 4r], [Sounds::PUT_DOWN, Sounds::RESET]
  end

  def test_each_placed_letter_clacks_a_little_higher
    game = game()
    cues = cues_of(game)
    game.tap_slot(0)
    game.tap_cell(Position::ORIGIN)
    game.tap_slot(1)
    game.tap_cell(at(1, 0))
    places = cues.select { it.name == :place }

    assert_equal %i[pick place pick place], cues.map(&:name)
    assert_operator places.last.pitch, :>, places.first.pitch
  end

  def test_a_check_that_finds_problems_swishes_then_thunks
    game = game(pool: "...........Z", board: board("CAT"))
    cues = cues_of(game)
    game.tap_slot(11)
    game.tap_cell(at(3, 0))

    assert_equal %i[pick place check problem], cues.map(&:name)
    assert_operator cues.last.delay, :>, 0
  end

  def test_giving_up_with_letters_left_does_not_thunk_over_the_phrase
    game = game(board: board("CZ"), pool: "..TSDOGTAGCA")
    cues = cues_of(game)
    game.give_up

    assert_equal %i[check loss], cues.map(&:name)
  end

  def test_giving_up_swishes_and_ends_softly_after_the_sweep
    game = game()
    cues = cues_of(game)
    game.give_up

    assert_equal %i[check loss], cues.map(&:name)
    assert_equal Motion::SWEEP, cues.last.delay
  end
end
