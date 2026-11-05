# frozen_string_literal: true

require "presentation_helper"

class SoundsTest < Minitest::Test
  include PresentationTest

  def cues_of(game) = [].tap { |cues| game.subscribe { cues.concat(Sounds.for(it, game)) } }

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

  def test_giving_up_swishes_and_ends_softly_after_the_sweep
    game = game()
    cues = cues_of(game)
    game.give_up

    assert_equal %i[check loss], cues.map(&:name)
    assert_equal Motion::SWEEP, cues.last.delay
  end
end
