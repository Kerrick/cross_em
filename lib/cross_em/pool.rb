# frozen_string_literal: true

module CrossEm
  # The twelve slots letters wait in before they go on the grid. A slot
  # holds a letter, or nil once its letter is on the grid.
  class Pool < Data.define(:slots)
    def initialize(slots:)
      super(slots: slots.dup.freeze)
    end

    def [](index) = slots[index]
    def size = slots.size

    def letter?(index) = !slots[index].nil?

    def letters = slots.compact
    def unused_count = letters.size
    def empty? = letters.empty?

    # The letter in slot +index+, and the pool without it.
    def take(index)
      letter = slots.fetch(index) or raise ArgumentError, "slot #{index} is empty"
      [letter, with_slot(index, nil)]
    end

    # The pool with +letter+ back in its first empty slot, which need not
    # be the slot it came from.
    def put(letter)
      index = slots.index(nil) or raise ArgumentError, "the pool is full"
      with_slot(index, letter)
    end

    def first_empty_index = slots.index(nil)

    # The slots reordered: +order+ lists the old index of each new slot.
    def rearrange(order) = with(slots: order.map { slots.fetch(it) })

    private

    def with_slot(index, letter)
      with(slots: slots.dup.tap { it[index] = letter })
    end
  end
end
