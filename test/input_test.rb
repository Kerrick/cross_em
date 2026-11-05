# frozen_string_literal: true

require "presentation_helper"

class InputTest < Minitest::Test
  include PresentationTest

  def router = InputRouter.new

  def test_a_finger_is_one_press_not_two
    assert router.touch(:pressed, 7, 10, 20, :touchscreen, false)
    assert_nil router.mouse(:pressed, 10, 20, button: 1, istouch: true), "SDL's made-up mouse press"
  end

  def test_trackpad_touches_and_mice_turned_into_touches_are_not_presses
    assert_nil router.touch(:pressed, 1, 0.5, 0.5, :touchpad, false)
    assert_nil router.touch(:pressed, 1, 10, 20, :touchscreen, true)
  end

  def test_only_the_main_mouse_button_presses
    assert_equal :mouse, router.mouse(:pressed, 1, 2, button: 1).id
    assert_nil router.mouse(:pressed, 1, 2, button: 2)
  end

  def test_a_press_that_moves_far_enough_is_a_drag_and_stays_one
    gesture = Gesture.start(Pointer.new(phase: :pressed, id: 1, x: 100.0, y: 100.0), [:board])

    assert_predicate gesture.moved(105, 103, 16), :tap?
    dragged = gesture.moved(120, 100, 16)

    refute_predicate dragged, :tap?
    refute_predicate dragged.moved(100, 100, 16), :tap?, "coming back does not make it a tap"
  end
end
