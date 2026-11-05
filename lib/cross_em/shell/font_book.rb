# frozen_string_literal: true

module CrossEm
  module Shell
    # The game's fonts, made once for each face and pixel size and kept.
    # Each is rasterised at exactly its size in pixels (dpiscale 1), since
    # the game draws in physical pixels, so glyphs land 1:1 on the screen.
    # A change of density makes every size new, so the book is emptied.
    class FontBook
      def initialize(type)
        @type = type
        @fonts = {}
      end

      def slab(size) = font(@type.slab, size)
      def sans(size) = font(@type.sans, size)
      def sans_bold(size) = font(@type.sans_bold, size)

      def forget = @fonts.clear

      private

      def font(path, size)
        size = [size.round, 1].max
        @fonts[[path, size]] ||= load(path, size)
      end

      def load(path, size)
        ::Lota::Graphics::Font.new(path, size, dpiscale: 1.0)
      rescue StandardError => e
        warn "Cross ’em: using Lota's own font (#{e.message})"
        ::Lota::Graphics::Font.new(size, dpiscale: 1.0)
      end
    end
  end
end
