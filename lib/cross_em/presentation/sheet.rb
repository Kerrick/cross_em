# frozen_string_literal: true

module CrossEm
  module Presentation
    # One piece of a sheet's content, top to bottom: a heading, a
    # paragraph, a bullet, small print, a license file shown line for
    # line, some space, a setting to switch, a row of buttons, or a
    # small example board: +tiles+ as [letter, column, row] and a
    # +target+ as [column, row].
    class Block < Data.define(:kind, :text, :id, :detail, :buttons, :tiles, :target)
      def initialize(kind:, text: nil, id: nil, detail: nil, buttons: nil, tiles: nil, target: nil) = super

      def self.heading(text) = new(kind: :heading, text:)
      def self.subheading(text) = new(kind: :subheading, text:)
      def self.body(text) = new(kind: :body, text:)
      def self.bullet(text) = new(kind: :bullet, text:)
      def self.small(text) = new(kind: :small, text:)
      def self.license(text) = new(kind: :license, text: text.to_s)
      def self.space = new(kind: :space)
      def self.toggle(id, text, detail) = new(kind: :toggle, id:, text:, detail:)
      def self.buttons(buttons) = new(kind: :buttons, buttons:)
      def self.example(tiles, target) = new(kind: :example, tiles:, target:)
    end

    # A sheet over the Play screen: How to play, Credits or Past
    # puzzles, how far its body is scrolled, in pixels, and, in Past
    # puzzles, the day the keyboard is on (+focus+, a puzzle number).
    class Sheet < Data.define(:kind, :scroll, :focus)
      TITLES = {help: "How to play", credits: "Credits", archive: "Past puzzles"}.freeze

      def self.open(kind) = new(kind:, scroll: 0, focus: nil)

      def title = TITLES.fetch(kind)

      def scrolled(by, layout) = with(scroll: (scroll + by).clamp(0, layout.most_scroll))
    end

    # Where a sheet's parts go: the card, its title and close button, and
    # the body that scrolls, as lines of text and controls placed from the
    # body's top. Text is wrapped by +measure+, which answers
    # +wrap(style, text, width)+ with the lines and +line_height(style)+
    # in pixels; the shell measures with the real fonts, tests with a
    # stand-in.
    class SheetLayout < Data.define(:card, :title, :close, :link, :body, :lines, :controls, :examples, :content_height)
      # A line of text at (+x+, +y+), +y+ from the body's top.
      class Line < Data.define(:style, :text, :x, :y); end

      # Something to tap, its +rect+'s y from the body's top.
      class Control < Data.define(:id, :kind, :rect, :text, :detail, :primary); end

      # A small board drawn in the sheet: a patch of graph paper, +rect+'s
      # y from the body's top, with cells +cell+ pixels square, the
      # +tiles+ ([letter, column, row]) and a +target+ ([column, row]).
      class Example < Data.define(:rect, :cell, :tiles, :target)
        # Where the cell at (+column+, +row+) is, inside +rect+ moved to
        # +origin+.
        def cell_rect(column, row, origin)
          columns = (tiles.map { it[1] } + [target[0]]).max + 1
          rows = (tiles.map { it[2] } + [target[1]]).max + 1
          left = origin.x + ((rect.width - (columns * cell)) / 2)
          top = origin.y + ((rect.height - (rows * cell)) / 2)
          Rect.new(x: left + (column * cell), y: top + (row * cell), width: cell, height: cell)
        end
      end

      M = Look::METRICS

      # +link+, if given as [id, text] (or [id, text, width in points]),
      # is a button in the title bar, beside the close button, always in
      # reach however far the body has scrolled.
      def self.build(blocks:, safe:, units:, measure:, link: nil)
        Builder.new(safe:, units:, measure:).build(blocks, link)
      end

      def most_scroll = [content_height - body.height, 0].max
      def scrolls? = most_scroll.positive?

      # The control under (+px+, +py+) with the body scrolled by +scroll+.
      def control_at(px, py, scroll)
        return unless body.contains?(px, py)

        controls.find { it.rect.offset(body.x, body.y - scroll).contains?(px, py) }
      end

      # Lays a sheet out, block by block.
      class Builder
        def initialize(safe:, units:, measure:)
          @safe, @u, @measure = safe, units, measure
          @lines, @controls, @examples = [], [], []
          @y = 0
        end

        def build(blocks, link = nil)
          margin = px(M.margin)
          width = [@safe.width - (2 * margin), px(M.sheet_max)].min
          @pad = px(width < px(420) ? 20 : 28)
          @width = width - (2 * @pad)
          blocks.each_with_index { |block, i| place(block, i.zero?) }
          content = @y + @pad

          title_height = px(64)
          room = @safe.height - (2 * margin)
          height = [title_height + content, room].min
          card = Rect.new(x: @safe.x + ((@safe.width - width) / 2), y: @safe.y + ((@safe.height - height) / 2),
                          width:, height:)
          title = Rect.new(x: card.x + @pad, y: card.y, width: card.width - (2 * @pad), height: title_height)
          close = Rect.new(x: card.right - px(8) - px(M.touch), y: card.y + ((title_height - px(M.touch)) / 2),
                           width: px(M.touch), height: px(M.touch))
          body = Rect.new(x: card.x + @pad, y: title.bottom, width: @width, height: card.bottom - title.bottom)
          link &&= title_link(link, close)
          SheetLayout.new(card:, title:, close:, link:, body:, lines: @lines.freeze, controls: @controls.freeze,
                          examples: @examples.freeze, content_height: content)
        end

        private

        def px(points) = @u.px(points)

        def title_link((id, text, points), close)
          width = px(points || 88)
          rect = Rect.new(x: close.x - px(4) - width, y: close.y, width:, height: close.height)
          Control.new(id:, kind: :button, rect:, text:, detail: nil, primary: false)
        end

        def place(block, first)
          case block.kind
          when :heading then text(:heading, block.text, before: first ? 0 : px(22), after: px(6))
          when :subheading then text(:subheading, block.text, before: px(14), after: px(4))
          when :body then text(:body, block.text, after: px(10))
          when :small then text(:small, block.text, after: px(8))
          when :bullet then bullet(block.text)
          when :license then license(block.text)
          when :space then @y += px(10)
          when :toggle then toggle(block)
          when :buttons then buttons(block.buttons)
          when :example then example(block)
          end
        end

        def text(style, text, before: 0, after: 0, indent: 0)
          @y += before
          height = @measure.line_height(style)
          @measure.wrap(style, text, @width - indent).each do |line|
            @lines << Line.new(style:, text: line, x: indent, y: @y)
            @y += height
          end
          @y += after
        end

        def bullet(text)
          indent = px(20)
          @lines << Line.new(style: :bullet, text: "•", x: px(4), y: @y)
          text(:body, text, indent:, after: px(8))
        end

        # A license file, every word of it, with its paragraphs reflowed to
        # the sheet's width (Reflow), its indents and quotes kept, and its
        # lines of dashes drawn as rules.
        def license(text)
          @y += px(6)
          height = @measure.line_height(:license)
          Reflow.parse(text).each do |piece|
            case piece
            when Reflow::Gap then @y += (height * 0.6).round
            when Reflow::Rule
              @lines << Line.new(style: :rule, text: "", x: 0, y: @y + (height / 2))
              @y += height
            when Reflow::Text then license_text(piece, height)
            end
          end
          @y += px(6)
        end

        def license_text(piece, height)
          indent = [piece.indent, 8].min * px(4)
          quoted = piece.quote.empty? ? 0 : px(12)
          @measure.wrap(:license, piece.text, @width - indent - quoted).each do |part|
            @lines << Line.new(style: :quote, text: "", x: indent, y: @y) if quoted.positive?
            @lines << Line.new(style: :license, text: part, x: indent + quoted, y: @y)
            @y += height
          end
        end

        def toggle(block)
          detail = @measure.wrap(:small, block.detail, @width - px(64)).size
          height = [px(M.touch) + px(12), @measure.line_height(:body) + (detail * @measure.line_height(:small)) + px(16)].max
          rect = Rect.new(x: 0, y: @y, width: @width, height:)
          @controls << Control.new(id: block.id, kind: :toggle, rect:, text: block.text, detail: block.detail,
                                   primary: false)
          @y += height
        end

        # A patch of graph paper the body's width, as tall as the example's
        # rows of cells and a margin.
        def example(block)
          cell = px(40)
          rows = (block.tiles.map { it[2] } + [block.target[1]]).max + 1
          @y += px(4)
          rect = Rect.new(x: 0, y: @y, width: @width, height: (rows * cell) + (2 * px(14)))
          @examples << Example.new(rect:, cell:, tiles: block.tiles, target: block.target)
          @y = rect.bottom + px(10)
        end

        def buttons(buttons)
          height = px(48)
          row_width = [@width, px(400)].min
          row = Rect.new(x: @width - row_width, y: @y + px(4), width: row_width, height:)
          row.columns(buttons.size, px(M.tile_gap)).zip(buttons) do |rect, (id, text, primary)|
            @controls << Control.new(id:, kind: :button, rect:, text:, detail: nil, primary:)
          end
          @y += height + px(4)
        end
      end
    end
  end
end
