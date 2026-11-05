# frozen_string_literal: true

# Writes every game sound as a 16-bit mono WAV, so a human can listen,
# and game.wav: a whole game as the Speaker would play it, cued by
# Presentation::Sounds, from the first pick through a check that finds
# problems to the win.
#   ruby script/preview_sounds.rb DIRECTORY
require "fileutils"
require_relative "../lib/cross_em"
require_relative "../lib/cross_em/presentation"
require_relative "../lib/cross_em/presentation/synth"

Synth = CrossEm::Presentation::Synth
Sounds = CrossEm::Presentation::Sounds

def wav(samples)
  data = samples.map { (it.clamp(-1.0, 1.0) * 32_767).round }.pack("s<*")
  header = ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, Synth::SAMPLE_RATE,
            Synth::SAMPLE_RATE * 2, 2, 16, "data", data.bytesize]
  header.pack("a4Va4a4VvvVVvva4V") + data
end

# WORDSMITHING placed across with its last two letters swapped, a shuffle
# along the way, both sent back once the check finds them, and placed
# again: [seconds after the last tap, what the player does].
def a_game
  game = CrossEm::Game.new(day: CrossEm::Day.numbered(1), pool: CrossEm::Pool.new(slots: "WORDSMITHING".chars),
                           board: CrossEm::Board.empty, status: :playing,
                           referee: CrossEm::Referee.new(CrossEm::Dictionary.new(%w[wordsmithing])))
  cell = ->(column) { CrossEm::Position.new(column:, row: 0) }
  place = lambda do |letter, column|
    [[0.45, -> { game.tap_slot(game.pool.slots.index(letter)) }], [0.35, -> { game.tap_cell(cell[column]) }]]
  end
  taps = "WORDSMITHIGN".chars.each_with_index.flat_map { |letter, column| place[letter, column] }
  taps.insert(8, [0.6, -> { game.shuffle(random: Random.new(1)) }])
  taps += [[1.4, -> { game.tap_cell(cell[10]) }], [0.4, -> { game.tap_cell(cell[11]) }]]
  [game, taps + place["N", 10] + place["G", 11]]
end

def plays_of_a_game
  game, taps = a_game
  now = 0.0
  plays = []
  game.subscribe { |event| Sounds.for(event, game).each { plays << [now + it.delay, it.name, it.pitch] } }
  taps.each do |wait, tap|
    now += wait
    tap.call
  end
  abort "the game was not won" unless game.won?
  plays
end

directory = ARGV.fetch(0) { abort "usage: ruby script/preview_sounds.rb DIRECTORY" }
FileUtils.mkdir_p(directory)
rendered = Synth::SOUNDS.to_h { [it, Synth.render(it)] }
rendered.each { |name, samples| File.binwrite(File.join(directory, "#{name}.wav"), wav(samples)) }
game = Synth.mixdown(plays_of_a_game, rendered:) + ([0.0] * (Synth::SAMPLE_RATE / 2))
File.binwrite(File.join(directory, "game.wav"), wav(game))
peak = 20 * Math.log10(game.map(&:abs).max)
puts format("Wrote %d sounds and game.wav (%.1f s, peaking at %.1f dBFS) to %s",
            rendered.size, game.size.fdiv(Synth::SAMPLE_RATE), peak, directory)
