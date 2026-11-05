# frozen_string_literal: true

require "presentation_helper"

class SoundsTest < Minitest::Test
  include PresentationTest

  def test_each_placed_letter_clacks_a_little_higher
    game = game()
    cues = []
    game.subscribe { cues << Sounds.for(it, game) }
    game.tap_slot(0)
    game.tap_cell(Position::ORIGIN)
    game.tap_slot(1)
    game.tap_cell(at(1, 0))

    places = cues.compact.select { it.name == :place }

    assert_equal %i[pick place pick place], cues.compact.map(&:name)
    assert_operator places.last.pitch, :>, places.first.pitch
  end

  def test_giving_up_sounds_only_the_ending
    game = game()
    cues = []
    game.subscribe { cues << Sounds.for(it, game) }
    game.give_up

    assert_equal [:loss], cues.compact.map(&:name)
  end
end
