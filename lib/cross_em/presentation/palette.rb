# frozen_string_literal: true

module CrossEm
  module Presentation
    # Every color the game paints with, by what it means rather than what
    # it looks like. There are two: Palette::LIGHT, "morning paper", and
    # Palette::DARK, "night edition". The tiles keep their ivory in both,
    # since they are objects and objects keep their material.
    class Palette < Data.define(
      :page, :page_shade, :grid_dot, :rule, :ink, :ink_muted, :card, :scrim, :shadow,
      :tile_face, :tile_edge, :tile_letter, :target, :problem,
      :finished_face, :finished_edge, :finished_letter, :won, :glow, :confetti
    )
      hex = Color.method(:hex)

      LIGHT = new(
        page: hex["#F3EDE2"], page_shade: hex["#E7DECF"], grid_dot: hex["#D3C7B0"], rule: hex["#D9CFBC"],
        ink: hex["#1F1A14"], ink_muted: hex["#6B6256"], card: hex["#FAF6EE"], scrim: hex["#1F1A14", 0.42],
        shadow: hex["#3A2A12", 0.16],
        tile_face: hex["#FBF4E3"], tile_edge: hex["#D3BF97"], tile_letter: hex["#1F1A14"],
        target: hex["#1F7A8C"], problem: hex["#C8432B"],
        finished_face: hex["#24427F"], finished_edge: hex["#172C57"], finished_letter: hex["#FBF4E3"],
        won: hex["#2E7D4F"], glow: hex["#FFFFFF", 0.6],
        confetti: [hex["#2E7D4F"], hex["#3B6FD4"], hex["#E2A93B"], hex["#1F7A8C"], hex["#C8432B"]].freeze
      )

      DARK = new(
        page: hex["#14171D"], page_shade: hex["#0E1014"], grid_dot: hex["#353C4A"], rule: hex["#2A2F3A"],
        ink: hex["#ECE6DA"], ink_muted: hex["#9AA0AC"], card: hex["#1B1F27"], scrim: hex["#05070A", 0.62],
        shadow: hex["#000000", 0.4],
        tile_face: hex["#E9DFC8"], tile_edge: hex["#A8956F"], tile_letter: hex["#1F1A14"],
        target: hex["#5CC4D6"], problem: hex["#FF7A5C"],
        finished_face: hex["#4A73C9"], finished_edge: hex["#2F4F94"], finished_letter: hex["#FBF4E3"],
        won: hex["#5BC08A"], glow: hex["#FFFFFF", 0.16],
        confetti: [hex["#5BC08A"], hex["#6E9BF0"], hex["#F2C35B"], hex["#5CC4D6"], hex["#FF7A5C"]].freeze
      )

      def self.for(dark) = dark ? DARK : LIGHT
    end
  end
end
