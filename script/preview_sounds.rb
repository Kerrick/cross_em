# frozen_string_literal: true

# Writes every game sound as a 16-bit mono WAV, so a human can listen:
#   ruby script/preview_sounds.rb DIRECTORY
require "fileutils"
require_relative "../lib/cross_em/presentation/synth"

Synth = CrossEm::Presentation::Synth

def wav(samples)
  data = samples.map { (it * 32_767).round }.pack("s<*")
  header = ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, Synth::SAMPLE_RATE,
            Synth::SAMPLE_RATE * 2, 2, 16, "data", data.bytesize]
  header.pack("a4Va4a4VvvVVvva4V") + data
end

directory = ARGV.fetch(0) { abort "usage: ruby script/preview_sounds.rb DIRECTORY" }
FileUtils.mkdir_p(directory)
Synth::SOUNDS.each do |name|
  File.binwrite(File.join(directory, "#{name}.wav"), wav(Synth.render(name)))
end
puts "Wrote #{Synth::SOUNDS.size} sounds to #{directory}"
