# frozen_string_literal: true

module CrossEm
  module Shell
    # The font for each role, at the screen's density: Look's sizes in
    # points, made into pixel sizes by Units. It also measures text for
    # the sheets' layout (SheetLayout's +measure+).
    class Type
      S = Presentation::Look::SIZES

      attr_reader :fonts

      def initialize(fonts, units)
        @fonts, @units = fonts, units
      end

      def px(points) = @units.px(points)

      def wordmark = fonts.slab(px(S.wordmark))
      def number = fonts.sans(px(S.number))
      def status = fonts.sans_bold(px(S.status))
      def reason = fonts.sans(px(S.reason))
      def button = fonts.sans_bold(px(S.button))
      # The results' heading, smaller when the window is short of room.
      def heading(room = nil) = fonts.slab(px(room && room < px(60) ? S.heading - 6 : S.heading))
      def subheading = fonts.sans(px(S.subheading))
      def stat = fonts.sans_bold(px(S.stat))
      def stat_label = fonts.sans(px(S.stat_label))
      def countdown = fonts.sans_bold(px(S.countdown))
      def countdown_label = fonts.sans(px(S.countdown_label))
      def sheet_title = fonts.slab(px(S.sheet_title))

      # A tile's letter, sized to the tile's face in pixels, in steps of
      # two pixels, so a tile that grows in flight uses only a few sizes.
      def tile(face) = fonts.slab([((face * 0.3).round * 2), 2].max)

      # The fonts of a sheet's text, by SheetLayout's styles.
      def style(name)
        case name
        when :heading then fonts.sans_bold(px(19))
        when :subheading then fonts.sans_bold(px(S.body - 1))
        when :body, :bullet then fonts.sans(px(S.body))
        when :small then fonts.sans(px(S.small))
        when :license then fonts.sans(px(S.license))
        when :toggle then fonts.sans_bold(px(S.body))
        end
      end

      def line_height(style) = (style(style).height * (style == :license ? 1.08 : 1.18)).round

      def wrap(style, text, width)
        _, lines = style(style).wrap(text, width)
        lines.empty? ? [""] : lines
      end
    end
  end
end
