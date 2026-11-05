# frozen_string_literal: true

# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

# CI only: the iOS kit workflow's touch job (.github/workflows/ios-kit.yml)
# loads this from main.rb in its own copy of the Xcode project, never the
# kit's, so a touch test shows where each tap landed. With
# CROSS_EM_TOUCH_PROBE=1 it prints what Lota reports about the screen,
# and each touch as a fraction of Lota::Graphics.pixel_dimensions, in the
# shape of Lota's winkit probe (WINKIT_DPI_PROBE). simulator.rb keeps the
# lines that hold "probe:". The game itself never loads this file.
if ENV["CROSS_EM_TOUCH_PROBE"] == "1"
  module CrossEm
    # Prints Lota's view of the screen, and each touch, then hands the
    # callback to the game.
    module TouchProbe
      def self.screen(event)
        width, height = ::Lota::Graphics.pixel_dimensions
        puts "probe: #{event}: usedpiscale=false Window.dpi_scale=#{::Lota::Window.dpi_scale} " \
             "Window.native_dpi_scale=#{::Lota::Window.native_dpi_scale} " \
             "Graphics.dimensions=#{::Lota::Graphics.dimensions.inspect} " \
             "Graphics.pixel_dimensions=#{[width, height].inspect} Window.safe_area=#{::Lota::Window.safe_area.inspect}"
      rescue StandardError => e
        puts "probe: #{event}: #{e.class}: #{e.message}"
      end

      def self.touch(x, y)
        width, height = ::Lota::Graphics.pixel_dimensions
        puts format("probe: touch at %.1f, %.1f is %.2f, %.2f of pixel_dimensions %dx%d",
          x, y, x / width.to_f, y / height.to_f, width, height)
      rescue StandardError => e
        puts "probe: touch: #{e.class}: #{e.message}"
      end
    end
  end

  class << Lota
    alias_method :cross_em_probe_load, :load
    alias_method :cross_em_probe_resize, :resize
    alias_method :cross_em_probe_touchpressed, :touchpressed

    # Lota passes a callback as many arguments as it takes, so these hand
    # the game's own load and resize only theirs.
    def load(*args)
      cross_em_probe_load(*args.first(method(:cross_em_probe_load).arity.abs))
        .tap { CrossEm::TouchProbe.screen("load") }
    end

    def resize(*args)
      cross_em_probe_resize(*args.first(method(:cross_em_probe_resize).arity.abs))
        .tap { CrossEm::TouchProbe.screen("resize") }
    end

    def touchpressed(id, x, y, *rest)
      CrossEm::TouchProbe.touch(x, y)
      cross_em_probe_touchpressed(id, x, y, *rest)
    end
  end
end
