# frozen_string_literal: true

# The rules of Cross ’em: the day's letters, the pool and the grid, how
# words are checked, how a game ends, what is saved, the statistics and
# the share text. Nothing here draws, plays a sound or reads input, so
# all of it runs, and is tested, without a window.
require "date"
require "json"
require "set"

module CrossEm
end

require_relative "cross_em/rules"
require_relative "cross_em/sfc32"
require_relative "cross_em/day"
require_relative "cross_em/position"
require_relative "cross_em/pool"
require_relative "cross_em/word"
require_relative "cross_em/board"
require_relative "cross_em/dictionary"
require_relative "cross_em/check"
require_relative "cross_em/referee"
require_relative "cross_em/events"
require_relative "cross_em/game"
require_relative "cross_em/record"
require_relative "cross_em/archive"
require_relative "cross_em/stats"
require_relative "cross_em/share_text"
require_relative "cross_em/countdown"
require_relative "cross_em/session"
