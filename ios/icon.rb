# frozen_string_literal: true

# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Cross ’em's copy of Lota's experimental ipad/icon.rb at setdef/Lota commit
# 5e68d3d (experiment/ios-kit-1), unchanged but for these notes. The iOS kit
# workflow builds the project from it with released Lota (v0.1.3) and
# Fledge v0.5.1, so it needs nothing from Lota's experiment branch.

require "zlib"

# The iOS kit's PNG files, read and written with Ruby's standard library
# alone, so the kit's workflow installs nothing to pick or make an icon.
#
# An iOS app takes one icon of 1024 pixels a side, from which Xcode makes
# the rest (Fledge's Fledge::Icon::IOS). KitIcon.size reads a PNG's width
# and height from its header, so the workflow can find that one among a
# game's icons, and KitIcon.plain writes an opaque icon of one colour with
# a disc in the middle, for a game that names none.
module KitIcon
  SIGNATURE = "\x89PNG\r\n\x1a\n".b.freeze

  # The width, height, and whether the image has an alpha channel, of the
  # PNG at +path+, or +nil+ when it is not a PNG.
  def self.size(path)
    header = File.binread(path, 33)
    return nil unless header && header.bytesize == 33 && header.start_with?(SIGNATURE) && header[12, 4] == "IHDR"

    width, height, _depth, colour = header[16, 10].unpack("NNCC")
    [width, height, [4, 6].include?(colour)]
  end

  # Writes an opaque PNG of +side+ pixels a side to +path+: +background+,
  # an Array of three bytes, with a disc of +disc+ in the middle.
  def self.plain(path, side: 1024, background: [26, 51, 153], disc: [255, 128, 0])
    centre = (side - 1) / 2.0
    radius = side * 0.3
    rows = Array.new(side) do |y|
      dy = y - centre
      row = +"\x00".b
      side.times do |x|
        dx = x - centre
        row << ((dx * dx) + (dy * dy) <= radius * radius ? disc : background).pack("C3")
      end
      row
    end
    write(path, side, side, rows.join)
  end

  # Writes +pixels+, rows of RGB bytes each after a filter byte, as an
  # 8-bit RGB PNG of +width+ by +height+.
  def self.write(path, width, height, pixels)
    File.binwrite(path, SIGNATURE + chunk("IHDR", [width, height, 8, 2, 0, 0, 0].pack("NNCCCCC")) +
      chunk("IDAT", Zlib::Deflate.deflate(pixels, Zlib::BEST_COMPRESSION)) + chunk("IEND", ""))
  end

  def self.chunk(type, data)
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end
end
