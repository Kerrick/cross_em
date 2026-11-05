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

The tag, without its `v`, is the app's version. Pushing a tag that starts with `v0.` makes the Package workflow build every platform and attach the builds to a new GitHub prerelease for the tag. It also makes the iOS kit workflow build the iOS kit and attach it to the same prerelease, about an hour later. Nothing is published to RubyGems.

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

`script/make_icon.rb` draws the icon in code, in pure Ruby: ivory letter tiles on a rounded square of ink blue, from the palette in `doc/design.md`, spelling CROSS across and REM down from its R (three bigger tiles, the first lettered C, below 128 px). It fills the letters from the game's own Zilla Slab Bold, reading the font file itself. Every size is drawn sharp, not scaled. It writes `icons/icon-16.png` through `icons/icon-1024.png`, `icons/icon.ico`, and, on a Mac, `icons/icon.icns` (with `iconutil`). The generated files are committed, so CI needs no tools to make them. The icon is released under CC0 (see `LICENSES/ICONS.md`).

## iPhone and iPad

`lota fuse` doesn't build for iOS, and Apple allows no app that runs games it downloads, so an iPhone or iPad build is an Xcode project, the "iOS kit", that whoever plays it opens in Xcode, signs with their own Apple ID, and runs on their device. The [iOS kit workflow](.github/workflows/ios-kit.yml) makes it with Lota's iOS kit tooling, which is experimental and unsupported: it checks out Lota at a pinned commit of its `experiment/ios-kit-1` branch (`5e68d3d`) and runs that commit's `ipad/` scripts and `rake ios:sdl3`, with this repository as the game. It builds SDL3 for iOS, then has [Fledge](https://github.com/setdef/Fledge) 0.5.0's `fledge build ios` write the project around `bin/cross_em`, the game's launcher. Lota's own CI never builds a game's app, so this workflow runs here.

The app is `Cross ’em` under its icon (`icons/icon-1024.png`), with the identifier `com.kerricklong.CrossEm` and the Xcode target `CrossEm`. It turns to portrait and landscape on an iPhone and to all four orientations on an iPad, hides the status bar, and uses the `ambient` audio session, so it mixes with other apps' music and the silent switch mutes it.

### Getting the kit

- **From a release.** Pushing a `v0.*` tag runs the workflow, which attaches `CrossEm-ios.zip` and `CrossEm-ios-SHA256SUMS.txt` to the tag's prerelease, beside the Package workflow's builds.
- **From a workflow run.** Start it by hand on GitHub's Actions page, or with `gh workflow run ios-kit.yml -R Kerrick/cross_em --ref main`. A green run's `ios-kit` artifact holds `CrossEm-ios.zip`, `kit.json` (the settings the run used), and `SHA256SUMS`: `gh run download RUN -R Kerrick/cross_em -n ios-kit`.

Check the zip with `shasum -a 256 -c`, then unpack it with Finder or `ditto -x -k CrossEm-ios.zip .`. Both keep the symbolic links the frameworks inside need; tools that drop them break the project.

### Building and running it

You need a Mac with Xcode (the version `BUILD-INFO.txt` in the kit names, or newer), an Apple ID, and a cable. You don't need Ruby, Lota, Fledge or XcodeGen. `README.txt` in the kit has every step; in short:

1. Open `CrossEm-ios/CrossEm.xcodeproj`.
2. Add your Apple ID in Xcode > Settings > Apple Accounts. On the CrossEm target's Signing & Capabilities tab, turn on automatic signing and choose your team. If Xcode says `com.kerricklong.CrossEm` isn't available, change it to an identifier of your own, such as `com.yourname.CrossEm`.
3. Connect the device, unlock it, and trust the Mac. Turn on Developer Mode on the device (Settings > Privacy & Security > Developer Mode) and let it restart.
4. Choose the device as the run destination and press Run. If the first launch stops at "Untrusted Developer", open Settings > General > VPN & Device Management on the device, trust your Apple ID, and press Run again.

A free Apple ID signs the app for 7 days. After that it won't launch until you connect the device and press Run again, which keeps the game's saves. To play a newer build, get the newer kit and repeat steps 1, 2 and 4 with the same identifier.

Playtesters answer the questions in `CrossEm-results.txt`, next to the kit's `README.txt`, and send that file back. The questions come from `doc/playtest-questions.txt`.

### What the workflow checks

It has the three jobs of Lota's iOS kit workflow, plus a release job for tags:

1. **The Xcode project** builds SDL3 for iOS, lays the game out, runs `fledge build ios`, fails if the project names a path on the runner, and uploads `ios-kit`.
2. **A fresh Mac, in portrait.** A second runner with no Lota, Fledge, XcodeGen or gems unpacks the zip and builds it with `xcodebuild` for the Simulator and, unsigned, for devices, Debug and Release. Lota's `check_app.rb` checks each built app's `Info.plist`: the name, character for character, the identifier, iPhone and iPad, the orientations, the status bar and the icon. Lota's `simulator.rb` then runs the app in an iPad Pro 13-inch, an iPad (A16), an iPad mini, an iPhone 17 Pro and an iPhone 16e: two launches that play No. 1720 to a win by themselves (`CROSS_EM_SCRIPT`), take screenshots and quit with status 0, and one launch with no settings. A launch fails on a crash, a Ruby `[BUG]`, a nonzero exit, or, for the scripted ones, no `screenshot … shot-2.png` line in the game's output. It uploads `ios-kit-simulator`, with Simulator screenshots, the game's log and its saves for every launch.
3. **Landscape, touch and rotation.** A third runner adds UI tests to a copy of the project. They turn each Simulator to landscape for the same launches. On the iPad Pro and the iPhone 17 Pro, they also tap known points in portrait, turn the device to landscape, tap again, and turn it back. In that copy only, the game also loads `ios/touch_probe.rb`, which prints where each touch landed in Lota's pixels. It uploads `ios-kit-touch`.

`ios/README.txt` is the kit's `README.txt`, Lota's `ipad/README.txt` changed to say where to download this repository's kit.

## What has been verified, and what hasn't

Verified:

- CI builds every platform's files from each push to `main`, and v0.2.1 was the first release made from a tag with all of them attached.
- `script/smoke.sh` reports `status 0` on the macOS, Windows and both Linux builds in CI.
- On Linux x86_64, CI also runs the packaged game for five seconds under Xvfb with Mesa's software OpenGL, and it quits on its own with status 0.
- On an Apple-silicon Mac, the fused macOS app opens its window, plays with sound, and quits cleanly. Fledge, the file system and the archive tools all cope with the curly apostrophe (U+2019) in the name.
- A fused macOS app that hung at launch with audio on was traced to a stuck macOS service (`com.apple.cmio.registerassistantservice`), not to the game: any app with a bundle identifier that opened CoreAudio hung the same way. Restarting the service (`sudo kill -9` on its process; macOS starts it again) fixed it.
- The iOS kit, in CI ([run 42105015578](https://github.com/Kerrick/cross_em/actions/runs/42105015578)): a fresh Mac with no Lota, Fledge or XcodeGen builds it for the Simulator and, unsigned, for devices. In the iOS 26.2 Simulator on an iPad Pro 13-inch, an iPad (A16), an iPad mini, an iPhone 17 Pro and an iPhone 16e, in portrait and in landscape, it plays No. 1720 to a win and quits with status 0, and runs idle without crashing. Its screenshots show the board laid out inside the safe area, clear of the Dynamic Island and the home indicator. With Lota's DPI scaling off, the UI test's taps reach the game at exactly the fractions of `Lota::Graphics.pixel_dimensions` they aimed at, in portrait and in landscape, and turning the device resizes the game.

Not verified:

- **Playing on a real PC.** Nobody has yet played a packaged build on Windows or Linux with a real graphics card and driver, real sound, or touch.
- **Linux on other distributions.** The AppImage was not tried on anything older than glibc 2.39.
- **Restarting.** `lota run` restarts a game that calls `Lota::Event.restart`; a fused app quits instead.
- **iPhone and iPad devices.** The iOS kit has only run in the iOS 26.2 Simulator. No one has yet signed it, installed it over a cable, or played it on a real iPhone or iPad, so its frame rate, sound, the silent switch and touch feel on a device are untested. The device build compiles and links, unsigned.
- **The iOS app icon for the App Store.** `icons/icon-1024.png` has an alpha channel, which Xcode accepts for a device build but the App Store refuses.
- **Signing.** The builds are unsigned, so SmartScreen and Gatekeeper warn about them, and the `.dmg` isn't notarized.
