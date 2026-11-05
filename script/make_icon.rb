#!/usr/bin/env ruby
# frozen_string_literal: true

# Draws Cross ’em's icon from code and writes the files the icon argument
# of `lota fuse --icon icons/icon` names: icons/icon-SIZE.png (16 to 1024),
# icons/icon.ico (16 to 256, PNG entries), and on macOS icons/icon.icns
# (with iconutil). The icon is CC0-1.0 (LICENSES/ICONS.md). Run it from the
# repository's root: ruby script/make_icon.rb
#
# Design: the game's own materials (doc/design.md's palette). Five ivory
# tiles (#FBF4E3, with the darker lower edge #D3BF97 that makes a tile look
# raised) cross in a "+": a word running across and a word running down,
# sharing the middle tile, on a rounded square of ink blue (#24427F). No
# letters, so it reads at 16 px. Each pixel's coverage comes from its
# distance to each shape's edge, so every size is drawn sharp, not scaled
# down.

require "zlib"
require "fileutils"
require "tmpdir"

INK_BLUE = [0x24, 0x42, 0x7F].freeze
IVORY = [0xFB, 0xF4, 0xE3].freeze
EDGE = [0xD3, 0xBF, 0x97].freeze

# Signed distances, in units of the icon's side (0..1); negative inside.
def rounded_box(x, y, cx, cy, half, radius)
  qx = (x - cx).abs - (half - radius)
  qy = (y - cy).abs - (half - radius)
  Math.hypot([qx, 0].max, [qy, 0].max) + [[qx, qy].max, 0].min - radius
end

PITCH = 0.245     # distance between tile centres
HALF = 0.106      # half a tile's side
RAISE = 0.022     # how far a tile's lower edge shows
TILE_CENTRES = [[0, -1], [-1, 0], [0, 0], [1, 0], [0, 1]].map do |col, row|
  [0.5 + col * PITCH, 0.5 + row * PITCH - RAISE / 2]
end.freeze

# Layers, bottom to top: [colour, distance function]. Each tile is its edge
# (the same box, lower) and then its face.
LAYERS = [
  [INK_BLUE, ->(x, y) { rounded_box(x, y, 0.5, 0.5, 0.46, 0.2) }],
  *TILE_CENTRES.flat_map do |cx, cy|
    [
      [EDGE, ->(x, y) { rounded_box(x, y, cx, cy + RAISE, HALF, 0.034) }],
      [IVORY, ->(x, y) { rounded_box(x, y, cx, cy, HALF, 0.034) }]
    ]
  end
].freeze

def render(size)
  rows = Array.new(size) do |j|
    row = +"\0".b # the scanline's PNG filter type: none
    size.times do |i|
      x = (i + 0.5) / size
      y = (j + 0.5) / size
      r = g = b = a = 0.0
      LAYERS.each do |colour, distance|
        coverage = (0.5 - distance.call(x, y) * size).clamp(0.0, 1.0)
        next if coverage.zero?

        # "Over" compositing, premultiplied.
        r = colour[0] * coverage + r * (1 - coverage)
        g = colour[1] * coverage + g * (1 - coverage)
        b = colour[2] * coverage + b * (1 - coverage)
        a = coverage + a * (1 - coverage)
      end
      pixel = a.zero? ? [0, 0, 0, 0] : [r / a, g / a, b / a, a * 255].map { |c| c.round.clamp(0, 255) }
      row << pixel.pack("C4")
    end
    row
  end
  png(size, rows.join)
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
  offset = 6 + 16 * pngs.size
  entries = +"".b
  pngs.each do |size, data|
    entries << [size % 256, size % 256, 0, 0, 1, 32, data.bytesize, offset].pack("C4v2V2")
    offset += data.bytesize
  end
  header + entries + pngs.map(&:last).join
end

FileUtils.mkdir_p("icons")
pngs = [16, 24, 32, 48, 64, 128, 256, 512, 1024].to_h { |size| [size, render(size)] }
pngs.each { |size, data| File.binwrite("icons/icon-#{size}.png", data) }
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
