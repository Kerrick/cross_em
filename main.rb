# frozen_string_literal: true

# Cross ’em, a daily word puzzle. The rules are in lib/cross_em, how the
# game looks, sounds and answers a tap is in lib/cross_em/presentation,
# and lib/cross_em/shell carries that out with Lota. This file only hands
# Lota's callbacks to the game.
#
# Controls: tap or click a letter in the pool to pick it up, then a
# glowing square on the grid to place it; tap a placed letter to send it
# back. Drag the grid, or scroll, to see all of a big one. On a keyboard,
# type a letter to pick it up (again for the next of the same letter), Esc
# puts it down or closes a sheet, Space shuffles, ? opens How to play,
# Ctrl+C or Cmd+C copies the result once the game is over, Enter plays
# the next puzzle when it is ready, and F11 toggles fullscreen.
#
# Development settings, read from the environment:
#
#   CROSS_EM_QUIT_AFTER=20      quits after this many seconds, with status 0.
#   CROSS_EM_SHOTS=0.5,2,4      captures the screen at these seconds after
#                               start, as shot-1.png, shot-2.png, ... in the
#                               save folder, and prints each file's path.
#   CROSS_EM_SAVE_AS=test       saves in a folder of this name instead, so
#                               a run starts from nothing and never touches
#                               the player's saves.
#   CROSS_EM_TODAY=2026-11-07   plays as if that UTC date were today, at
#                               the real time of day.
#   CROSS_EM_WINDOW=390x844     opens the window at this size, in points
#                               (390x844 an iPhone, 1366x1024 an iPad on
#                               its side).
#   CROSS_EM_DENSITY=1          draws as if the screen had this many pixels
#                               to a point, to try a big screen's layout in
#                               a small window (683x512 at density 1 is an
#                               iPad on its side, at 1:1).
#   CROSS_EM_THEME=dark         starts in this appearance: light, dark or
#                               system.
#   CROSS_EM_MUTE=1             runs without sound, never opening an audio
#                               device, as on a computer without one.
#   CROSS_EM_SCRIPT=pick:K,tap:0:0,wait:1,giveup
#                               plays these steps by itself at startup; see
#                               CrossEm::Presentation::Script for them all.

require_relative "lib/cross_em/shell"

def Lota.load
  @app = CrossEm::Shell::App.new
  @app.load
end

def Lota.update(dt) = @app&.update(dt)
def Lota.draw = @app&.draw
def Lota.resize(_width, _height) = @app&.resize
def Lota.themechanged(*) = @app&.theme_changed

def Lota.mousepressed(x, y, button, istouch) = @app&.mouse(:pressed, x, y, button, istouch)
def Lota.mousereleased(x, y, button, istouch) = @app&.mouse(:released, x, y, button, istouch)
def Lota.mousemoved(x, y, _dx, _dy, istouch) = @app&.mouse_moved(x, y, istouch)
def Lota.wheelmoved(x, y) = @app&.wheel(x, y)

def Lota.touchpressed(id, x, y, _dx, _dy, _pressure, devicetype, mouse)
  @app&.touch(:pressed, id, x, y, devicetype, mouse)
end

def Lota.touchmoved(id, x, y, _dx, _dy, _pressure, devicetype, mouse)
  @app&.touch(:moved, id, x, y, devicetype, mouse)
end

def Lota.touchreleased(id, x, y, _dx, _dy, _pressure, devicetype, mouse)
  @app&.touch(:released, id, x, y, devicetype, mouse)
end

def Lota.keypressed(key) = @app&.key_pressed(key)
def Lota.textinput(text) = @app&.text_input(text)
