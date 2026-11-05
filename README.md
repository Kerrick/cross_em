# Cross ’em

Every day, everyone gets the same twelve letters. Arrange all of them into a
single connected crossword of real words.

Cross ’em is a remake of a daily word puzzle, written in Ruby on
[Lota](https://github.com/setdef/Lota), which runs Ruby games on the LÖVE 2D
engine. Its daily letters match the original game's, so players of both get
the same puzzle and can compare results.

## Playing

1. Tap a letter in the pool to pick it up.
2. Tap a glowing square on the grid to place it.
3. Tap a placed letter to send it back to the pool.

Every word must be a real word of three or more letters, and all the letters
must connect. The game checks your crossword once all twelve letters are on
the grid, and ends when it's correct or when you give up. Use as many letters
as you can. When the game is over, "Copy result" puts your result on the
clipboard, ready to paste.

The calendar in the header (or "Past puzzles" after a game) lists every
puzzle back to No. 1 with how you did. Open a finished day to see your board,
and play any day again for fun. Practice games are marked as practice, are
never saved, and never change your statistics; the first play of each day is
the one that counts.

### On a keyboard

Type a whole word and press Enter (or Space). The game puts its letters where
the word fits, using letters already on the board where they match. If it fits
more than one place, the places are numbered on the board.

| Key | What it does |
| --- | --- |
| A–Z | Type a word |
| Enter, Space | Place it. With nothing typed, Enter plays the next puzzle when it's ready and Space shuffles |
| Tab, arrows | When a word fits several places, show the next one (Shift+Tab, Up, Left: the one before) |
| 1–9 | Place the word in that numbered place |
| Backspace | Delete the last letter typed. With nothing typed, take back the last word placed, then the one before |
| Esc | Go back from choosing a place, clear what you typed, put down a letter, or close a sheet |
| ? | How to play |
| Ctrl+C (Cmd+C on a Mac) | Copy the result once the game is over |
| F11 | Fullscreen |

In Past puzzles, Up and Down move from day to day, Page Up, Page Down, Home and
End move further, and Enter opens the day.

## Getting the game

Players without Ruby can download a built app for Linux, Windows or macOS from
the [Releases page](https://github.com/Kerrick/cross_em/releases).
[PACKAGING.md](PACKAGING.md) explains each platform's files, how to install
them, and how releases are made. iPhone and iPad builds come as an Xcode
project from Lota's experimental iOS kit; see "iPhone and iPad" below.

## Running from source

You need:

- **Ruby 4.0.9.** The version is in `.ruby-version`, and `mise install` sets
  it up if you use [mise](https://mise.jdx.dev).
- **Lota 0.1.3**, which `bin/setup` fetches for you. Lota isn't on
  RubyGems.org, so the script downloads its gems from
  [Lota's v0.1.3 release](https://github.com/setdef/Lota/releases/tag/v0.1.3)
  into `vendor/cache`, checks them against the release's checksums, and runs
  `bundle install`. On Linux the game needs an X11 or Wayland desktop with
  OpenGL.

Then, from this folder:

```sh
bin/setup
bundle exec lota run
```

Your games are saved in Lota's save folder under `cross_em`. On a Mac that's
`~/Library/Application Support/Lota/cross_em` when run with `lota run`, and
`~/Library/Application Support/cross_em` for a built app.

## Running the tests

```sh
bundle exec rake test
```

The tests cover the rules without opening a window: the daily letters (all of
the original's test vectors), the pool and grid, word checking, winning and
giving up, saving and restoring, statistics, the exact share text, where a
typed word fits, and that practice games are never saved. They
also cover the pure-Ruby parts of the presentation, such as the layout, the
board's fit and panning, input routing, the words on screen, and the sounds.

## Developer tools

`main.rb` documents environment variables for development. With them you
can open the window at a phone's size, pretend it's another day, replay a
scripted game, take screenshots, or run silently. For example, this shows a
winning game for No. 1720 at iPhone size:

```sh
CROSS_EM_SAVE_AS=try CROSS_EM_TODAY=2026-11-05 CROSS_EM_WINDOW=390x844 \
CROSS_EM_SCRIPT=close,word:MITER:0:0:across,word:WALKER:3:-4:down,word:JAK:2:-3:across \
  lota run .
```

Scripts can also type, as a player at a keyboard would
(`type:MITER,key:return,key:tab`), and visit the archive
(`archive`, `day:1700`, `again`, `today`).

`ruby script/solve.rb 2026-11-05` finds boards that win a day's puzzle, and
prints each one as a script like the one above. `ruby script/preview_sounds.rb
DIR` writes every sound as a WAV file. `ruby script/make_icon.rb` redraws the
app icon.

## How it's built

- `lib/cross_em/` holds the rules: plain Ruby values (`Day`, `Pool`, `Board`,
  `Check`, `Record` and more) and one `Game` that announces events. Nothing
  there knows about Lota. The puzzle's fixed data lives in
  `lib/cross_em/rules.rb`.
- `lib/cross_em/presentation/` decides how the game looks, moves, sounds and
  answers input, still in plain, tested Ruby. Its look is in `look.rb` and
  `palette.rb`.
- `lib/cross_em/shell/` carries that out with Lota: drawing, sound, the save
  folder and the clipboard.
- `doc/design.md` explains the design and why it is the way it is.

The game draws at the screen's native resolution. Lota's DPI scaling is off,
so the game converts its point-based layout to whole physical pixels itself,
and text and lines land exactly on pixels with nothing resampled.

## iPhone and iPad

Lota's iOS support is experimental. Its maintainer builds an Xcode project
("kit") for Cross ’em on CI. To play it on your own device, you open that
project in Xcode, sign it with your Apple ID (a free account works, but the
app must be re-installed every 7 days), and run it on a device connected by
cable. The kit comes with step-by-step instructions, and
`doc/playtest-questions.txt` lists what to report back.

## Credits and licenses

- Cross ’em is © 2026 Kerrick Long, under the
  [GNU AGPL 3.0 or later](LICENSE), as Lota is.
- The word list is based on SCOWL by Kevin Atkinson and the sources it
  credits, including ENABLE and the UK Advanced Cryptics Dictionary,
  Copyright (c) J Ross Beresford 1993-1999. All Rights Reserved.
  `wordlist.txt` and `wordlist-COPYRIGHT.txt` ship together, unmodified, and
  the game shows the full notice in its Credits.
- The fonts are Atkinson Hyperlegible (© 2020 Braille Institute of America)
  and Zilla Slab (© 2017 The Mozilla Foundation), both under the SIL Open
  Font License; see [assets/fonts/README.md](assets/fonts/README.md).
- The sounds are synthesised by the game's own code. The icon is drawn by
  `script/make_icon.rb` and is CC0 ([LICENSES/ICONS.md](LICENSES/ICONS.md)).
- Lota is AGPL-3.0-or-later, and LÖVE is zlib-licensed. Lota is not made or
  endorsed by the LÖVE Development Team.
