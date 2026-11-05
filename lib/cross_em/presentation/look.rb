# frozen_string_literal: true

module CrossEm
  module Presentation
    # Every presentation setting in one place, as Rules holds every rule.
    # Sizes are in points (Units turns them into pixels); durations are in
    # seconds. doc/design.md says why each is what it is.
    module Look
      # The typefaces, by role: Zilla Slab for the tiles and the wordmark,
      # Atkinson Hyperlegible for everything that is read.
      class Type < Data.define(:slab, :sans, :sans_bold); end

      TYPE = Type.new(
        slab: "assets/fonts/ZillaSlab-Bold.ttf",
        sans: "assets/fonts/AtkinsonHyperlegible-Regular.ttf",
        sans_bold: "assets/fonts/AtkinsonHyperlegible-Bold.ttf"
      )

      # Type sizes, in points.
      class Sizes < Data.define(:wordmark, :number, :status, :reason, :button, :heading, :subheading, :stat,
                                :stat_label, :countdown, :countdown_label, :sheet_title, :body, :small, :license); end

      SIZES = Sizes.new(wordmark: 27, number: 15, status: 17, reason: 15, button: 17, heading: 30, subheading: 16,
                        stat: 26, stat_label: 13, countdown: 22, countdown_label: 13, sheet_title: 26, body: 17,
                        small: 14, license: 13)

      # Spacing and furniture, in points.
      class Metrics < Data.define(:margin, :gap, :header, :touch, :tile_min, :tile_max, :tile_gap, :cell_min,
                                  :cell_max, :board_pad, :status, :controls, :controls_max, :heading, :stats,
                                  :column_min, :column_max, :sheet_max, :drag, :lift); end

      METRICS = Metrics.new(margin: 16, gap: 12, header: 56, touch: 44, tile_min: 44, tile_max: 64, tile_gap: 8,
                            cell_min: 44, cell_max: 72, board_pad: 12, status: 56, controls: 48, controls_max: 520,
                            heading: 66, stats: 58, column_min: 320, column_max: 430, sheet_max: 600, drag: 8, lift: 7)

      # How much larger the whole design is drawn on a big screen: none
      # until the window is wider and taller, in points, than this, then
      # in proportion, up to +most+ (Units.for_window).
      class Zoom < Data.define(:width, :height, :most); end

      ZOOM = Zoom.new(width: 1200, height: 820, most: 1.5)

      # How long things take, in seconds.
      class Timing < Data.define(:give_up_confirm, :copied); end

      TIMING = Timing.new(give_up_confirm: 3.0, copied: 2.5)
    end
  end
end
