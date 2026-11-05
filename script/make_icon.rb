#!/usr/bin/env ruby
# frozen_string_literal: true

# Draws Cross ’em's icon from code and writes the files the icon argument
# of `lota fuse --icon icons/icon` names: icons/icon-SIZE.png (16 to 1024),
# icons/icon.ico (16 to 256, PNG entries), and on macOS icons/icon.icns
# (with iconutil). The icon is CC0-1.0 (LICENSES/ICONS.md). Run it from the
# repository's root: ruby script/make_icon.rb
#
# Design: the game's own materials (doc/design.md's palette) on a rounded
# square of ink blue (#24427F). Ivory tiles (#FBF4E3, with the darker
# lower edge #D3BF97 that makes a tile look raised) carry ink letters in
# Zilla Slab Bold, the game's tile face, read from the font that ships
# with the game (assets/fonts, SIL Open Font License) and filled here, so
# nothing else is needed. From 128 px up the tiles spell a tiny crossword:
# CROSS across and REM down from its R, so it reads "Cross … em". Smaller
# icons can't show seven letters, so they show three bigger tiles meeting
# at a corner, the first one lettered C from 32 px up. Every pixel's
# coverage is worked out at its own size (shapes from their distance to
# an edge, letters from exact spans on sixteen lines a pixel), so every
# size is drawn sharp, not scaled down.

require "zlib"
require "fileutils"
require "tmpdir"

INK_BLUE = [0x24, 0x42, 0x7F].freeze
IVORY = [0xFB, 0xF4, 0xE3].freeze
EDGE = [0xD3, 0xBF, 0x97].freeze
INK = [0x1F, 0x1A, 0x14].freeze
SHADOW = [0x10, 0x1E, 0x3C].freeze

# The outlines of a TrueType font's glyphs, as closed polygons in font
# units (y up), with quadratic curves cut into short straight pieces.
class Font
  def initialize(path)
    @data = File.binread(path)
    @tables = Array.new(u16(4)) do |i|
      tag, _, offset, = @data[12 + (16 * i), 16].unpack("a4NNN")
      [tag, offset]
    end.to_h
    head = @tables.fetch("head")
    @units = u16(head + 18)
    @long_loca = u16(head + 50) == 1
  end

  attr_reader :units

  # The outline of +char+: an array of contours, each an array of [x, y].
  def outline(char) = contours(glyph_index(char.ord))

  # How far the pen moves after +char+, in font units.
  def advance(char)
    glyphs = u16(@tables.fetch("hhea") + 34)
    index = [glyph_index(char.ord), glyphs - 1].min
    u16(@tables.fetch("hmtx") + (4 * index))
  end

  private

  def u16(at) = @data[at, 2].unpack1("n")
  def s16(at) = @data[at, 2].unpack1("s>")

  # The glyph for a character, from the cmap's Windows Unicode subtable
  # (format 4).
  def glyph_index(code)
    cmap = @tables.fetch("cmap")
    sub = Array.new(u16(cmap + 2)) { cmap + 4 + (8 * it) }
              .map { [u16(it), u16(it + 2), cmap + @data[it + 4, 4].unpack1("N")] }
              .find { |platform, encoding, at| platform == 3 && encoding == 1 && u16(at) == 4 }&.last
    raise "no Unicode cmap" unless sub

    segments = u16(sub + 6) / 2
    ends, starts, deltas, ranges = [14, 16 + (2 * segments), 16 + (4 * segments), 16 + (6 * segments)].map { sub + it }
    segments.times do |i|
      next if u16(ends + (2 * i)) < code
      return 0 if u16(starts + (2 * i)) > code

      range = u16(ranges + (2 * i))
      return (code + s16(deltas + (2 * i))) % 65_536 if range.zero?

      glyph = u16(ranges + (2 * i) + range + (2 * (code - u16(starts + (2 * i)))))
      return glyph.zero? ? 0 : (glyph + s16(deltas + (2 * i))) % 65_536
    end
    0
  end

  def glyph_offset(index)
    loca = @tables.fetch("loca")
    if @long_loca
      @data[loca + (4 * index), 8].unpack("NN")
    else
      @data[loca + (2 * index), 4].unpack("nn").map { it * 2 }
    end.then { |from, to| from == to ? nil : @tables.fetch("glyf") + from }
  end

  def contours(index, dx = 0, dy = 0)
    at = glyph_offset(index) or return []
    count = s16(at)
    return composite(at + 10, dx, dy) if count.negative?

    ends = Array.new(count) { u16(at + 10 + (2 * it)) }
    points = ends.last + 1
    at += 10 + (2 * count)
    at += 2 + u16(at) # skip the hinting instructions
    flags = []
    while flags.size < points
      flag = @data.getbyte(at)
      at += 1
      repeat = 0
      if flag & 8 != 0
        repeat = @data.getbyte(at)
        at += 1
      end
      (repeat + 1).times { flags << flag }
    end
    xs, at = coordinates(flags, at, 2, 16)
    ys, = coordinates(flags, at, 4, 32)
    on = flags.map { it & 1 == 1 }
    start = 0
    ends.map do |last|
      contour = (start..last).map { [xs[it] + dx, ys[it] + dy, on[it]] }
      start = last + 1
      flatten(contour)
    end
  end

  # Composite glyphs: their parts, each moved by its offset (no scaling,
  # which the capitals here don't use).
  def composite(at, dx, dy)
    parts = []
    loop do
      flags = u16(at)
      index = u16(at + 2)
      if flags & 1 != 0
        x, y = s16(at + 4), s16(at + 6)
        at += 8
      else
        x, y = @data[at + 4, 2].unpack("cc")
        at += 6
      end
      at += 2 if flags & 8 != 0
      at += 4 if flags & 0x40 != 0
      at += 8 if flags & 0x80 != 0
      parts.concat(contours(index, dx + x, dy + y))
      break if flags & 0x20 == 0
    end
    parts
  end

  def coordinates(flags, at, short, same)
    value = 0
    values = flags.map do |flag|
      if flag & short != 0
        delta = @data.getbyte(at)
        at += 1
        value += flag & same != 0 ? delta : -delta
      elsif flag & same == 0
        value += s16(at)
        at += 2
      end
      value
    end
    [values, at]
  end

  # A contour of on- and off-curve points as a polygon: two off-curve
  # points in a row imply an on-curve point midway, and each curve is
  # cut into eight straight pieces.
  def flatten(points)
    first = points.index { it[2] }
    if first.nil?
      a, b = points[0], points[1]
      points = [[(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0, true], *points]
      first = 0
    end
    points = points.rotate(first)
    polygon = [points.first.first(2)]
    control = nil
    (points.drop(1) + [points.first]).each do |x, y, on|
      if on
        curve(polygon, control, [x, y]) if control
        polygon << [x, y] unless control
        control = nil
      elsif control
        middle = [(control[0] + x) / 2.0, (control[1] + y) / 2.0]
        curve(polygon, control, middle)
        control = [x, y]
      else
        control = [x, y]
      end
    end
    polygon
  end

  def curve(polygon, control, to)
    from = polygon.last
    1.upto(8) do |step|
      t = step / 8.0
      polygon << [((1 - t)**2 * from[0]) + (2 * (1 - t) * t * control[0]) + (t**2 * to[0]),
                  ((1 - t)**2 * from[1]) + (2 * (1 - t) * t * control[1]) + (t**2 * to[1])]
    end
  end
end

SLAB = Font.new(File.expand_path("../assets/fonts/ZillaSlab-Bold.ttf", __dir__))

# Signed distances, in units of the icon's side (0..1); negative inside.
def rounded_box(x, y, cx, cy, half, radius)
  qx = (x - cx).abs - (half - radius)
  qy = (y - cy).abs - (half - radius)
  Math.hypot([qx, 0].max, [qy, 0].max) + [[qx, qy].max, 0].min - radius
end

# A coverage mask, size by size, from a signed distance.
def shape(size, &distance)
  Array.new(size * size) do |n|
    j, i = n.divmod(size)
    (0.5 - (distance.call((i + 0.5) / size, (j + 0.5) / size) * size)).clamp(0.0, 1.0)
  end
end

SUB = 16 # lines a pixel, for letters

# The coverage of +char+ with its capitals +cap+ high (in units of the
# icon's side), centred on (+cx+, +cy+): exact across each of SUB lines a
# pixel, nonzero winding.
def letter(size, char, cx, cy, cap)
  scale = cap * size / 700.0 * 1000 / SLAB.units # Zilla Slab's capitals are 700 units high
  polygons = SLAB.outline(char)
  xs = polygons.flatten(1).map(&:first)
  left = cx * size - (((xs.min + xs.max) / 2.0) * scale)
  base = (cy * size) + (350 * 1000 / SLAB.units * scale)
  edges = polygons.flat_map do |polygon|
    polygon.each_cons(2).to_a.push([polygon.last, polygon.first]).filter_map do |(x0, y0), (x1, y1)|
      a = [left + (x0 * scale), base - (y0 * scale)]
      b = [left + (x1 * scale), base - (y1 * scale)]
      next if a[1] == b[1]

      a[1] < b[1] ? [a, b, 1] : [b, a, -1]
    end
  end
  mask = Array.new(size * size, 0.0)
  top = edges.map { it[0][1] }.min.floor.clamp(0, size)
  bottom = edges.map { it[1][1] }.max.ceil.clamp(0, size)
  (top * SUB...bottom * SUB).each do |line|
    y = (line + 0.5) / SUB
    crossings = edges.filter_map do |(ax, ay), (bx, by), wind|
      next unless ay <= y && y < by

      [ax + ((y - ay) * (bx - ax) / (by - ay)), wind]
    end.sort_by(&:first)
    winding = 0
    crossings.each_cons(2) do |(x0, w), (x1, _)|
      winding += w
      next if winding.zero?

      span(mask, size, line / SUB, x0, x1)
    end
  end
  mask
end

def span(mask, size, row, from, to)
  from, to = from.clamp(0, size), to.clamp(0, size)
  (from.floor..[to.ceil - 1, size - 1].min).each do |i|
    covered = [to, i + 1].min - [from, i].max
    mask[(row * size) + i] += covered.to_f / SUB if covered.positive?
  end
end

# A tile at (+cx+, +cy+), +half+ its side: its lower edge, its face and
# its letter, if any, as [colour, mask] layers.
def tile(size, cx, cy, half, char)
  raise_by = half * 0.2
  radius = half * 0.3
  layers = [
    [SHADOW, shape(size) { |x, y| rounded_box(x, y, cx, cy + (raise_by * 2.2), half, radius) + (0.5 / size) }, 0.35],
    [EDGE, shape(size) { |x, y| rounded_box(x, y, cx, cy + raise_by, half, radius) }],
    [IVORY, shape(size) { |x, y| rounded_box(x, y, cx, cy, half, radius) }]
  ]
  layers << [INK, letter(size, char, cx, cy, half * 1.08)] if char
  layers
end

# Where the tiles go, as [column, row, letter] on a grid, for a size.
def tiles_for(size)
  if size >= 128
    word = "CROSS".chars.each_with_index.map { |c, i| [i, 0, c] }
    [*word, [1, 1, "E"], [1, 2, "M"]]
  else
    [[0, 0, size >= 32 ? "C" : nil], [1, 0, nil], [0, 1, nil]]
  end
end

def render(size)
  layers = [[INK_BLUE, shape(size) { |x, y| rounded_box(x, y, 0.5, 0.5, 0.46, 0.2) }]]
  tiles = tiles_for(size)
  columns = tiles.map(&:first).max + 1
  rows = tiles.map { it[1] }.max + 1
  pitch = size >= 128 ? 0.164 : 0.33
  half = pitch * (size >= 128 ? 0.44 : 0.43)
  # The tiles centred on the square, by the box around them.
  ox = 0.5 - ((columns - 1) * pitch / 2.0)
  oy = 0.5 - ((rows - 1) * pitch / 2.0) - (half * 0.1)
  layers << [IVORY, dots(size, ox - (pitch / 2), oy - (pitch / 2), pitch), 0.3] if size >= 128
  tiles.each do |column, row, char|
    layers.concat(tile(size, ox + (column * pitch), oy + (row * pitch), half, char))
  end
  png(size, composite(size, layers))
end

# The game's graph paper: a dot at every cell's corner, on a grid through
# (+x+, +y+) +pitch+ apart, well inside the rounded square.
def dots(size, x, y, pitch)
  mask = Array.new(size * size, 0.0)
  radius = 0.0075
  x -= pitch while x > 0.12
  y -= pitch while y > 0.12
  centres = []
  (x..0.95).step(pitch) { |cx| (y..0.95).step(pitch) { |cy| centres << [cx, cy] } }
  centres.select { |cx, cy| rounded_box(cx, cy, 0.5, 0.5, 0.46, 0.2) < -0.05 }.each do |cx, cy|
    ((cy - (2 * radius)) * size).floor.upto(((cy + (2 * radius)) * size).ceil) do |j|
      ((cx - (2 * radius)) * size).floor.upto(((cx + (2 * radius)) * size).ceil) do |i|
        distance = Math.hypot(((i + 0.5) / size) - cx, ((j + 0.5) / size) - cy) - radius
        mask[(j * size) + i] = [mask[(j * size) + i], (0.5 - (distance * size)).clamp(0.0, 1.0)].max
      end
    end
  end
  mask
end

# "Over" compositing, premultiplied, layer by layer.
def composite(size, layers)
  Array.new(size) do |j|
    row = +"\0".b # the scanline's PNG filter type: none
    size.times do |i|
      n = (j * size) + i
      r = g = b = a = 0.0
      layers.each do |colour, mask, opacity|
        coverage = mask[n].clamp(0.0, 1.0) * (opacity || 1.0)
        next if coverage.zero?

        r = (colour[0] * coverage) + (r * (1 - coverage))
        g = (colour[1] * coverage) + (g * (1 - coverage))
        b = (colour[2] * coverage) + (b * (1 - coverage))
        a = coverage + (a * (1 - coverage))
      end
      pixel = a.zero? ? [0, 0, 0, 0] : [r / a, g / a, b / a, a * 255].map { |c| c.round.clamp(0, 255) }
      row << pixel.pack("C4")
    end
    row
  end.join
end

def chunk(type, data) = [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")

def png(size, raw)
  "\x89PNG\r\n\x1A\n".b +
    chunk("IHDR", [size, size, 8, 6, 0, 0, 0].pack("NNC5")) +
    chunk("IDAT", Zlib::Deflate.deflate(raw, Zlib::BEST_COMPRESSION)) +
    chunk("IEND", "")
end

# An ICO whose entries are PNGs, which Windows Vista and later read.
def ico(pngs)
  header = [0, 1, pngs.size].pack("v3")
  offset = 6 + (16 * pngs.size)
  entries = +"".b
  pngs.each do |size, data|
    entries << [size % 256, size % 256, 0, 0, 1, 32, data.bytesize, offset].pack("C4v2V2")
    offset += data.bytesize
  end
  header + entries + pngs.map(&:last).join
end

if $PROGRAM_NAME == __FILE__
  FileUtils.mkdir_p("icons")
  sizes = ARGV.empty? ? [16, 24, 32, 48, 64, 128, 256, 512, 1024] : ARGV.map(&:to_i)
  pngs = sizes.to_h { |size| [size, render(size)] }
  pngs.each { |size, data| File.binwrite("icons/icon-#{size}.png", data) }
  exit unless ARGV.empty?

  File.binwrite("icons/icon.ico", ico(pngs.slice(16, 24, 32, 48, 64, 128, 256)))
  if system("which iconutil > /dev/null 2>&1")
    Dir.mktmpdir do |dir|
      set = File.join(dir, "icon.iconset")
      FileUtils.mkdir_p(set)
      { 16 => [16, 32], 32 => [32, 64], 128 => [128, 256], 256 => [256, 512], 512 => [512, 1024] }.each do |point, (one, two)|
        File.binwrite(File.join(set, "icon_#{point}x#{point}.png"), pngs.fetch(one))
        File.binwrite(File.join(set, "icon_#{point}x#{point}@2x.png"), pngs.fetch(two))
      end
      system("iconutil", "-c", "icns", set, "-o", "icons/icon.icns", exception: true)
    end
  else
    warn "iconutil not found (it comes with macOS); icons/icon.icns not rewritten"
  end
  puts Dir["icons/*"].sort
end
