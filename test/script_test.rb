# frozen_string_literal: true

require "presentation_helper"

class ScriptTest < Minitest::Test
  include PresentationTest

  def test_steps_parse_with_their_arguments
    script = Script.parse("pick:K, tap:0:1,word:MILK:0:0:down,giveup")

    assert_equal %i[pick tap word giveup], script.steps.map(&:name)
    assert_equal %w[MILK 0 0 down], script.steps[2].args
  end

  def test_a_wait_holds_back_the_steps_after_it
    script = Script.parse("pick:K,wait:1,tap:0:0,wait:0.5,giveup")
    ready, left, clock = script.due(0.2)

    assert_equal [:pick], ready.map(&:name)
    ready, left, clock = left.due(1.1, clock)

    assert_equal [:tap], ready.map(&:name)
    ready, left, clock = left.due(1.3, clock)

    assert_empty ready
    ready, left, = left.due(1.6, clock)

    assert_equal [:giveup], ready.map(&:name)
    assert_predicate left, :empty?
  end

  def test_a_held_stick_holds_back_the_steps_after_it
    script = Script.parse("pad:dpright,stick:0.8:0:0.5,pad:a")
    ready, left, clock = script.due(0.1)

    assert_equal %i[pad stick], ready.map(&:name)
    assert_equal %w[0.8 0 0.5], ready.last.args
    ready, left, clock = left.due(0.4, clock)

    assert_empty ready, "the stick is still held"
    ready, left, = left.due(0.7, clock)

    assert_equal [:pad], ready.map(&:name)
    assert_predicate left, :empty?
  end
end
