# frozen_string_literal: true

module CrossEm
  # The original game's random number generator, bit for bit: xmur3
  # hashes the seed into the four words of sfc32's state. Every operation
  # is on unsigned 32-bit integers, so each step masks its result back
  # into 32 bits, which is how JavaScript's >>> 0 behaves.
  class Sfc32
    MASK = 0xFFFF_FFFF
    RANGE = 2.0**32

    def self.rotl(value, bits) = ((value << bits) | (value >> (32 - bits))) & MASK

    def self.seeded(seed) = new(*Xmur3.new(seed).take(4))

    def initialize(a, b, c, d)
      @a, @b, @c, @d = a, b, c, d
    end

    # The next number, a Float in [0, 1).
    def call
      t = (@a + @b + @d) & MASK
      @d = (@d + 1) & MASK
      @a = @b ^ (@b >> 9)
      @b = (@c + (@c << 3)) & MASK
      @c = (Sfc32.rotl(@c, 21) + t) & MASK
      t / RANGE
    end

    # Picks every item of +items+ once, in the original's order: each
    # draw takes the item at a random place among those left.
    def shuffle(items)
      left = items.dup
      Array.new(items.size) { left.delete_at((call * left.size).floor) }
    end

    # The string hash that seeds sfc32. Each value it yields is one more
    # call of the original's hash function.
    class Xmur3
      include Enumerable

      def initialize(seed)
        @seed = seed
      end

      def each
        h = 1_779_033_703 ^ @seed.length
        @seed.each_char do |char|
          h = ((h ^ char.ord) * 3_432_918_353) & MASK
          h = Sfc32.rotl(h, 13)
        end
        loop do
          h = ((h ^ (h >> 16)) * 2_246_822_507) & MASK
          h = ((h ^ (h >> 13)) * 3_266_489_909) & MASK
          yield h ^= h >> 16
        end
      end
    end
  end
end
