# frozen_string_literal: true

module CrossEm
  # Whole seconds left until a moment, never fewer than none, shown as
  # HH:MM:SS. A part of a second left still shows as a second, so the
  # clock reads 00:00:00 only once the moment has come.
  class Countdown < Data.define(:seconds)
    def self.between(now, moment) = new(seconds: [(moment - now).ceil, 0].max)

    def done? = seconds.zero?

    def to_s
      minutes, second = seconds.divmod(60)
      hours, minute = minutes.divmod(60)
      format("%02d:%02d:%02d", hours, minute, second)
    end
  end
end
