# frozen_string_literal: true

require "presentation_helper"

class SheetTest < Minitest::Test
  include PresentationTest

  def build(blocks, safe: rect(0, 0, 390, 844)) = SheetLayout.build(blocks:, safe:, units: units, measure: FakeMeasure.new)

  def test_text_wraps_to_the_card_and_stacks_down
    layout = build([Block.heading("Title"), Block.body("word " * 40)])

    assert_operator layout.lines.size, :>, 3
    assert_equal layout.lines.map(&:y).sort, layout.lines.map(&:y)
    layout.lines.each { assert_operator it.text.length * 8, :<=, layout.body.width }
  end

  def test_an_example_board_takes_its_rows_of_room_and_centres_its_cells
    layout = build([Block.body("Before."), Block.example([["A", 0, 0], ["B", 1, 0], ["C", 1, 1]], [2, 1]),
                    Block.body("After.")])
    example = layout.examples.first

    assert_operator example.rect.y, :>=, layout.lines.first.y + 20
    assert_operator layout.lines.last.y, :>=, example.rect.bottom
    assert_equal layout.body.width, example.rect.width
    first, last = example.cell_rect(0, 0, example.rect), example.cell_rect(2, 1, example.rect)

    assert_equal example.rect.right - last.right, first.x - example.rect.x
    assert_equal example.rect.bottom - last.bottom, first.y - example.rect.y
  end

  def test_a_link_sits_in_the_title_bar_beside_the_close_button
    layout = SheetLayout.build(blocks: [Block.body("word " * 400)], safe: rect(0, 0, 390, 844), units: units,
                               measure: FakeMeasure.new, link: [:credits, "Credits"])
    link = layout.link.rect

    assert_equal :credits, layout.link.id
    assert_operator link.right, :<=, layout.close.x
    assert_operator link.bottom, :<=, layout.body.y
    assert_operator link.height, :>=, 44
    assert_nil build([Block.body("Short.")]).link
  end

  def test_a_license_keeps_its_lines_and_scrolls_when_long
    text = (1..200).map { "Line #{it} of the license." }.join("\n")
    layout = build([Block.license(text)])

    assert_equal 200, layout.lines.size
    assert_predicate layout, :scrolls?
    assert_equal layout.content_height - layout.body.height, layout.most_scroll
  end

  def test_a_short_sheet_is_only_as_tall_as_its_content
    layout = build([Block.body("Short.")], safe: rect(0, 0, 1280, 800))

    assert_operator layout.card.height, :<, 300
    refute_predicate layout, :scrolls?
  end

  def test_controls_are_found_where_they_are_drawn_scrolled_or_not
    layout = build([Block.license("x\n" * 100), Block.buttons([[:credits, "Credits", false], [:close, "Play", true]])])
    play = layout.controls.find { it.id == :close }
    scroll = layout.most_scroll
    x = layout.body.x + play.rect.center_x
    y = layout.body.y + play.rect.center_y - scroll

    assert_equal :close, layout.control_at(x, y, scroll)&.id
    assert_nil layout.control_at(x, y + scroll, 0), "off the bottom of the body"
  end

  def test_scrolling_stops_at_either_end
    layout = build([Block.license("x\n" * 100)])
    sheet = Sheet.open(:credits)

    assert_equal 0, sheet.scrolled(-50, layout).scroll
    assert_equal layout.most_scroll, sheet.scrolled(1_000_000, layout).scroll
  end
end
