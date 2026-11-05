# frozen_string_literal: true

require "test_helper"
require "digest"

class DictionaryTest < Minitest::Test
  include CrossEm

  ROOT = File.expand_path("..", __dir__)

  # The license terms ask for the word list and its notices to ship
  # unmodified. These are their digests as they were given to the game.
  SHIPPED = {
    "wordlist.txt" => "356074824089b7db2da8ed7e91bd8c3ecb195dff7b196da6aabce525be56cdc9",
    "wordlist-COPYRIGHT.txt" => "d4d3a67c6bde1a1d503eec2d559dbfb089f7867c5d1348d3b1885388a36a52b0"
  }.freeze

  SHIPPED.each do |name, digest|
    define_method("test_#{name}_is_unmodified") do
      assert_equal digest, Digest::SHA256.file(File.join(ROOT, name)).hexdigest
    end
  end

  def test_the_word_list_loads_into_a_set
    words = Dictionary.parse(File.read(File.join(ROOT, Dictionary::FILE)))

    assert_equal 102_528, words.size # its 102,975 lines repeat some words
    assert words.include?("catalog")
    assert words.include?("CATALOG")
    refute words.include?("qzx")
  end
end
