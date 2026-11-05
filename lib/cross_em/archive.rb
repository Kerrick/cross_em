# frozen_string_literal: true

module CrossEm
  # Every day's Record, by puzzle number, kept in one JSON file through a
  # storage: anything that answers +read(name)+ with the file's text (or
  # nil when there is none) and +write(name, text)+. The game hands it
  # Lota's save folder; tests hand it a Memory.
  class Archive
    FILE = "records.json"
    FORMAT = 1

    # A storage that keeps files in a Hash, for tests and for a game that
    # cannot save.
    class Memory
      def initialize(files = {})
        @files = files
      end

      def read(name) = @files[name]
      def write(name, text) = @files[name] = text
    end

    # What a records file that cannot be read means: it is damaged.
    DAMAGED = [JSON::ParserError, KeyError, TypeError, NoMethodError, ArgumentError].freeze

    # The archive in +storage+. A records file that is damaged is kept
    # aside under another name, with +now+ in it, and a fresh one begun, so
    # the game opens and goes on saving. +warn+ hears what happened.
    def self.open(storage, now: Time.now, warn: ->(_message) {})
      new(storage)
    rescue *DAMAGED => e
      damaged = storage.read(FILE)
      aside = "records-unreadable-#{now.to_i}.json"
      storage.write(aside, damaged) if damaged
      storage.write(FILE, empty_text)
      warn.("the saved games could not be read (#{e.message}); kept them aside as #{aside}")
      new(storage)
    end

    def self.empty_text = text_of([])
    def self.text_of(records) = JSON.pretty_generate({"format" => FORMAT, "days" => records.map(&:to_h)})

    def initialize(storage)
      @storage = storage
      @records = load
    end

    def [](number) = @records[number]
    def records = @records.values
    def size = @records.size

    def save(record)
      @records[record.number] = record
      @storage.write(FILE, Archive.text_of(@records.values))
      record
    end

    private

    def load
      text = @storage.read(FILE) or return {}
      JSON.parse(text).fetch("days").to_h { |hash| [hash.fetch("number"), Record.from_h(hash)] }
    end
  end
end
