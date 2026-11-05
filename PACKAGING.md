# Packaging Cross ’em

Most players don't have Ruby installed, so Cross ’em also ships as a self-contained app. `lota fuse` builds it: it hands the game to [Fledge](https://github.com/setdef/Fledge), which copies the game, Lota, and a copy of Ruby built to run from any folder into one app, and packs that app into an archive and an installer. "Fused" is LÖVE's term for a game shipped as a standalone app.

Each platform builds only its own app, so CI builds each on a runner of that platform.

| Platform | Files |
| --- | --- |
| Linux x86_64 | `Cross ’em-x86_64-linux-gnu.AppImage` and `Cross ’em-x86_64-linux-gnu.tar.gz` |
| Linux aarch64 | the same two files, named `aarch64-linux-gnu` |
| Windows x64 | `Cross ’em-x64-mingw-ucrt.zip`, holding `Cross ’em.exe`; and `Cross ’em-x64-mingw-ucrt-setup.exe`, an installer that doesn't need administrator rights |
| macOS, Apple silicon | `Cross ’em-arm64-darwin.dmg` and `Cross ’em-arm64-darwin.tar.gz`, holding `Cross ’em.app` |

The names above are what Fledge writes. GitHub's Releases page changes some characters in file names (a space becomes a dot, and it may drop or replace the curly apostrophe), so a file may appear there under a slightly different name.

## Getting a build

### From a release

Tagged versions are on the [Releases page](https://github.com/Kerrick/cross_em/releases), each with all the builds. They are marked as prereleases.

### From any push to `main`

The [Package workflow](.github/workflows/package.yml) builds every platform on each push to `main`:

1. Sign in to GitHub. Downloads from workflow runs require it.
2. Open the [Package workflow's runs](https://github.com/Kerrick/cross_em/actions/workflows/package.yml) and choose a run with a green check mark.
3. At the bottom of the run's page, under Artifacts, download `cross-em-linux-x86_64`, `cross-em-windows-x64`, or `cross-em-macos-arm64` (or `cross-em-linux-aarch64`). Each is a `.zip` holding that platform's files.

GitHub deletes artifacts after its retention period, 90 days by default. A build from a push to `main` has the version `0.0.N`, where N is the workflow's run number.

## Installing

### Linux

The AppImage is one file. Make it executable and run it:

```console
$ chmod +x "Cross ’em-x86_64-linux-gnu.AppImage"
$ ./"Cross ’em-x86_64-linux-gnu.AppImage"
```

Or unpack the `.tar.gz` anywhere and run the `Cross ’em` program in the folder it makes. The folder also holds a desktop entry.

The app needs glibc 2.39 or newer (Ubuntu 24.04, Debian 13, Fedora 40 or newer), because that is what Fledge's Ruby for Linux needs. It also needs an OpenGL driver, which any desktop with a graphics driver has. An AppImage needs FUSE 2 (`libfuse2` on Ubuntu 24.04); without it, run `./app.AppImage --appimage-extract-and-run`, or use the `.tar.gz`.

### Windows

Run `Cross ’em-x64-mingw-ucrt-setup.exe`. It installs the game into `%LOCALAPPDATA%\Programs` and adds a Start menu shortcut. Or unpack the `.zip` anywhere and run `Cross ’em.exe` from the unpacked folder.

The build isn't signed, so Windows SmartScreen warns about it the first time. Choose **More info**, then **Run anyway**.

To uninstall, use Settings > Apps, or run `uninstall.exe` in the folder the game was installed to.

### macOS

Open the `.dmg` and copy `Cross ’em.app` to Applications, or anywhere you like. The app isn't notarized by Apple, so the first time, right-click it and choose **Open**, then confirm.

## Where a packaged build saves its files

A fused game saves in a folder named after its identity (`cross_em`) directly in the system's application-data folder, as shipped LÖVE games do:

| Platform | Folder |
| --- | --- |
| Linux | `~/.local/share/cross_em` |
| Windows | `%APPDATA%\cross_em` |
| macOS | `~/Library/Application Support/cross_em` |

`bundle exec lota run` saves in a `Lota` folder inside the application-data folder instead (`Lota/cross_em`), so a development run and a packaged build keep separate stats and saves.

## Cutting a release

1. Make sure `main` is green.
2. Tag the commit and push the tag. Use the form `v0.X.Y`. For example, for 0.2.0:

   ```console
   $ git tag v0.2.0 && git push origin v0.2.0
   ```

The tag, without its `v`, is the app's version. Pushing a tag that starts with `v0.` makes the Package workflow build every platform and attach the builds to a new GitHub prerelease for the tag. Nothing is published to RubyGems.

## What CI checks

The Package workflow runs on every push to `main`, on every tag that starts with `v0.`, and when started by hand from GitHub's Actions page. It has three jobs:

- **Test**, on Ubuntu, runs `bundle exec rake test`.
- **Fuse**, once per platform (Linux x86_64 and aarch64, Windows x64, macOS arm64) after Test passes:
  - downloads Lota 0.1.3's gem for the platform from [its release](https://github.com/setdef/Lota/releases/tag/v0.1.3), checks it against the release's `SHA256SUMS`, and installs it;
  - runs `lota fuse . --identifier com.kerricklong.CrossEm --app-version VERSION --icon icons/icon --out dist`;
  - runs `script/smoke.sh dist`, the no-window check described below;
  - on Linux, also tries to run the app for real under Xvfb with Mesa's software OpenGL (llvmpipe), with `CROSS_EM_QUIT_AFTER=5`, which makes the game quit with status 0 after five seconds. This step is allowed to fail for now, so a failure shows up as a warning and not as a red build;
  - uploads the platform's files as an artifact.
- **Release** runs only for a `v0.` tag, and attaches every artifact to a GitHub prerelease.

### The no-window check

CI's runners have no graphics card, so most of them can't start the game. `lota fuse` writes a program of its own for the app, so the check doesn't go through that program. `script/smoke.sh` instead unpacks the archive, then runs the Ruby that ships inside the app, with an almost empty environment, on `bin/cross_em`, the game's own launcher. When the environment variable `CROSS_EM_SMOKE` names a file, the launcher loads Lota, then `conf.rb` and `main.rb` from the packaged copy of the game, calls `Lota.conf`, writes what it found to the file, and exits with 0, or with 1 if anything is missing. Loading those files requires every file they depend on, so a file that didn't ship fails here. It never opens a window.

You can run it on a build of your own:

```console
$ lota fuse . --identifier com.kerricklong.CrossEm --icon icons/icon
$ script/smoke.sh dist
```

## Building on your own computer

You need Ruby 4.0.9 (the version in `.ruby-version`), Lota's gem for your platform from the release page, Git, and the network (Fledge is fetched from GitHub, and downloads its runtime the first time, which takes a minute or two).

```console
$ lota fuse . --identifier com.kerricklong.CrossEm --app-version 0.1.0 --icon icons/icon
```

The files appear in `dist/`, which git ignores. On Windows, Fledge's runtime includes NSIS, so the setup program needs nothing else installed.

## The icon

`script/make_icon.rb` draws the icon in code, in pure Ruby: five ivory tiles in a "+" on a rounded square of ink blue, from the palette in `doc/design.md`. Every size is drawn sharp, not scaled. It writes `icons/icon-16.png` through `icons/icon-1024.png`, `icons/icon.ico`, and, on a Mac, `icons/icon.icns` (with `iconutil`). The generated files are committed, so CI needs no tools to make them. The icon is released under CC0 (see `LICENSES/ICONS.md`).

## iOS

An iPhone or iPad build is made separately, with Lota's maintainer. It needs `bin/cross_em` from this repository, the launcher. `lota fuse` doesn't build for iOS.

## What has been verified, and what hasn't

Verified, on the maintainer's Apple-silicon Mac, with a stand-in `conf.rb` and `main.rb` (the real ones were being written at the same time):

- `lota fuse` with the arguments above builds `Cross ’em-arm64-darwin.tar.gz` and `.dmg`. Fledge, the file system, and the archive tools all cope with the curly apostrophe (U+2019) in the name.
- `script/smoke.sh` on that build reports `status 0`.

Not verified:

- **The Linux and Windows builds.** They follow Lota's own `fuse.yml`, but this workflow had not run on those platforms when this was written.
- **`script/smoke.sh` on Windows**, which runs the app's Ruby from Git Bash, and the exact layout of Fledge's Linux and Windows archives. The script finds the files by pattern.
- **Playing on a real PC.** Nobody has yet played a packaged build on Windows or Linux with a real graphics card and driver, real sound, or touch.
- **Linux on other distributions.** The AppImage was not tried on anything older than glibc 2.39.
- **Restarting.** `lota run` restarts a game that calls `Lota::Event.restart`; a fused app quits instead.
- **Signing.** The builds are unsigned, so SmartScreen and Gatekeeper warn about them, and the `.dmg` isn't notarized.
- **Starting the fused app's window from the build.** On the maintainer's Mac, the stand-in game's app did not get past Lota's start-up when run from an agent's shell with no display session, so opening the window from a build is still to be confirmed on a desktop.
