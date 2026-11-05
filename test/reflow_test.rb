# frozen_string_literal: true

require "presentation_helper"

class ReflowTest < Minitest::Test
  include PresentationTest

  def test_hard_wrapped_paragraphs_join_and_short_lines_stay
    text = <<~TEXT
      This is a long line that the author wrapped at about seventy columns,
      and this line goes on from it.

      Grady Ward
      3449 Martha Ct.
    TEXT
    pieces = Reflow.parse(text)

    assert_equal ["This is a long line that the author wrapped at about seventy columns, and this line goes on from it.",
                  "Grady Ward", "3449 Martha Ct."], pieces.grep(Reflow::Text).map(&:text)
    assert_kind_of Reflow::Gap, pieces[1]
  end

  def test_indents_quotes_and_rules_carry_over
    text = "-----------------\n  > I was wondering what the copyright status of your word list is, as\n  > it seems to lack one.\n"
    rule, quoted = Reflow.parse(text)

    assert_kind_of Reflow::Rule, rule
    assert_equal [2, "> ", "I was wondering what the copyright status of your word list is, as it seems to lack one."],
                 [quoted.indent, quoted.quote, quoted.text]
  end

  def test_no_word_is_lost
    text = File.read(File.expand_path("../wordlist-COPYRIGHT.txt", __dir__))
    words = Reflow.parse(text).grep(Reflow::Text).flat_map { it.text.split }

    assert_equal text.split.reject { it == ">" || it.match?(/\A[-=*_]{8,}\z/) }, words
  end
end
