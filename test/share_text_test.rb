# frozen_string_literal: true

require "test_helper"

class ShareTextTest < Minitest::Test
  include CrossEmTest


  def test_a_win_in_the_light
    game = game(pool: "." * 12, board: board("WORDSMITHING"))
    game.give_up

    assert_equal <<~TEXT.chomp, ShareText.for(game).to_s
      Cross ’em 1720 12/12

      🟩🟩🟩🟩🟩🟩
      🟩🟩🟩🟩🟩🟩

      🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦
    TEXT
  end

  def test_a_win_with_empty_cells_in_the_dark
    game = game(pool: "." * 12, board: board("CATS", "A...", "T..."))
    game.give_up

    assert_predicate game, :won?
    assert_equal <<~TEXT.chomp, ShareText.for(game, dark: true).to_s
      Cross ’em 1720 6/12

      🟩🟩🟩🟩🟩🟩
      🟩🟩🟩🟩🟩🟩

      🟦🟦🟦🟦
      🟦⬛⬛⬛
      🟦⬛⬛⬛
    TEXT
  end

  def test_a_loss_in_the_light
    game = game(pool: "D.G...TAG...", board: board("CAT", ".Z.", "....O"))
    game.give_up

    assert_equal <<~TEXT.chomp, ShareText.for(game).to_s
      Cross ’em 1720 2/12

      🟥🟨🟥🟨🟨🟨
      🟥🟥🟥🟨🟨🟨

      🟦🟥🟦⬜⬜
      ⬜🟥⬜⬜⬜
      ⬜⬜⬜⬜🟥
    TEXT
  end

  def test_a_loss_in_the_dark
    game = game(pool: "D.G...TAG...", board: board("CAT", ".Z.", "....O"))
    game.give_up

    assert_equal <<~TEXT.chomp, ShareText.for(game, dark: true).to_s
      Cross ’em 1720 2/12

      🟥🟨🟥🟨🟨🟨
      🟥🟥🟥🟨🟨🟨

      🟦🟥🟦⬛⬛
      ⬛🟥⬛⬛⬛
      ⬛⬛⬛⬛🟥
    TEXT
  end

  def test_giving_up_with_nothing_placed_shares_only_the_pool
    game = game(pool: "CATSDOGTAGCA")
    game.give_up

    assert_equal "Cross ’em 1720 0/12\n\n🟥🟥🟥🟥🟥🟥\n🟥🟥🟥🟥🟥🟥", ShareText.for(game).to_s
  end
end
