# frozen_string_literal: true

module CrossEm
  module Shell
    # Draws one letter tile, the only things in the game that look like
    # objects: an ivory face over a darker lower edge, with a soft shadow,
    # and the letter in Zilla Slab. Each state has a shape of its own as
    # well as a color (doc/design.md): a problem is hatched and has a
    # folded corner, a finished letter is inverted, an unused one is faded
    # inside a dotted outline, a lifted one floats higher with a ring.
    class TilePainter
      def initialize(pen)
        @pen = pen
      end

      # +rect+ is the tile's footprint, edge included. +depth+ is the edge
      # in pixels; +lift+ raises the tile off its footprint.
      def draw(rect, letter, state: :plain, depth: nil, lift: 0, alpha: 1.0)
        palette = @pen.palette
        depth ||= [(rect.height * 0.08).round, 2].max
        radius = (rect.width * 0.14).round
        tile = rect.offset(0, -lift.round)

        shadow(rect, tile, radius, lift, alpha) unless state == :unused
        face_color, edge_color, ink = colors(state, palette)

        if state == :unused
          face = tile
          @pen.fill(face, face_color, alpha: 0.5 * alpha, radius:)
          dotted(face, radius, alpha)
        else
          @pen.fill(tile, edge_color, alpha:, radius:)
          face = Presentation::Rect.new(x: tile.x + 1, y: tile.y + 1, width: tile.width - 2, height: tile.height - depth - 1)
          @pen.fill(face, face_color, alpha:, radius: radius - 1)
        end

        hatch(face, radius, alpha) if state == :problem
        font = @pen.type.tile(face.height)
        @pen.centered(letter, font, face, ink, alpha: state == :unused ? 0.55 * alpha : alpha)
        if state == :problem
          @pen.outline(tile, palette.problem, width: @pen.stroke(2), radius:, alpha:)
          fold(tile, radius, alpha)
        end
        ring(tile, radius, alpha) if state == :selected
        face
      end

      private

      def colors(state, palette)
        case state
        when :finished then [palette.finished_face, palette.finished_edge, palette.finished_letter]
        when :unused then [palette.tile_face, palette.tile_edge, palette.ink_muted]
        else [palette.tile_face, palette.tile_edge, palette.tile_letter]
        end
      end

      # Resting, the shadow hugs the tile; lifted, it spreads and stays
      # behind on the footprint, so the tile is seen to rise.
      def shadow(rect, tile, radius, lift, alpha)
        spread = @pen.px(1) + (lift / 3.0).round
        drop = @pen.px(2) + (lift / 4.0).round
        under = Presentation::Rect.new(x: rect.x - spread + 1, y: [tile.y + drop, rect.y].max, width: rect.width + (2 * spread) - 2,
                                       height: rect.bottom + drop - [tile.y + drop, rect.y].max)
        @pen.fill(under, @pen.palette.shadow, alpha: alpha * (lift.positive? ? 0.8 : 1.0), radius: radius + spread)
      end

      # Diagonal lines across the face, kept inside its rounded corners.
      def hatch(face, radius, alpha)
        inset = (radius * 0.3).ceil
        area = face.inset(inset)
        spacing = [@pen.px(6), 4].max
        width = @pen.stroke(1.5)
        @pen.clip(area) do
          (area.x - area.height).step(area.right, spacing) do |x|
            @pen.line(@pen.palette.problem, width, x, area.bottom, x + area.height, area.y, alpha: 0.32 * alpha)
          end
        end
      end

      # The top right corner folded down, as a marked page's would be.
      def fold(tile, _radius, alpha)
        size = (tile.width * 0.26).round
        right, top = tile.right, tile.y
        @pen.polygon(@pen.palette.page, right - size, top, right + 1, top - 1, right + 1, top + size, alpha:)
        @pen.polygon(@pen.palette.problem, right - size, top, right, top + size, right - size, top + size, alpha:)
      end

      def ring(tile, radius, alpha)
        gap = @pen.px(3)
        width = @pen.stroke(2.5)
        @pen.outline(tile.outset(gap + width), @pen.palette.ink, width:, radius: radius + gap + width, alpha:)
      end

      def dotted(face, radius, alpha)
        dot = @pen.stroke(1.5)
        @pen.dashed(face, @pen.palette.ink_muted, width: dot, dash: dot, gap: dot * 2, radius:, alpha: 0.8 * alpha)
      end
    end
  end
end
