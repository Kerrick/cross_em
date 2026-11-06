# frozen_string_literal: true

module CrossEm
  module Shell
    # Draws one letter tile, the only things in the game that look like
    # objects: an ivory face over a darker lower edge, with a soft shadow,
    # and the letter in Zilla Slab. Each state has a shape of its own as
    # well as a color (doc/design.md): a problem is hatched and has a
    # folded corner, a finished letter is inverted, an unused one is faded
    # inside a dotted outline, a lifted one floats higher with a ring.
    #
    # A tile in motion can be squashed as it lands (shorter from the top)
    # or flipped (shorter about its middle). Its letter keeps the size of
    # the whole tile and is only uncovered by the face, never scaled, so
    # its glyphs stay 1:1 with the screen's pixels.
    class TilePainter
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
      end

      # A dashed square with a small plus: a place the letter can go.
      def target(rect, alpha = 1.0)
        palette = @pen.palette
        width = @pen.stroke(2)
        radius = (rect.width * 0.14).round
        @pen.fill(rect, palette.target, alpha: 0.1 * alpha, radius:)
        @pen.dashed(rect, palette.target, width:, dash: @pen.px(6), gap: @pen.px(4), radius:, alpha:)
        arm = (rect.width * 0.14).round
        thick = @pen.stroke(2.5)
        cx = rect.x + ((rect.width - thick) / 2)
        cy = rect.y + ((rect.height - thick) / 2)
        @pen.color(palette.target, alpha)
        G.rectangle(:fill, cx - arm + (thick / 2), cy, 2 * arm, thick)
        G.rectangle(:fill, cx, cy - arm + (thick / 2), thick, 2 * arm)
      end

      # A ghost of a tile: a faint face inside a dashed outline in
      # +color+, with its letter in ink. A letter typed but not yet
      # placed, or one a typed word would place. A +short+ one, a letter
      # that can't be had, carries a problem's marks: hatching, the
      # problem color's outline and a folded corner.
      def ghost(rect, letter, color: nil, alpha: 1.0, short: false)
        palette = @pen.palette
        radius = (rect.width * 0.14).round
        @pen.fill(rect, palette.tile_face, alpha: (short ? 0.3 : 0.16) * alpha, radius:)
        hatch(rect, radius, alpha) if short
        @pen.dashed(rect, short ? palette.problem : (color || palette.ink_muted), width: @pen.stroke(short ? 2 : 1.5),
                                                                                 dash: @pen.px(5), gap: @pen.px(3), radius:, alpha:)
        @pen.centered(letter, @pen.type.tile(rect.height - 2), rect, palette.ink, alpha:)
        fold(rect, alpha) if short
      end

      # A sunken dashed socket where a tile can sit and none does.
      def socket(rect, alpha: 1.0)
        palette = @pen.palette
        radius = (rect.width * 0.14).round
        @pen.fill(rect, palette.page_shade, radius:, alpha:)
        @pen.fill(rect.with(height: @pen.px(3)).inset(radius, 0), palette.shadow, alpha: 0.5 * alpha)
        @pen.dashed(rect, palette.ink_muted, width: @pen.stroke(1), dash: @pen.px(4), gap: @pen.px(3), radius:,
                                             alpha: 0.45 * alpha)
      end

      # +rect+ is the tile's footprint, edge included. +depth+ is the edge
      # in pixels; +lift+ raises the tile off its footprint.
      def draw(rect, letter, state: :plain, depth: nil, lift: 0, alpha: 1.0, squash: 1.0, flip: 1.0)
        return if alpha <= 0.0

        palette = @pen.palette
        depth ||= [(rect.height * 0.08).round, 2].max
        radius = (rect.width * 0.14).round
        font = @pen.type.tile(rect.height - depth - 1)
        tile = shape(rect.offset(0, -lift.round), squash, flip)
        return if tile.height < 2

        shadow(flip < 1.0 ? tile : rect, tile, radius, lift, alpha) unless state == :unused
        face_color, edge_color, ink = colors(state, palette)

        if state == :unused
          face = tile
          @pen.fill(face, face_color, alpha:, radius:)
          dotted(face, radius, alpha)
        else
          @pen.fill(tile, edge_color, alpha:, radius:)
          face_depth = (depth * [flip, 1.0].min).round
          face = Presentation::Rect.new(x: tile.x + 1, y: tile.y + 1, width: tile.width - 2, height: tile.height - face_depth - 1)
          @pen.fill(face, face_color, alpha:, radius: radius - 1)
        end

        hatch(face, radius, alpha) if state == :problem
        letter(letter, font, face, ink, alpha * (state == :unused ? 0.55 : 1.0))
        if state == :problem
          @pen.outline(tile, palette.problem, width: @pen.stroke(2), radius:, alpha:)
          fold(tile, alpha)
        end
        ring(tile, radius, alpha) if state == :selected
        face
      end

      private

      # The footprint squashed from the top (landing) or about its middle
      # (flipping).
      def shape(rect, squash, flip)
        return rect if squash >= 1.0 && flip >= 1.0

        if flip < 1.0
          height = (rect.height * flip).round
          return rect.with(y: rect.y + ((rect.height - height) / 2), height:)
        end
        height = (rect.height * squash).round
        widen = ((rect.width * (1.0 - squash) * 0.5) / 2).round
        Presentation::Rect.new(x: rect.x - widen, y: rect.bottom - height, width: rect.width + (2 * widen), height:)
      end

      def letter(letter, font, face, ink, alpha)
        if face.height >= font.height
          @pen.centered(letter, font, face, ink, alpha:)
        else
          @pen.clip(face) { @pen.centered(letter, font, face, ink, alpha:) }
        end
      end

      def colors(state, palette)
        case state
        when :finished then [palette.finished_face, palette.finished_edge, palette.finished_letter]
        when :unused then [palette.unused_face, palette.tile_edge, palette.ink_muted]
        else [palette.tile_face, palette.tile_edge, palette.tile_letter]
        end
      end

      # Resting, the shadow hugs the tile; lifted, it spreads and stays
      # behind on the footprint, so the tile is seen to rise.
      def shadow(rect, tile, radius, lift, alpha)
        spread = @pen.px(1) + (lift / 3.0).round
        drop = @pen.px(2) + (lift / 4.0).round
        top = [tile.y + drop, rect.y].max
        under = Presentation::Rect.new(x: rect.x - spread + 1, y: top, width: rect.width + (2 * spread) - 2,
                                       height: [tile.bottom, rect.bottom].max + drop - top)
        @pen.fill(under, @pen.palette.shadow, alpha: alpha * (lift.positive? ? 0.8 : 1.0), radius: radius + spread)
      end

      # Diagonal lines across the face, kept inside its rounded corners.
      def hatch(face, radius, alpha)
        area = face.inset((radius * 0.3).ceil)
        return if area.empty?

        spacing = [@pen.px(6), 4].max
        width = @pen.stroke(1.5)
        @pen.clip(area) do
          (area.x - area.height).step(area.right, spacing) do |x|
            @pen.line(@pen.palette.problem, width, x, area.bottom, x + area.height, area.y, alpha: 0.32 * alpha)
          end
        end
      end

      # The top right corner folded down, as a marked page's would be.
      def fold(tile, alpha)
        size = [(tile.width * 0.26).round, tile.height / 2].min
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
