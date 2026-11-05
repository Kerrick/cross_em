# frozen_string_literal: true

module CrossEm
  # Opens a day's game from the archive, or starts it fresh, and saves it
  # after every place, return and reset, and when it ends. A shuffle is
  # saved too, so the pool reopens exactly as it was left, but only once
  # the day has a record: shuffling alone does not make a day played.
  class Session
    attr_reader :archive, :referee

    def initialize(archive:, referee:)
      @archive = archive
      @referee = referee
    end

    def open(day)
      record = archive[day.number]
      game = record ? Game.restore(record, referee:) : Game.start(day, referee:)
      game.subscribe { |event| archive.save(game.to_record) if saves?(event, day) }
    end

    def stats(today) = Stats.of(archive.records, today:)

    private

    def saves?(event, day)
      Events::SAVED.any? { event.is_a?(it) } || (event.is_a?(Events::Shuffled) && archive[day.number])
    end
  end
end
