#!/bin/bash
# The checks to run before committing: the app (flutter analyze, flutter test) and, when an nxnative checkout with the patch is there, the host's Wi-Fi and keyboard
# tests (protocol and sessions, real UDP on loopback through hle_hid.c) and that host/nxnative.patch still applies to the pinned commit.
#   scripts/check.sh [--nxnative <folder>] [--game <title ID>] [--app-only]
set -euo pipefail
source "$(dirname "$0")/lib.sh"
NX=""; GAME=""; APP_ONLY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --nxnative) NX="${2:?}"; shift 2 ;;
        --game) GAME="${2:?}"; shift 2 ;;
        --app-only) APP_ONLY=1; shift ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        *) die "unknown option $1 (see --help)" ;;
    esac
done
say "app: flutter analyze, flutter test"
(cd "$MANDO_ROOT/app" && flutter pub get >/dev/null && flutter analyze && flutter test)
[ "$APP_ONLY" = 1 ] && exit 0

T="$(mktemp -d -t mando-check)"; trap 'rm -rf "$T"' EXIT
NX="$(nx_dir "$NX")"
if [ -d "$NX/.git" ] && git -C "$NX" cat-file -e "$NX_COMMIT^{commit}" 2>/dev/null; then
    say "the patch applies to nxnative $NX_COMMIT"
    git -C "$NX" archive "$NX_COMMIT" | tar -x -C "$T"
    git -C "$T" init -q && git -C "$T" apply --check "$NX_PATCH"
else
    echo "skipped: the patch check needs an nxnative checkout that has $NX_COMMIT"
fi
if nx_patched "$NX"; then
    [ -n "$GAME" ] || { B="$(cfg_get BUILD_DIR)"; [ -n "$B" ] && [ -d "$B/profile" ] && GAME="$(ls "$B/profile" | head -1)"; }
    GAME="${GAME:-0100152000022000}"
    say "host tests (GAME=$GAME)"
    make -C "$NX/dm/host/tests" GAME="$GAME" remote
else
    echo "skipped: host tests (no patched nxnative at $NX: scripts/setup_nxnative.sh)"
fi
say "all checks passed"
