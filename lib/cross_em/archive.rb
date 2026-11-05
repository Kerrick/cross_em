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

    def initialize(storage)
      @storage = storage
      @records = load
    end

    def [](number) = @records[number]
    def records = @records.values
    def size = @records.size

    def save(record)
      @records[record.number] = record
      @storage.write(FILE, JSON.pretty_generate({"format" => FORMAT, "days" => @records.values.map(&:to_h)}))
      record
    end

    private

    def load
      text = @storage.read(FILE) or return {}
      JSON.parse(text).fetch("days").to_h { |hash| [hash.fetch("number"), Record.from_h(hash)] }
    end
  end
end
