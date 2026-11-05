# frozen_string_literal: true

# Lota reads this before it opens the window.
def Lota.conf(t)
  # The save folder's name. CROSS_EM_SAVE_AS gives a test run a folder of
  # its own, so it starts from nothing and leaves the player's alone.
  t.identity = ENV.fetch("CROSS_EM_SAVE_AS", "cross_em")

  # Draw in the screen's physical pixels, with no scaling by Lota: with
  # high density on and its DPI scaling off, drawing, the mouse, touches,
  # the safe area and the scissor are all in pixels, and the game sizes
  # everything itself from the screen's density (Presentation::Units), so
  # text and lines land on whole pixels and nothing is resampled.
  t.highdpi = true
  t.window.usedpiscale = false
  # Multisampling smooths the rounded corners and circles; edges that sit
  # on pixel boundaries stay sharp.
  t.window.msaa = 4

  # The window's first size, in points: CROSS_EM_WINDOW=390x844 to try a
  # phone's.
  width, height = ENV.fetch("CROSS_EM_WINDOW", "").split("x", 2).map { Integer(it, exception: false) }
  t.window.title = "Cross ’em"
  t.window.width = width || 1100
  t.window.height = height || 760
  t.window.resizable = true
  # CROSS_EM_MUTE=1 runs without sound and never opens an audio device.
  t.modules.audio = false if ENV["CROSS_EM_MUTE"] == "1"
  t.window.minwidth = 320
  t.window.minheight = 480
end
