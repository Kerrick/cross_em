# frozen_string_literal: true

module CrossEm
  # One day's game: the pool, the board, the letter selected, and whether
  # the game is still being played, won or lost. Each tap changes it at
  # once and then tells every listener what changed, as an Events value,
  # which the tap also returns. A tap that changes nothing returns nil.
  class Game
    attr_reader :day, :pool, :board, :selected, :status

    def self.start(day, referee:) = new(day:, pool: Pool.new(slots: day.letters), board: Board.empty, referee:)

    def self.restore(record, referee:)
      new(day: record.day, pool: record.pool, board: record.board, status: record.status, referee:)
    end

    def initialize(day:, pool:, board:, referee:, status: :playing)
      @day = day
      @pool = pool
      @board = board
      @referee = referee
      @status = status
      @selected = nil
      @listeners = []
    end

    # Adds a listener: anything that answers +call(event)+.
    def subscribe(listener = nil, &block)
      @listeners << (listener || block or raise ArgumentError, "subscribe needs a listener or a block")
      self
    end

    def playing? = status == :playing
    def won? = status == :won
    def lost? = status == :lost
    def over? = !playing?

    # The marks of the latest check, once every letter is on the grid or
    # the game is over; nil while letters wait in the pool.
    def check
      return unless pool.empty? || over?

      @check ||= @referee.check(board)
    end

    def good_letters = board.size - (check&.count || 0)

    # Selects the letter in slot +index+, or deselects it if it was
    # selected. An empty slot does nothing.
    def tap_slot(index)
      return unless playing? && pool.letter?(index)

      if selected == index
        @selected = nil
        announce Events::Deselected.new(index:)
      else
        @selected = index
        announce Events::Selected.new(index:)
      end
    end

    # With a letter selected, places it on a target. With none, returns a
    # placed letter to the pool. Anything else does nothing.
    def tap_cell(position)
      return unless playing?

      if selected
        place(position) if board.target?(position)
      elsif board.occupied?(position)
        return_letter(position)
      end
    end

    # Places the letter in slot +index+ on the target +position+ at once,
    # as tapping the slot and then the target would, for a whole word
    # typed at a keyboard. A letter selected before is put down first.
    # Anything that is not a letter going to a target does nothing.
    def place_letter(index, position)
      return unless playing? && pool.letter?(index) && board.target?(position)

      tap_slot(selected) if selected && selected != index
      @selected = index
      place(position)
    end

    # Reorders all twelve slots at random, empty ones too. A selected
    # letter stays selected, wherever it lands.
    def shuffle(random: Random.new)
      return unless playing?

      order = (0...pool.size).to_a.shuffle(random:)
      @pool = pool.rearrange(order)
      @selected = order.index(selected) if selected
      announce Events::Shuffled.new(order:)
    end

    # Returns every placed letter, in reading order, each to the first
    # empty slot.
    def reset
      return unless playing? && !board.empty?

      returns = board.positions.map { |position| move_to_pool(position) }
      announce Events::Reset.new(returns:)
    end

    # Ends the game: a win if every letter is placed and the check is
    # clean, otherwise a loss, with the problems marked.
    def give_up
      return unless playing?

      @selected = nil
      @check = @referee.check(board)
      announce Events::Checked.new(check: @check)
      finish
    end

    def to_record = Record.new(day:, pool:, board:, status:)

    private

    def place(position)
      index = selected
      letter, @pool = pool.take(index)
      @selected = nil
      change_board board.place(position, letter)
      event = announce Events::Placed.new(letter:, index:, position:)
      return event unless pool.empty?

      announce Events::Checked.new(check:)
      check.clean? ? finish : event
    end

    def return_letter(position) = announce(move_to_pool(position))

    def move_to_pool(position)
      letter, rest = board.lift(position)
      index = pool.first_empty_index
      @pool = pool.put(letter)
      change_board rest
      Events::Returned.new(letter:, position:, index:)
    end

    def change_board(board)
      @board = board
      @check = nil
    end

    def finish
      @status = pool.empty? && check.clean? ? :won : :lost
      announce won? ? Events::Won.new(game: self) : Events::Lost.new(game: self)
    end

    def announce(event)
      @listeners.each { it.call(event) }
      event
    end
  end
end
