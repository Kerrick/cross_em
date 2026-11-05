# Cross ’em: design

This is the brief the presentation was built from, and the record of why it
looks, sounds and moves the way it does. The rules are in `lib/cross_em/` and
are not up for design; everything here is. Where the build went past the
first brief, this document was changed to match it.

## The idea: ink and tiles

Cross ’em is a crossword you build yourself, so it should feel like a
pencil-and-paper puzzle page with real tiles on it. Two materials, one voice:

- **Paper and ink** for everything that is *information*: the page, the dotted
  graph-paper grid, the headings, the counts, the clock, the buttons. Flat,
  quiet, typographic.
- **Tiles** for everything that is *the letters*: chunky, slightly raised,
  ivory with a darker lower edge, set in a bold slab serif. Tiles are the only
  things that look like objects, so the player's eye knows what can be moved.

One accent per meaning, and never meaning by color alone (Westland & Maggio;
Johnson). Every state below has a shape or motion cue too.

| State | Shape/motion cue | Color cue |
| --- | --- | --- |
| Pool letter available | raised tile with its edge showing | ivory tile |
| Pool letter selected | lifted higher (bigger, spread shadow, gentle bob), thick ring, a small caret beneath | ink ring |
| Empty pool slot | a sunken dashed socket with an inner shadow, no tile | paper shade |
| Placed letter | tile flat on the grid, thin edge | ivory tile |
| Target (only while a letter is selected) | dashed rounded square with a small "+", fading in and breathing | accent (blue-teal) |
| Problem letter | diagonal hatching across the tile, an outline and a folded corner, a small shake as the check finds it | vermilion |
| Finished letter (after the game) | inverted tile: dark face, light letter | ink blue |
| Unused letter (after a loss) | faded tile with a dotted outline | muted |
| Won | heading "Solved!", tiles flip in a diagonal wave, square confetti | green heading |
| Lost | heading "Game over", tiles settle quietly, nothing celebrates | ink heading |

Appearance follows the system (`Lota::Window.system_theme`, re-read on
`themechanged`) unless the player picks Light or Dark with the header's
appearance button, which cycles System, Light, Dark (a half-filled disc, a
sun, a moon). Light is "morning paper"; dark is "night edition": deep ink-blue
page, the same ivory tiles (tiles are objects, so they keep their material),
lighter ink.

### Palette (sRGB hex; `Presentation::Palette`)

| Token | Light | Dark | Used for |
| --- | --- | --- | --- |
| page | `#F3EDE2` | `#14171D` | the page |
| page shade | `#E7DECF` | `#0E1014` | sunken sockets, the off switch |
| grid dot | `#D3C7B0` | `#353C4A` | graph-paper dots |
| rule | `#D9CFBC` | `#2A2F3A` | hairlines, disabled buttons |
| ink | `#1F1A14` | `#ECE6DA` | text, outlines, the selection ring |
| ink muted | `#6B6256` | `#9AA0AC` | secondary text |
| card | `#FAF6EE` | `#1B1F27` | sheets, plain buttons |
| scrim | ink at 42% | near-black at 62% | behind a sheet |
| shadow | brown at 16% | black at 40% | under tiles and cards |
| tile face / edge / letter | `#FBF4E3` / `#D3BF97` / `#1F1A14` | `#E9DFC8` / `#A8956F` / `#1F1A14` | tiles |
| target | `#1F7A8C` | `#5CC4D6` | targets, the wordmark's apostrophe, the on switch |
| problem | `#C8432B` | `#FF7A5C` | problem marks and reasons, the armed Give up |
| finished face / edge / letter | `#24427F` / `#172C57` / `#FBF4E3` | `#4A73C9` / `#2F4F94` / `#FBF4E3` | finished tiles |
| won | `#2E7D4F` | `#5BC08A` | "Solved!" |
| glow | white at 60% | white at 16% | the check's sweep |

Problem vermilion and target teal differ strongly in lightness as well as hue,
so they stay apart for red-green color blindness; hatching, the folded corner
and the "+" carry the meaning regardless. Confetti uses the share text's
colors: green, blue, yellow, teal and vermilion.

### Type

- **Zilla Slab Bold** for tile letters, the wordmark, the results heading and
  sheet titles. A slab serif reads as "newspaper puzzle page", and its
  capitals are wide and unambiguous.
- **Atkinson Hyperlegible** (Regular, Bold) for everything else. It was drawn
  by the Braille Institute for legibility; readability comes first here. Its
  slashed zero is kept: it cannot be mistaken for an O next to letter tiles.
- The wordmark is "Cross ’em" with the curly apostrophe in the accent color,
  followed by the puzzle's number, "No. 1720", on the same baseline.

Text is rasterised at its exact pixel size (`dpiscale: 1.0`) and printed at
whole-pixel positions. Fonts are rebuilt when the window's density changes. A
tile's letter size steps by two pixels, so a tile growing in flight uses only
a few sizes; a flipping or squashed tile uncovers its letter rather than
scaling it, so glyphs are never resampled. The clock's digits each sit in a
cell as wide as the widest digit, so it ticks without shuffling sideways.

## Pixels

The window runs with `t.highdpi = true` and `t.window.usedpiscale = false`, so
every Lota coordinate — drawing, mouse, touch, safe area, scissor — is a
physical pixel. The layout is designed in points; `Units` multiplies by
`Lota::Window.native_dpi_scale` and rounds, so every rectangle, line and text
origin lands on whole pixels, and strokes are drawn inside their rectangles
with their edges on pixel boundaries. Lines are `:rough` (hard-edged) and the
window has 4× multisampling, so edges on pixel boundaries stay sharp while
rounded corners and circles are smooth. Nothing is drawn to a fixed canvas and
resampled. Only things in motion (a tile in flight, confetti) sit between
pixels.

## Layout (`Presentation::Layout`)

Designed in points, from a phone up:

- **Portrait (phone, narrow window):** header (wordmark, puzzle number, three
  44 pt icon buttons) at the top; the board fills the middle, edge to edge;
  one status line; the pool as two rows of six; the controls row (Shuffle,
  Reset, Give up) at the bottom, in thumb reach. Everything inside the safe
  area.
- **Landscape (tablet, desktop, a phone on its side; at least 600 pt wide and
  1.1× wider than tall):** the board takes the left, larger part; a column on
  the right (38% of the width, 320–430 pt) holds the status line, the pool and
  the controls, centred top to bottom. Six tiles a row, or four if six would
  be under 44 pt.
- Pool tiles are at least 44 pt (≈ 7.8 mm on an iPhone) and grow to 64 pt;
  controls are 48 pt tall.
- **After the game** the results take the status line's and the controls'
  place: the heading and what was good, the four statistics, the clock to the
  next puzzle and "Copy result". The pool stays only while letters are left
  in it (after a loss); after a win its empty sockets give their room to the
  board.
- **The board** fits itself to its letters plus one ring of targets, with
  cells between 44 pt and 72 pt. When even 44 pt cells don't fit, the board
  pans: drag with a finger or mouse (8 pt of movement makes a press a drag
  rather than a tap), scroll with a wheel or trackpad. After every move the
  view eases to fit again (or, when panning is needed, keeps its place and
  brings the letter just placed into view). The pan stops at the content's
  edges, so every cell stays tappable and the whole board reachable
  (`Presentation::BoardView`, unit tested).

## Motion (Swink: under ~100 ms feels direct; `Presentation::Motion`)

The rules change on the tap. Animations only show what already happened:
Motion hears each event after the fact and remembers where a tile came from.

- Select: the tile lifts 7 pt in 120 ms and bobs gently while selected; its
  shadow spreads and stays on the slot. Picking another lowers the first.
- Place: the tile flies from its slot to the cell (220 ms, ease-out-back,
  with a slight arc), growing to the cell's size, and lands with a small
  squash (140 ms) and a clack.
- Return: it flies back to its new slot (200 ms).
- Reset: every letter flies home, staggered 30 ms in reading order; until its
  turn, each waits where it was.
- Shuffle: tiles arc to their new slots (260 ms) with a rattle.
- Targets fade in (150 ms) when a letter is selected, and breathe.
- Check: a soft band of light sweeps across the board, left to right
  (450 ms); each problem letter gets its marks as the sweep passes it, with a
  small shake, and the thunk sounds as the sweep ends.
- Win: after the sweep, tiles flip to the finished face in a diagonal wave
  from the top left (60 ms a step, 320 ms a flip), the rising chime starts the
  wave, and square confetti falls through the board.
- Loss: no shake beyond the problems' and no confetti; good letters fade to
  their final faces, unused letters fade to outlines, and a soft two-note
  phrase plays. The game says what was good: "7 of 12 letters crossed."
- The results fade in as the board settles.
- The board's camera eases (250 ms) whenever its fit changes, even when the
  board's room changes at the end of the game. A drag takes over at once.

A player can turn motion down in How to play ("Calm motion"): lifts, flights,
the sweep and the wave become 80 ms fades, nothing bobs or breathes, the camera
jumps, and there is no confetti.

## Sound (`Presentation::Synth`, `Presentation::Sounds`)

Synthesised in Ruby as the game starts (one sound a frame, so the first frames
don't stall), so there are no audio files and nothing to license: a wooden
"tock" to pick up (lower to put down), a clack to place (pitch rising slightly
with each letter on the grid), a lighter tick to return, a rattle to shuffle
(lower for a reset), a paper swish for the check, a muted thunk for problems,
a rising four-note chime for a win, a gentle falling two-note phrase for a
loss, a soft click for buttons, and a bright ding for "copied". The speaker
button in the header mutes; the game plays identically muted, and without an
audio device.

## Words (Podmajersky, Yifrah; `Presentation::Copy`)

The status line always says what the player can do next, in their state:

- Nothing selected, the board empty: "Tap a letter to pick it up."
- Nothing selected, letters placed: the same, and under it "9 letters left.
  Tap a placed one to send it back."
- A letter selected: "Now tap a glowing square to place it."
- All placed, problems: "3 letters need fixing. Tap one to send it back."
  (broken at the sentence when it needs two lines), followed by the reasons,
  as many as fit and then "+2 more": "AZ is too short", "TCA isn't in the word
  list", "DOG isn't connected", "Q is on its own". A word whose letters are
  problems only because a bad word crosses it is not blamed.
- Over: "Solved!" and "All 12 letters crossed.", or "Game over" and "7 of 12
  letters crossed."

Buttons name their action: "Shuffle", "Reset", "Give up" (which turns
vermilion and asks "Give up? Tap again" for three seconds before it acts),
"Copy result" (then "Copied" for a few seconds, with a ding), "Play No. 1721"
once the clock runs out. A label too long for its button wraps onto two lines
in a smaller size rather than being cut off.

## Screens

- **Play**, the only real screen.
- **How to play**, a sheet over Play: shown at first launch until dismissed,
  reopened by the "?" in the header (or the ? key). It covers every rule,
  the keyboard on a computer, the Calm motion switch, the word list's credit
  word for word, and buttons to Credits and to Play.
- **Credits**, a scrolling sheet over How to play: Cross ’em itself, Lota and
  LÖVE, the full `wordlist-COPYRIGHT.txt`, and both fonts' licenses, each
  read from the files that ship with the game. The license texts are shown
  with every word as written, their hard-wrapped paragraphs reflowed to the
  sheet's width (`Presentation::Reflow`); a line of dashes becomes a rule.
  The body fades at an edge with more beyond it, and a thin bar shows where
  it is.
- **Results** replace the controls when the game is over: the heading, the
  four statistics (played, win %, streak, best streak), the countdown to the
  next UTC midnight, "Copy result", and, once the countdown reaches zero,
  "Play No. N", which opens the new day's puzzle without restarting.

A sheet closes with its ×, a tap outside it, or Esc. On a computer the
pointer becomes a hand over anything a click would change, and a four-way
arrow over a board that pans.
