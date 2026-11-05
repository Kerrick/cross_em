# frozen_string_literal: true

require "test_helper"
require "cross_em/presentation"

module PresentationTest
  include CrossEmTest
  include CrossEm::Presentation

  def rect(x, y, width, height) = Rect.new(x:, y:, width:, height:)
  def units(scale = 1) = Units.new(scale:)

  # Measures text as if every character were +char+ pixels wide and
  # every line +line+ pixels tall, wrapping at spaces.
  class FakeMeasure
    def initialize(char: 8, line: 20)
      @char, @line = char, line
    end

    def line_height(_style) = @line

    def wrap(_style, text, width)
      text.split(" ").each_with_object([+""]) do |word, lines|
        candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
        if candidate.length * @char <= width || lines.last.empty? then lines[-1] = candidate
        else lines << word.dup
        end
      end
    end
  end

  # Records what Play asks of the world outside the screen.
  class FakeHost
    attr_reader :sounds, :copied, :settings, :next_days

    def initialize(dark: false, clipboard: true)
      @dark, @clipboard = dark, clipboard
      @sounds, @copied, @next_days = [], [], 0
    end

    def sound(name) = @sounds << name
    def copy(text) = @clipboard && (@copied << text)
    def settings_changed(settings) = @settings = settings
    def next_day = @next_days += 1
    def dark? = @dark
    def read(path) = "text of #{path}\n\nsecond paragraph"
  end
end
