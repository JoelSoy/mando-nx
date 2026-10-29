#!/bin/bash
# Builds nxnative's Mac host with the Wi-Fi controllers for one game and puts it in that game's build folder as tools/dmhost-wifi (the build's own tools/dmhost is not touched;
# the previous dmhost-wifi is kept as dmhost-wifi.prev).
#   scripts/build_host.sh --build <the game's <title ID>_build folder> [--nxnative <folder>] [--test]
#   --test   also runs the host's Wi-Fi and keyboard tests (make -C dm/host/tests remote)
# The build folder is saved, so play_wifi.command finds the game without options.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
BUILD=""; NX=""; TEST=0
while [ $# -gt 0 ]; do
    case "$1" in
        --build) BUILD="${2:?--build needs a folder}"; shift 2 ;;
        --nxnative) NX="${2:?--nxnative needs a folder}"; shift 2 ;;
        --test) TEST=1; shift ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) die "unknown option $1 (see --help)" ;;
    esac
done
NX="$(nx_dir "$NX")"
nx_patched "$NX" || die "$NX has no Wi-Fi host: run scripts/setup_nxnative.sh first"
D="$(build_dir "$BUILD")" || exit 1; build_info "$D"
say "game $B_ID, version $B_VER, build folder $B_DIR"

OUT="$B_DIR/tools/dmhost-wifi"
if pgrep -f "$OUT" >/dev/null 2>&1; then die "the game is running from $OUT: close it first (replacing a running program can crash it)"; fi
LOG="$B_DIR/logs/mando-host-build.log"; mkdir -p "$B_DIR/logs" "$B_DIR/tools"
say "compiling the host (log: $LOG)"
if ! make -C "$NX/dm/host" GAME="$B_ID" dmhost > "$LOG" 2>&1; then tail -20 "$LOG"; die "the host did not build (log: $LOG)"; fi
[ -f "$OUT" ] && cp -p "$OUT" "$OUT.prev"
cp -p "$NX/dm/host/dmhost" "$OUT"
if [ -d "$NX/dm/host/dmhost.dSYM" ]; then rm -rf "$OUT.dSYM"; cp -R "$NX/dm/host/dmhost.dSYM" "$OUT.dSYM"; fi
say "built $OUT"

if [ "$TEST" = 1 ]; then
    say "host tests"
    make -C "$NX/dm/host/tests" GAME="$B_ID" remote
fi
cfg_set BUILD_DIR "$B_DIR"
echo "Start the game with: $MANDO_ROOT/scripts/play_wifi.command"
