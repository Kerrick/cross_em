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
| Empty board | one target where the first letter will go, breathing softly, brightening when a letter is picked up | accent |
| Placed letter | tile flat on the grid, thin edge | ivory tile |
| Target (only while a letter is selected) | dashed rounded square with a small "+", fading in and breathing | accent (blue-teal) |
| Problem letter | diagonal hatching across the tile, an outline and a folded corner, a small shake as the check finds it | vermilion |
| Finished letter (after the game) | inverted tile: dark face, light letter | ink blue |
| Unused letter (after a loss) | a ghost of a tile (the unused face) with a dotted outline and a muted letter | muted |
| Letter typed, not placed | a ghost tile: faint face, dashed outline, ink letter, in the strip | ink, muted outline |
| Typed letter that can't be had | the ghost tile hatched, with a folded corner, as soon as it is typed | vermilion |
| Typed word whose letters can all be had | every ghost outlined in the accent, and the ⏎ key under it too | accent |
| Pool letter a typed word would use | a short bar under its slot | muted ink |
| Letters placed (the strip's pips) | twelve small squares: solid for each letter on the board, hollow for each in the pool | ink |
| Problem letter (the strip's pips) | a pip outlined and struck through, as the sweep finds it | vermilion |
| A place a typed word fits (several) | the one shown: its new letters as ghost tiles in a solid outline of the whole word, a filled number on its corner; each other: only the cells it would fill, dashed and faint, its number outlined in the first | accent |
| Practice / looking back | a chip by the puzzle number with a dashed edge (nothing here is for keeps), a circling arrow and "Practice", or an eye and "Your board", and a × (a tap goes back to today) | ink, dashed outline |
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
| problem | `#B23A24` | `#FF7A5C` | problem marks and reasons, the armed Give up |
| finished face / edge / letter | `#24427F` / `#172C57` / `#FBF4E3` | `#4A73C9` / `#2F4F94` / `#FBF4E3` | finished tiles |
| won | `#2E7D4F` | `#5BC08A` | "Solved!" |
| glow | white at 60% | white at 16% | the check's sweep |

Problem vermilion and target teal differ strongly in lightness as well as hue,
so they stay apart for red-green color blindness; hatching, the folded corner
and the "+" carry the meaning regardless. The light page's vermilion is dark
enough (5.1:1 on the page) for the small type of a problem's reason. Confetti uses the share text's
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
  44 pt icon buttons: Past puzzles, How to play, appearance, sound, each
  named in a tooltip when a mouse rests on it) at the top; the board fills
  the middle, edge to edge; the strip; the pool as two rows of six; the
  controls row (Shuffle, Reset, Give up) at the bottom, in thumb reach.
  Everything inside the safe area. Once every letter is down the pool's
  twelve empty sockets give their room to the board, as after a win, and
  come back with the first letter sent back.
- **Landscape (tablet, desktop, a phone on its side; at least 560 pt wide and
  1.1× wider than tall):** the board takes the left, larger part; a column on
  the right (38% of the width, 320–430 pt) holds the strip, the pool and
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
- **After the game** the results take the strip's and the controls'
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
  phrase plays. Under the heading, a finished tile and "7/12": how many
  letters ended in good words, and, in vermilion, why the rest didn't.
- The results fade in as the board settles.
- The board's camera eases (250 ms) whenever its fit changes, even when the
  board's room changes at the end of the game. A drag takes over at once.

- Enter on a typed word that fits nowhere shakes the draft, as a problem
  letter shakes (320 ms), with the problem's thunk. Nothing is lost: the
  draft stays to be edited.
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

The game shows before it says. Reading is effortful and attention is
short (Johnson, Hodent), so in play the board, the tiles and their marks
carry what is going on, and the eye recognises a state rather than
reading about it. Every word on the screen does a job nothing else can,
and none repeats what the screen already shows (Strunk & White and
Zinsser: omit needless words; White: every element earns its place;
Lidwell: signal over noise; Saffer: bring the data forward, and let
feedback fit the moment).

- **The strip** under the board, where a status sentence used to be, is
  twelve pips, one a letter: solid for each on the board, hollow for each
  in the pool. It fills as the board does, so the rule that nothing is
  checked until all twelve are down is seen rather than told; when the
  check comes, the problem letters' pips turn to vermilion strikes as
  the sweep finds them. Then, and only then, a line of small type gives
  the reasons as briefly as they go ("AZ: too short", "TCA: not a word",
  "DOG: not joined", "Q: alone", then "+2" when they run out of room).
  The hatched tiles say which letters; the line says why.
- **Teaching.** A first-time player has How to play, and an empty board
  with one breathing glowing square, the thing the rules call a target.
  On a computer, two keycaps, A–Z and ⏎, sit under the empty pips: a word
  can be typed. A selected tile lifts and the targets glow, so "now tap a
  glowing square" goes unsaid.
- **Typing.** The draft is ghost tiles. A letter the pool and the board
  can't supply between them is hatched with a folded corner the moment it
  is typed: a letter on the board can be used again only by crossing it,
  so the most of a letter any word can use is the pool's count plus the
  board's, and in CHECKED with one E to be had the second E is marked.
  That is counting, never the word list (`WordFit#short`). A word whose
  letters can all be had turns the accent: ready. Under it, keycaps: ⏎ (in
  the accent when ready) and Esc. Enter with no place shakes the draft
  with a thunk (Swink, and Juice It or Lose It: under 100 ms, and felt;
  Juul: a failure whose cause can be seen is fair). Only when the letters
  are all there but the word still has no place are there words: "No
  room" or "Already there".
- **Choosing.** "1/3" in the accent, then Tab, ⏎ and Esc as keycaps; the
  places are numbered on the board, and a click or tap on one puts the
  word there.
- **What doesn't count** wears a chip (see the state table), in the
  header for as long as it is shown and in place of the statistics on its
  results, so a practice result can't be mistaken for the day's. A tap
  on the chip goes back to today.
- **Counts** are a glyph and a number: "7/12" beside a finished tile in
  the results, a glyph and "7/12" for each day in Past puzzles. "Crossed"
  is no longer used to mean "in a good word".

Words stay where they do a job: buttons, short verbs naming their action
("Shuffle", "Reset", "Give up", which turns vermilion and asks "Give up?"
for three seconds before it acts; "Copy result", then "Copied" with a
ding, or "Couldn't copy"; "Play again"; "Back to today"; "Play No. 1721"
once the clock runs out); the result's heading, "Solved!" or "Game over";
the clock, "Next puzzle" over HH:MM:SS; numbers and dates; the header's
tooltips; How to play, which keeps every rule and speaks the player's
device ("tap" on a touch screen, "click" with a mouse); the Credits, with
the word list's credit word for word; and the share text. A label too
long for its button wraps onto two lines in a smaller size rather than
being cut off.

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
  phones the title steps down a size to make room for it. The sheet ends
  with "Play" alone.
- **Credits**, a scrolling sheet over How to play. It opens with the game's
  own credit (a remake of a daily word puzzle, by Kerrick Long, under the
  GNU AGPL 3.0 or later), then the word list: its credit word for word ("Word list based on SCOWL by Kevin
  Atkinson and the sources it credits, …"), then the full
  `wordlist-COPYRIGHT.txt`; then Lota and LÖVE, and both
  fonts' licenses, each
  read from the files that ship with the game. The license texts are shown
  with every word as written, their hard-wrapped paragraphs reflowed to the
  sheet's width (`Presentation::Reflow`); a line of dashes becomes a rule.
  The body fades at an edge with more beyond it, and a thin bar shows where
  it is.
- **Past puzzles**, a sheet from the calendar in the header or the results'
  "Past puzzles": every puzzle from today back to No. 0, newest first, under
  a heading for each month that stays pinned while its days scroll. Each
  day shows its number and date and how the player did, as a glyph whose
  shape says it, never by color alone, and a count out of twelve: solved
  (a filled disc with a tick, "12/12"), game over (a ring with a cross and
  the good letters, "7/12"), in progress (a half-filled ring and the
  letters placed, "5/12"), not played (a faint dashed ring, no count). The
  counts line up in a column, so the glyphs do too. Only the rows in view
  are drawn (`ArchiveList`), and the month heading pinned at the top
  covers, and takes the taps of, the day under it.
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

- **Drafting.** Letters build a draft, shown in the strip as ghost tiles
  with a blinking caret (still in Calm motion), with the pool letters it
  would use marked by a bar. A letter that can't be had is hatched as it
  is typed, and a word whose letters can all be had is outlined in the
  accent (Words, above). Backspace edits it; Esc clears it.
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
  ghost tiles in the accent's outline, each other only as the cells it
  would fill, faintly; the camera frames it. Under the draft, "1/3" and the
  keycaps Tab, ⏎ and Esc. Tab and the arrows cycle, 1–9 place at once, a
  click or tap on a place puts it there, Enter or Space places the one
  shown, Esc goes back to the draft. Past nine (a word with nothing to
  cross can lie beside a board in two dozen places) only the one shown is
  drawn, since nine outlines already tangle and digits can't reach the
  rest; Tab still can. A tap on the pool or the board, Shuffle or Reset
  lets go of the places, which were worked out for a board that is gone,
  and keeps the draft. None, and the draft shakes and is kept to edit
  (Juul: a failure the player can see the cause of feels fair).
- **Through the rules.** Each new letter goes through `Game#place_letter`,
  a tap on its slot and then its square in one step, from the first slot
  holding that letter, so saving, events, the check when all twelve are
  down, the win and every animation are a tap's.
- **Taking back.** Backspace with nothing typed takes back the last typed
  word's own letters (never the ones it crossed), then the word before;
  with no typed word left, the letter placed last, as before.
- **Keys that meant something else.** Space still shuffles, but only with
  nothing typed and nothing being chosen, and, as the Shuffle button,
  which fades once the pool is empty as Reset does on an empty board,
  only with letters to shuffle; Enter still opens the next
  puzzle, but only with nothing typed. Letters no longer pick up tiles.

- **Every button on a key.** Letters type, so every other action is on
  a key that isn't a letter, or on a letter with Ctrl (Cmd on a Mac).
  Shift goes with the keys of the whole game: Shift+Backspace resets,
  Shift+Esc gives up (twice, as the button asks), Shift+Enter plays again;
  Space shuffles, Enter goes on from the results, Ctrl/Cmd+T goes back to
  today, Ctrl/Cmd+P opens Past puzzles, ? or F1 How to play (and C in it
  the Credits), Ctrl/Cmd+D flips the page, Ctrl/Cmd+S the sound, and
  Ctrl/Cmd+C copies. Each button shows its keys as keycaps after its label
  on a computer (never on a touch screen), and when they don't fit, or the
  button is an icon, a tooltip shows them; no sentence lists them (Johnson:
  recognition over recall). `KeyMap` turns a key into a named action
  (`:reset`, `:give_up`, `[:type, "C"]`), and `Play#act` carries it out
  through the same path as a click, so a key only acts when its button is
  live, and another input can name the same actions.

Touch and mouse play are unchanged.

## A controller, and one focus (`Spatial`, `FocusRing`, `FocusMap`, `StickCursor`, `PadMap`)

A game controller plays the whole game, and the keyboard's arrows share
what it moves: one focus, the single thing A (or Enter) would act on.
`PadMap` turns a button into the same named actions `KeyMap` names, so
`Play#act` carries them out through the click's path, and a button acts
only when it is live.

- **One focus, shown only when it is being used.** A ring marks it. It
  appears once the arrows or a controller are used and hides at the next
  tap or click, which also moves the focus to what was tapped, so the
  arrows go on from there (Saffer: no mode to manage). The first press
  after a tap only shows where the ring is, and moves nothing: a move
  from a place the player can't see would be a guess (Lee: predictable
  control). In a sheet the first press acts, as the arrows always have
  there. The ring is ink, standing 3 pt off what it marks with a hairline
  of the page inside it, so it never reads as a picked-up tile's own ring;
  round on the header's icons and a sheet's ×.
- **What can be focused** is what a tap would do something to: pool
  letters (empty sockets are passed over, as faded buttons are), the
  board's letters, its glowing squares while a letter is in hand (and an
  empty board's one square), live buttons, the header's icons (the
  chip, in practice), a sheet's ×, its title-bar button and its controls,
  and Past puzzles' days. After the game, the board and the pool are only
  to look at; the right stick still pans the board.
- **Moving by direction** (d-pad, arrows) works on the laid-out
  rectangles, so it follows every layout, orientation and scale
  (`Spatial`): of the targets whose middle lies past the focus's edge that
  way, the least gap along plus three times the gap across. In line comes
  first: a move never turns a corner while something lies straight ahead.
  Leaving a region, the nearest region that way is chosen by its bounds
  (the board's are its whole room) before any target in it, so a move
  never jumps over a region: up from the pool's corner, when the board's
  few letters are off to one side, lands on the board, not on the header
  above it (Johnson: the eye groups by region first). Only then, round a
  corner within the region. A move onto a board cell out of sight pans
  the camera to it. A test walks every target by the d-pad alone on a
  phone, on its side, a desktop, an upright iPad and a small phone, in
  play, with a letter in hand, on the results and in practice: none is a
  dead end, and all can be reached.
- **Pinned.** On the results with the clock still running, the clock is
  not a button, so nothing is straight above "Play again" but the header
  far off past the board; up goes to the share button instead, the
  results' own (`FocusMap.pins`). Past puzzles is a list, not a grid: Up
  and Down walk the days as before, and up from today reaches the ×.
  Elsewhere the rules above agreed with the screen, so nothing else is
  pinned.
- **Regions:** the header, the board, the pool, and the controls or the
  results; a sheet is a region of its own and the only one while open.
  LB and RB (Tab and Shift+Tab with nothing typed) jump between them in
  that order, wrapping, and each remembers its last focus; the first jump
  to the board with a letter in hand lands on its first glowing square.
  In a sheet, Tab steps through its controls and LB and RB page.
- **The focus is held by what it is, not where.** A slot, a cell, a
  button by name, so a rotation or a resize finds it again. When it goes
  (a letter placed from the pool, Reset fading), the nearest target left
  in its region takes over; when a sheet closes, the focus is where it
  was before.
- **The left stick** is a cursor with gravity, for where moving by
  direction guesses wrong. Past a 20% dead zone (a resting stick drifts),
  its speed grows with the square of the tilt, up to 1,100 pt a second;
  over a target it moves at 45% (friction), so it is easy to stop on one.
  The target under it is the focus as it moves, so it and the d-pad drive
  the same thing at any moment; let go, it glides onto the nearest target
  in 120 ms and fades. It is a small reticle, an ink ring and dot on whole
  pixels with a halo of the page, shown only while it moves (Swink: a
  response curve, and a cursor that reads at a glance). The d-pad carries
  it along with the focus, out of sight.
- **The right stick** pans the board, as a drag does and kept to the same
  bounds, or scrolls a sheet.
- **Buttons.** A acts on the focus: picks up or places a letter (it
  places a typed word, too), sends one back, presses a button, opens a
  day. B is Esc: puts a letter down, goes back from choosing a place,
  closes a sheet. X shuffles and Y gives up (twice, as the button asks);
  once the game is over, X plays again and Y copies the result, the two
  things left to do there. Back resets (the View button; Select on older
  pads), and Start opens How to play. While a typed word's places are
  shown the d-pad shows the next, as Tab does.
- **Hints.** While a controller is the last thing used, buttons show its
  glyphs where they showed keycaps, in the keycap's style: face buttons
  round, bumpers and Back and Start as pills. SDL names buttons by where
  they sit on an Xbox controller, so the glyphs follow the controller's
  family: letters for Xbox, shapes for PlayStation, and a Nintendo
  controller's own letters, which are swapped (its bottom button is B).
  A key brings the keycaps back; on a touch screen a tap brings nothing.
  The ringed header icon shows its tooltip, so icons are named for a
  controller too. How to play explains the controller while one is
  connected.
- **The keyboard shares the ring.** With nothing typed and no place
  being chosen, the arrows move it and Tab jumps regions. Enter and Space
  act on it only once it shows; until then Space shuffles and Enter goes
  on from the results as before. Typing a letter hides it, so a player
  who types words keeps every key as it was.
- **Hot-plug.** Controllers are kept as `joystickadded` and
  `joystickremoved` say, never listed each frame (that once crashed a
  Lota build on iOS); a joystick SDL doesn't know as a gamepad, such as
  iOS's accelerometer, is ignored.

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
  wears a chip by its number in the header (on the narrowest phones the
  wordmark, then the ×, give way; the chip's word never does). Its
  results show the chip instead of statistics (a look back's with the
  day's date), and "Back to today" takes the place of "Copy result", so a
  practice result is never shared as a real one (Ctrl/Cmd+C does nothing
  there either). While the day's game is unfinished past its day, the
  clock, which would sit at 00:00:00 with nothing after it, is left out.
- **No "see the solution".** A day has no single solution; "your board" is
  the one the player finished. Opening a day from Past puzzles shows that
  board, to look at, with "Play again"; a day never finished opens straight
  into practice, and never gets a record; today goes back to the official
  game (or opens today's, if the official game is an unfinished earlier
  day).
- **Getting back.** A tap on the chip; the results of practice and of a
  look back offer "Back to today"; Past puzzles' top row (today) does too.
- **The keyboard in the list.** Arrows move the focus ring from day to
  day (the first press lands on the top day in view), Page Up/Down a page,
  Home and End the newest and oldest; Enter opens the day. Up from today
  reaches the ×. The list scrolls to keep the ring clear of the pinned
  month heading.

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
