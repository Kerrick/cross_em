# Cross ’em: design

This is the brief the presentation was built from, and the record of why it
looks, sounds and moves the way it does. The rules are in `lib/cross_em/` and
are not up for design; everything here is.

## The idea: ink and tiles

Cross ’em is a crossword you build yourself, so it should feel like a
pencil-and-paper puzzle page with real tiles on it. Two materials, one voice:

- **Paper and ink** for everything that is *information*: the page, the dotted
  graph-paper grid, the headings, the counts, the clock. Flat, quiet,
  typographic.
- **Tiles** for everything that is *the letters*: chunky, slightly raised,
  ivory with a darker lower edge, set in a bold slab serif. Tiles are the only
  things that look like objects, so the player's eye knows what can be moved.

One accent per meaning, and never meaning by color alone (Westland & Maggio;
Johnson). Every state below has a shape or motion cue too.

| State | Shape/motion cue | Color cue |
| --- | --- | --- |
| Pool letter available | raised tile with its edge showing | ivory tile |
| Pool letter selected | lifted higher (bigger shadow, gentle bob), thick ring, a small caret beneath | ink ring |
| Empty pool slot | a sunken dashed socket, no tile | paper shade |
| Placed letter | tile flat on the grid, thin edge | ivory tile |
| Target (only while a letter is selected) | dashed rounded square with a small "+" that breathes | accent (blue-teal) |
| Problem letter | diagonal hatching across the tile and a folded corner | vermilion |
| Finished letter (after the game) | inverted tile: dark face, light letter | ink blue |
| Unused letter (after a loss) | faded tile with a dotted outline | muted |
| Won | heading "Solved", tiles flip in a diagonal wave, square confetti | blue/green |
| Lost | heading "Game over", tiles settle, nothing celebrates | calm, muted |

Appearance follows the system (`Lota::Window.system_theme`, re-read on
`themechanged`) unless the player picks Light or Dark from the header. Light is
"morning paper"; dark is "night edition": deep ink-blue page, the same ivory
tiles (tiles are objects, so they keep their material), lighter ink.

### Palette (sRGB hex; the shell converts to 0..1)

| Token | Light | Dark |
| --- | --- | --- |
| page | `#F3EDE2` | `#14171D` |
| grid dot | `#D9CFBC` | `#2A2F3A` |
| ink | `#1F1A14` | `#ECE6DA` |
| ink muted | `#6B6256` | `#9AA0AC` |
| tile face | `#FBF4E3` | `#E9DFC8` |
| tile edge | `#D3BF97` | `#A8956F` |
| tile letter | `#1F1A14` | `#1F1A14` |
| target | `#1F7A8C` | `#5CC4D6` |
| problem | `#C8432B` | `#FF7A5C` |
| finished face | `#24427F` | `#4A73C9` |
| finished letter | `#FBF4E3` | `#FBF4E3` |
| won accent | `#2E7D4F` | `#5BC08A` |

Problem vermilion and target teal differ strongly in lightness as well as hue,
so they stay apart for red-green color blindness; hatching and the "+" carry
the meaning regardless.

### Type

- **Zilla Slab Bold** for tile letters and the wordmark. A slab serif reads as
  "newspaper puzzle page", and its capitals are wide and unambiguous.
- **Atkinson Hyperlegible** (Regular, Bold) for everything else. It was drawn
  by the Braille Institute for legibility; readability comes first here.
- The wordmark is "Cross ’em" with the curly apostrophe in the accent color.

Text is rasterised at its exact pixel size (`dpiscale: 1.0`) and printed at
whole-pixel positions. Fonts are rebuilt when the window's density changes.

## Pixels

The window runs with `t.highdpi = true` and `t.window.usedpiscale = false`, so
every Lota coordinate — drawing, mouse, touch, safe area, scissor — is a
physical pixel. The layout is designed in points; `Units` multiplies by
`Lota::Window.native_dpi_scale` and rounds, so every rectangle, line and text
origin lands on whole pixels, odd-width strokes on pixel centres. Nothing is
drawn to a fixed canvas and resampled.

## Layout

Designed in points, from a phone up:

- **Portrait (phone, narrow window):** header (wordmark, puzzle number, icon
  buttons) at the top; the board fills the middle; one status line; the pool as
  two rows of six; the controls row at the bottom, in thumb reach. Everything
  inside the safe area.
- **Landscape (tablet, desktop):** the board takes the left, larger part; a
  side column on the right holds the status line, the pool (two rows of six,
  or three of four if narrow), and the controls.
- Pool tiles are at least 44 pt (≈ 7.8 mm on an iPhone) and grow to 64 pt;
  controls are at least 44 pt tall.
- **The board** fits itself to its letters plus one ring of targets, with cells
  between 44 pt and 72 pt. When even 44 pt cells don't fit, the board pans: drag
  with a finger or mouse, scroll with a wheel or trackpad. After every move the
  view eases to fit again (or, when panning is needed, to keep the last placed
  letter in view). Every cell stays tappable, and the whole board is reachable.

## Motion (Swink: under ~100 ms feels direct)

The rules change on the tap. Animations only show what already happened.

- Select: the tile lifts in 120 ms and bobs gently while selected.
- Place: the tile flies from its slot to the cell (220 ms, ease-out-back) and
  lands with a small squash and a clack.
- Return: it flies back to its new slot (200 ms).
- Reset: every letter flies home, staggered 30 ms in reading order.
- Shuffle: tiles arc to their new slots (260 ms) with a rattle.
- Targets fade in when a letter is selected, and breathe.
- Check: a soft light sweeps across the board, left to right (450 ms); problem
  letters get their hatching as the sweep passes, with a small shake.
- Win: tiles flip to the finished face in a diagonal wave, then square confetti
  in the share text's colors, and a rising chime.
- Loss: no shake and no confetti; tiles take their final faces quietly, unused
  letters fade, and a soft two-note phrase plays. The game says what was good:
  "7 of 12 letters crossed".
- The board's camera eases (250 ms) whenever its fit changes.

A player can turn motion down in the instructions sheet ("Calm motion"):
lifts, flights and sweeps become 80 ms fades.

## Sound

Synthesised at load in Ruby, so there are no audio files and nothing to
license: a wooden "tock" to pick up, a clack to place (pitch rising slightly
with each letter placed), a lighter tick to return, a rattle to shuffle, a
paper swish for the check, a muted thunk for problems, a rising four-note
chime for a win, a gentle falling two-note phrase for a loss, a soft click for
buttons, and a bright ding for "copied". A speaker button in the header mutes;
the game plays identically muted.

## Words (Podmajersky, Yifrah)

The status line always says what the player can do next, in their state:

- Nothing selected, letters in the pool: "Tap a letter to pick it up."
- A letter selected: "Now tap a glowing square to place it."
- All placed, problems: "3 letters need fixing. Tap one to send it back."
  followed by the reasons ("AZ is too short", "TCA isn't in the word list",
  "DOG isn't connected").
- Over: "Solved! All 12 letters crossed." or "7 of 12 letters crossed."

Buttons name their action: "Shuffle", "Reset", "Give up" (which asks "Give up?
Tap again" for three seconds before it acts), "Copy result" (then "Copied").

## Screens

- **Play**, the only real screen.
- **How to play**, a sheet over Play: shown at first launch until dismissed,
  reopened by the "?" in the header. It covers every point the rules require,
  shows the word-list credit, and links to Credits.
- **Credits**, a scrolling sheet: the full `wordlist-COPYRIGHT.txt`, the font
  licenses, and Lota and LÖVE.
- **Results** replace the controls when the game is over: the heading, the
  four statistics, the countdown to the next puzzle, "Copy result", and, once
  the countdown reaches zero, "Play No. N".
