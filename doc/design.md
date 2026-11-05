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
| Empty board (until a letter is picked up) | the same sunken socket where the first letter will go | paper shade |
| Placed letter | tile flat on the grid, thin edge | ivory tile |
| Target (only while a letter is selected) | dashed rounded square with a small "+", fading in and breathing | accent (blue-teal) |
| Problem letter | diagonal hatching across the tile, an outline and a folded corner, a small shake as the check finds it | vermilion |
| Finished letter (after the game) | inverted tile: dark face, light letter | ink blue |
| Unused letter (after a loss) | a ghost of a tile (the unused face) with a dotted outline and a muted letter | muted |
| Letter typed, not placed | a ghost tile: faint face, dashed outline, ink letter, in a strip where the status line was | ink, muted outline |
| Pool letter a typed word would use | a short bar under its slot | muted ink |
| A place a typed word fits (several) | the word's cells outlined, numbered on its first corner; the one shown has a solid outline, a filled number and its new letters as ghost tiles | accent |
| Practice / looking back | a tag by the puzzle number, "Practice · doesn't count" or "Your board · read-only", for as long as the game is shown | ink outline |
| Won | heading "Solved!", tiles flip in a diagonal wave, square confetti | green heading |
| Lost | heading "Game over", tiles settle quietly, nothing celebrates | ink heading |

Appearance follows the system (`Lota::Window.system_theme`, re-read on
`themechanged`) unless the player flips it with the header's appearance
button: a filled sun on the light page, a crescent moon on the dark one.
A tap flips the page shown, light to dark or back. If the page it lands on
is the one the system shows, the setting goes back to following the
system, so the game keeps following it (at sunset, say); only a page the
system doesn't show is kept as a choice, and a system that can't say
(`:unknown`) keeps the page asked for (`Appearance.flip`, unit tested).
An earlier three-way cycle (System, Light, Dark) left a player who once
picked Light stuck there after their computer went dark. Light is "morning paper"; dark is "night edition": deep ink-blue
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
| unused face | tile face at 50% | tile face at 12% | letters left over after a loss (half strength turned into a grey slab on the night page) |
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

- **Portrait (phone, narrow window):** header (wordmark, puzzle number, four
  44 pt icon buttons: Past puzzles, How to play, appearance, sound) at the top; the board fills the middle, edge to edge;
  one status line; the pool as two rows of six; the controls row (Shuffle,
  Reset, Give up) at the bottom, in thumb reach. Everything inside the safe
  area.
- **Landscape (tablet, desktop, a phone on its side; at least 560 pt wide and
  1.1× wider than tall):** the board takes the left, larger part; a column on
  the right (38% of the width, 320–430 pt) holds the status line, the pool and
  the controls, centred top to bottom. Six tiles a row, or four if six would
  be under 44 pt.
- **Short of room** (a small phone, a short window, the results), the layout
  packs tighter step by step — smaller gaps, a smaller heading and
  statistics, then, after the game, when the pool can no longer be tapped,
  smaller pool tiles — and failing that turns the other way round, so the
  board always keeps at least one 44 pt cell and every part stays on screen.
  On the narrowest phones the puzzle number gives way to the wordmark.
- Pool tiles are at least 44 pt (≈ 7.8 mm on an iPhone) and grow to 64 pt;
  controls are 48 pt tall.
- **Big screens** draw the whole design larger rather than showing more
  empty paper. Where the window is wider and taller than 1200 × 820 pt,
  `Units.for_window` multiplies the screen's density by the window's
  excess, rounded down to an eighth and at most 1.5×: a 1920 × 1080
  desktop draws at 1.25×, a 1366 × 1024 iPad on its side at 1.125×; phones,
  upright tablets and 1280 × 800 laptops are unchanged. It is one scale on
  the point-to-pixel conversion, so every size still rounds to whole pixels
  and type is still rasterised at its exact size; nothing is resampled, and
  nothing drops below its smallest size in points (44 pt cells and tiles).
  Eighths keep the sizes few, so resizing a window rebuilds fonts rarely.
- **Very wide windows** set the game on a page: where the window is wider
  than 1180 pt plus a 64 pt margin either side, everything is laid out on a
  1180 pt sheet of the dotted paper, centred and 16 pt from the top and
  bottom, lying on a darker desk (page shade) with a soft shadow and a
  hairline edge. Before, the board sat in the middle of a huge left area
  and the column hugged the window's far edge, so the halves never met; on
  the page they read as one spread. A window too short to fit the game on
  the page gives up the page before the board.
- **After the game** the results take the status line's and the controls'
  place: the heading and what was good, the four statistics, the clock to the
  next puzzle and "Copy result", and under them a row with "Play again" and
  "Past puzzles". When even the smallest pool leaves no room (a phone on its
  side), the two rows share one row of four. The statistics share the measure of the
  row under them (at most 520 pt), so on an upright tablet they don't hang
  out past it. The pool stays only while letters are left
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

- A typed word's letters leave the pool one after another, 70 ms apart,
  each a tap's flight and clack, so the clacks climb the scale as a little
  run; a check its last letter sets off waits for that letter, as after a
  tap. A word taken back with Backspace returns staggered as a reset does.

A player can turn motion down in How to play ("Calm motion"): lifts, flights,
the sweep and the wave become 80 ms fades, nothing bobs or breathes, the camera
jumps, and there is no confetti.

## Sound (`Presentation::Synth`, `Presentation::Sounds`)

Synthesised in Ruby as the game starts (one sound a frame, so the first frames
don't stall), so there are no audio files and nothing to license. Felt-covered
wooden tiles and a soft marimba: warm and round, with presence but never a
punch (Saffer: feedback should fit the moment and be no more than it needs).

- A soft marimba G to pick up (down a third, to E, to put down), a marimba C
  with a thump of wood to place (climbing the scale, C to the E an octave up,
  as the grid fills), a lighter D to return, four soft taps tumbling to
  shuffle (a fourth lower for a reset), a breath of paper under the check's
  sweep, a muted low thunk for problems as the sweep ends, rounded bells
  rising C–E–G–C over a low C for a win, E settling to C for a loss, a tiny
  tap for buttons, and two small bells for "copied".
- Every voice is sines: a body with gentle second and third partials (a bell
  adds a faint inharmonic one), a soft attack of 8 ms or more, an exponential
  decay, and a low-pass, 1.5–4 kHz. No square, saw or raw noise; the check's
  breath is noise kept to a band around 900 Hz. Under 0.1% of any sound's
  energy is above 6 kHz.
- Every pitch is from C major pentatonic, so sounds that happen to ring
  together agree.
- Each sound is as loud as it matters, by its peak: a button −20 dBFS, pick
  and return −18, shuffle −17, place −14, the check −19, problems and
  "copied" −16, a loss −12, a win −8. Voices play at full volume, and a whole
  game mixed (SoundsTest) peaks at the win's −8 dBFS, leaving headroom for
  any overlap.
- One action, one sound, or a phrase in order: the last letter's clack, then
  the check's breath swelling under it, then the thunk or the ending once the
  sweep has passed. Giving up plays the loss alone, without a thunk. The same
  sound asked for twice within 30 ms plays once, a free voice is preferred to
  cutting one off, and a win or a loss fades whatever else still rings.

`ruby script/preview_sounds.rb DIRECTORY` writes each sound and a whole game
as WAVs. The speaker button in the header mutes; the game plays identically
muted, and without an audio device.

## Words (Podmajersky, Yifrah; `Presentation::Copy`)

The status line always says what the player can do next, in their state:

- Nothing selected, the board empty: "Tap a letter to pick it up.", and on a
  computer, under it, "Or type a word and press Enter."
- Typing: the draft as ghost tiles, and under it "Enter places it. Esc
  clears it." A word that fits nowhere keeps its draft and says why, in the
  problem color: "CRAB needs a B that isn't in the pool.", "CRABB needs more
  Bs than the pool has.", "CAT is already on the board.", "CRAB doesn't fit
  anywhere on the board."
- Choosing: "CRAB fits 3 places. Showing 1." and "Tab: next · 1–3: pick ·
  Enter: place · Esc: back".
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
"Copy result" (then "Copied" for a few seconds, with a ding, or
"Couldn't copy" if the clipboard refused it), "Play No. 1721"
once the clock runs out. A label too long for its button wraps onto two lines
in a smaller size rather than being cut off.

## Screens

- **Play**, the only real screen.
- **How to play**, a sheet over Play: shown at first launch until dismissed,
  reopened by the "?" in the header (or the ? key). Under its first
  sentence is a small example board, a patch of the dotted paper with WORD
  across and ROW down from its R in real tiles and a glowing square beside
  them, captioned "WORD and ROW cross at the R. The glowing square is a
  place the next letter can go." The picture teaches "crossword style" and
  "glowing square" before the rules say them. Then every rule, the keyboard
  on a computer, the Calm motion switch, and buttons to Credits and to
  Play. A Credits button also sits in its title bar beside the ×, so the
  Credits are two taps from the header without scrolling; on the narrowest
  phones the title steps down a size to make room for it.
- **Credits**, a scrolling sheet over How to play. It opens with the word
  list: its credit word for word ("Word list based on SCOWL by Kevin
  Atkinson and the sources it credits, …"), then the full
  `wordlist-COPYRIGHT.txt`; then Cross ’em itself, Lota and LÖVE, and both
  fonts' licenses, each
  read from the files that ship with the game. The license texts are shown
  with every word as written, their hard-wrapped paragraphs reflowed to the
  sheet's width (`Presentation::Reflow`); a line of dashes becomes a rule.
  The body fades at an edge with more beyond it, and a thin bar shows where
  it is.
- **Past puzzles**, a sheet from the calendar in the header or the results'
  "Past puzzles": every puzzle from today back to No. 0, newest first, under
  a heading for each month that stays pinned while its days scroll. Each
  day shows its number and date and how the player did, in a word and a
  glyph, never by color alone: "Solved" (a filled disc with a tick, "All 12
  crossed"), "Game over" (a ring with a cross, "7 of 12 crossed"), "In
  progress" (a half-filled ring, "5 letters placed"), "Not played" (a faint
  ring with a dash). Only the rows in view are drawn (`ArchiveList`).
- **Results** replace the controls when the game is over: the heading, the
  four statistics (played, win %, streak, best streak), the countdown to the
  next puzzle (09:00 UTC, for everyone at once), "Copy result", and, once the countdown reaches zero,
  "Play No. N", which opens the new day's puzzle without restarting.

A sheet closes with its ×, a tap outside it, or Esc.

## Typing a word (`CrossEm::WordFit`, `Presentation::Typing`)

The first keyboard mode had a typed letter pick up a tile, so a word took a
letter key and a click on a square for every letter: the mouse play,
slower. Players think in words, so a keyboard now takes a whole word
(Saffer: the trigger should match the player's intent, not the system's
steps).

- **Drafting.** Letters build a draft, shown where the status line was as
  ghost tiles with a blinking caret (still in Calm motion), with the pool
  letters it would use marked by a bar. Backspace edits it; Esc clears it.
  At most twelve letters, since no word can use more. Typing puts down a
  letter picked up with a tap, so only one thing is ever in hand.
- **Fitting is geometry only.** The rules give no feedback while letters
  wait in the pool, so the search never asks the word list or the Referee:
  a nonsense word fits wherever its letters do, and placements are never
  ranked by whether the words they make are real. A word fits a run across
  or down whose cells each hold that letter already or are empty and filled
  from the pool (counted letter by letter), adding at least one letter,
  with empty cells just before and after (so the run reads exactly the
  word: CAT then CATS adds just the S, and CAT never fits inside CATS),
  touching the board by crossing or lying beside it. An empty board takes
  it across from the origin. Placements that cross a letter are the only
  ones offered when there are any (they are almost always what was meant);
  otherwise those that lie beside. They come in reading order of their
  first cell, across before down, so the numbers are the same each time.
- **Choosing.** One place, and the word goes there at once. Several, and
  the board shows them numbered, the current one with its new letters as
  ghost tiles in the accent's outline, the rest outlined faintly; the
  camera frames it. Tab and the arrows cycle, 1–9 place at once, Enter or
  Space places the one shown, Esc goes back to the draft. Past nine (a
  word with nothing to cross can lie beside a board in two dozen places)
  only the one shown is drawn, since nine outlines already tangle and
  digits can't reach the rest; Tab still can. None, and the reason is
  given and the draft kept to edit (Juul: a failure the player can see the
  cause of feels fair).
- **Through the rules.** Each new letter goes through `Game#place_letter`,
  a tap on its slot and then its square in one step, from the first slot
  holding that letter, so saving, events, the check when all twelve are
  down, the win and every animation are a tap's.
- **Taking back.** Backspace with nothing typed takes back the last typed
  word's own letters (never the ones it crossed), then the word before;
  with no typed word left, the letter placed last, as before.
- **Keys that meant something else.** Space still shuffles, but only with
  nothing typed and nothing being chosen; Enter still opens the next
  puzzle, but only with nothing typed. Letters no longer pick up tiles.

Touch and mouse play are unchanged.

## Playing again and the archive (`Presentation::ArchiveList`, `Session#practice`)

The first play of each day is the record; everything else is for fun and
never counts (Juul: a practice run is safe to fail because it costs
nothing).

- **One official game, at most one other.** Play holds the day's official
  game (the one `Session#open` saves) and shows either it, a practice game
  (`Session#practice`: a fresh pool and empty board, never saved, in
  memory only) or a look back at a finished day (`Session#review`: the
  record restored, check marks and all; it is over, so nothing can change
  it, and it is never saved). Moving between them never touches the
  official game.
- **Labelled for as long as it is shown.** A practice game or a look back
  carries a tag by its number in the header. Its results show no
  statistics but a line saying what it is ("A practice game. It isn't saved
  or counted."), and "Back to today" takes the place of "Copy result", so a
  practice result is never shared as a real one (Ctrl/Cmd+C does nothing
  there either).
- **No "see the solution".** A day has no single solution; "your board" is
  the one the player finished. Opening a day from Past puzzles shows that
  board read-only with "Play it again"; a day never finished opens straight
  into practice, and never gets a record; today goes back to the official
  game (or opens today's, if the official game is an unfinished earlier
  day).
- **Getting back.** The results of practice and of a look back offer "Back
  to today"; during a practice game, Past puzzles' top row (today) does.
- **The keyboard in the list.** Arrows move a ring from day to day (the
  first press lands on the top day in view), Page Up/Down a page, Home and
  End the newest and oldest; Enter opens the day. The list scrolls to keep
  the ring clear of the pinned month heading.

## The icon (`script/make_icon.rb`, CC0)

The game's own materials on a rounded square of the finished tiles' ink
blue: ivory tiles with their darker lower edge, and ink letters in Zilla
Slab Bold, filled from the font file that ships with the game by a small
TrueType reader and scanline filler in the script (pure Ruby, nothing to
install). From 128 px up the tiles spell a tiny crossword, CROSS across and
REM down from its R, so it reads "Cross … em", on a few faint graph-paper
dots. Seven letters can't be read smaller, so below 128 px it shows three
bigger tiles meeting at a corner, the first lettered C from 32 px up, and
at 16 and 24 px only the tiles. Each size is drawn at its own size, never
scaled. The first icon, five blank tiles in a "+", read as a first-aid
sign. On a computer the
pointer becomes a hand over anything a click would change, and a four-way
arrow over a board that pans.
