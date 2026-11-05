#!/usr/bin/env bash
# Checks a fused build of Cross ’em without opening a window (CI runners
# have no GPU): unpacks the build's archive from the folder `lota fuse`
# wrote, finds the Ruby that ships inside the app, and runs the game's own
# launcher, bin/cross_em, with it in smoke mode (CROSS_EM_SMOKE). The
# launcher loads Lota, conf.rb and main.rb and everything they require,
# from the packaged copy of the game, so a file that did not ship fails.
#
# `lota fuse` makes the app's own program a small main.rb of Lota's, which
# does not know CROSS_EM_SMOKE, so the packaged Ruby runs the launcher.
#
#   script/smoke.sh dist [work-dir]
#
# Works on macOS and Linux (the .tar.gz) and on Windows, in Git Bash (the
# .zip). Exits 0 when the report says "status 0", 1 otherwise.

set -euo pipefail

dist="${1:?usage: script/smoke.sh DIST_DIR [WORK_DIR]}"
work="${2:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/cross-em-smoke}"
rm -rf "$work"
mkdir -p "$work/unpacked"

archive=$(find "$dist" -maxdepth 1 \( -name '*.tar.gz' -o -name '*.zip' \) | head -1)
[ -n "$archive" ] || { echo "no .tar.gz or .zip in $dist"; exit 1; }
echo "unpacking $archive"
case "$archive" in
  *.tar.gz) tar -xzf "$archive" -C "$work/unpacked" ;;
  # The paths reach PowerShell through the environment, never as quoted
  # literals: PowerShell counts the ’ in "Cross ’em" as a quote mark.
  *.zip) SMOKE_ZIP=$(cygpath -w "$archive") SMOKE_TO=$(cygpath -w "$work/unpacked") \
           powershell -NoProfile -Command 'Expand-Archive -LiteralPath $env:SMOKE_ZIP -DestinationPath $env:SMOKE_TO' ;;
esac

launcher=$(find "$work/unpacked" -path '*/game/*/bin/cross_em' -type f | head -1)
[ -n "$launcher" ] || { echo "bin/cross_em did not ship"; find "$work/unpacked" -maxdepth 4 | head -50; exit 1; }
ruby_bin=$(find "$work/unpacked" -type f \( -name ruby -o -name ruby.exe \) -path '*/bin/*' | head -1)
[ -n "$ruby_bin" ] || { echo "the app has no Ruby of its own"; find "$work/unpacked" -maxdepth 4 | head -50; exit 1; }
echo "launcher: $launcher"
echo "ruby:     $ruby_bin"

report="$work/report.txt"
rm -f "$report"
status=0
# Only the system's own folders on PATH, so a Ruby on the runner cannot help.
if [ "${OS:-}" = Windows_NT ]; then
  CROSS_EM_SMOKE="$(cygpath -w "$report")" "$ruby_bin" "$(cygpath -w "$launcher")" || status=$?
else
  env -i HOME="$HOME" PATH=/usr/bin:/bin CROSS_EM_SMOKE="$report" "$ruby_bin" "$launcher" || status=$?
fi
echo "--- launcher exited $status; its report:"
cat "$report" || { echo "(none)"; exit 1; }
[ "$status" -eq 0 ] && grep -q '^status 0$' "$report" && grep -q '^lota 0\.' "$report"
