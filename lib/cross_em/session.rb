# frozen_string_literal: true

module CrossEm
  # Opens a day's game from the archive, or starts it fresh, and saves it
  # after every place, return and reset, and when it ends. A shuffle is
  # saved too, so the pool reopens exactly as it was left, but only once
  # the day has a record: shuffling alone does not make a day played.
  # Practice games and reviews of past ones are never saved.
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

    # A game of +day+ just for fun: a fresh pool and an empty board,
    # never saved, so the day's record and the statistics stay as the
    # first play left them, whatever happens in it.
    def practice(day) = Game.start(day, referee:)

    # The game +record+ saved, to look at: restored exactly, check marks
    # and all, and never saved again.
    def review(record) = Game.restore(record, referee:)

    def stats(today) = Stats.of(archive.records, today:)

    private

    def saves?(event, day)
      Events::SAVED.any? { event.is_a?(it) } || (event.is_a?(Events::Shuffled) && archive[day.number])
    end
  end
end
