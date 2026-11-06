# frozen_string_literal: true

# Cross ’em, a daily word puzzle. The rules are in lib/cross_em, how the
# game looks, sounds and answers a tap is in lib/cross_em/presentation,
# and lib/cross_em/shell carries that out with Lota. This file only hands
# Lota's callbacks to the game.
#
# Controls: tap or click a letter in the pool to pick it up, then a
# glowing square on the grid to place it; tap a placed letter to send it
# back. Drag the grid, or scroll, to see all of a big one. The calendar in
# the header opens Past puzzles: any day can be played again for fun, as
# practice that is never saved, and a finished day shows its board.
#
# On a keyboard (every button shows its keys beside its label; the
# header's in a tooltip):
#
#   A-Z               type a word
#   Enter, Space      place it where it fits; with nothing typed, Enter
#                     goes on from the results (the next puzzle when it
#                     is ready, or back to today)
#   Tab, arrows       when it fits several places, show the next (Shift+Tab,
#                     Up and Left the one before); with nothing typed,
#                     the arrows move a focus ring by direction and Tab
#                     jumps between the header, the board, the pool and
#                     the buttons (Shift+Tab back)
#   Enter, Space      once the ring shows, with nothing typed: what a
#                     click on the ringed thing would do
#   1-9               place it in that numbered place
#   Backspace         the last letter typed; with nothing typed, takes
#                     back the last word placed (then the one before)
#   Esc               back from choosing a place, clears what is typed,
#                     puts down a letter picked up, or closes a sheet
#   Space             with nothing typed, Shuffle
#   Shift+Backspace   Reset (Ctrl/Cmd+Backspace too)
#   Shift+Esc         Give up, pressed twice
#   Shift+Enter       Play again, once the game is over
#   Ctrl/Cmd+T        back to today from practice or a look back
#   Ctrl/Cmd+P        Past puzzles
#   ?, F1             How to play; in it, C opens the Credits
#   Ctrl/Cmd+D        the page's appearance, light or dark
#   Ctrl/Cmd+S        sound on or off
#   Ctrl/Cmd+C        copies the result once the game is over
#   F11               fullscreen
#
# In Past puzzles, Up and Down walk the days, Page Up, Page Down, Home and
# End go further, and Enter opens the day. In the other sheets the arrows
# reach their buttons, scrolling to them.
#
# On a game controller (any SDL knows as a gamepad; plug it in any time):
#
#   D-pad             moves the focus ring by direction
#   Left stick        a cursor that settles on the nearest thing
#   A                 what a tap on the ringed thing would do
#   B                 back: puts a letter down, closes a sheet
#   X                 Shuffle (Play again once the game is over)
#   Y                 Give up, pressed twice (Copy result once it's over)
#   Back (View)       Reset
#   Start (Menu)      How to play
#   LB, RB            the region before or after; a page in a sheet
#   Right stick       pans the board, or scrolls a sheet
#
# The ring shows once the arrows or a controller are used, and hides at
# a tap or a click; buttons show a controller's glyphs while it is the
# last thing used.
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
#   CROSS_EM_TODAY=2026-11-07   plays as if that puzzle day were today, at
#                               the real time of day; with a time, as in
#                               2026-11-07T23:59:50Z, from that moment on.
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
#                               CrossEm::Presentation::Script for them all,
#                               a controller's too (pad:a, stick:0.8:0:0.5).

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

def Lota.joystickadded(joystick) = @app&.joystick_added(joystick)
def Lota.joystickremoved(joystick) = @app&.joystick_removed(joystick)
def Lota.gamepadpressed(joystick, button) = @app&.gamepad_pressed(joystick, button)
def Lota.gamepadaxis(joystick, axis, value) = @app&.gamepad_axis(joystick, axis, value)
