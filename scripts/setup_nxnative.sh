#!/bin/bash
# Gets nxnative (https://github.com/seedds/nxnative) at the commit this repository is tested on, applies the host patch (Wi-Fi controllers, QR pairing, game rumble and
# game info for phones, the Mac keyboard map) and links the phone app into it as dm/remote_pad, where nxnative's docs and tests expect it.
#   scripts/setup_nxnative.sh [--dir <nxnative folder>]   (default: NXNATIVE_DIR, the saved one, or ../nxnative beside this repository)
# A new folder is cloned and gets a branch "mando-nx" at the pinned commit. An existing checkout is never reset: if it is on another commit and the patch does not apply,
# the script stops and says what to do.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DIR="${2:?--dir needs a folder}"; shift 2 ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) die "unknown option $1 (see --help)" ;;
    esac
done
DIR="$(nx_dir "$DIR")"
command -v git >/dev/null || die "git is missing (xcode-select --install)"

if [ ! -e "$DIR" ]; then
    say "cloning nxnative into $DIR"
    git clone "$NX_URL" "$DIR"
    git -C "$DIR" switch -c mando-nx "$NX_COMMIT"
fi
[ -d "$DIR/.git" ] && [ -f "$DIR/dm/host/Makefile" ] || die "$DIR is not an nxnative checkout"
DIR="$(cd "$DIR" && pwd)"

if nx_patched "$DIR" && git -C "$DIR" apply --reverse --check "$NX_PATCH" 2>/dev/null; then
    say "the host patch is already applied in $DIR"
elif nx_patched "$DIR"; then
    say "$DIR already has the Wi-Fi host files, but not exactly this patch (an older or edited version): left as it is"
else
    git -C "$DIR" cat-file -e "$NX_COMMIT^{commit}" 2>/dev/null || git -C "$DIR" fetch -q origin || true
    if ! git -C "$DIR" apply --check "$NX_PATCH" 2>/dev/null; then
        die "the patch does not apply on $DIR ($(git -C "$DIR" rev-parse --short HEAD)); it is made for nxnative $NX_COMMIT. Either: git -C \"$DIR\" switch -c mando-nx $NX_COMMIT (with a clean tree), or port the patch (AGENTS.md, \"Moving to a newer nxnative\")"
    fi
    git -C "$DIR" apply "$NX_PATCH"
    say "host patch applied in $DIR"
fi

APP="$DIR/dm/remote_pad"
if [ -L "$APP" ] && [ "$(cd "$APP" && pwd -P)" = "$(cd "$MANDO_ROOT/app" && pwd -P)" ]; then :
elif [ -e "$APP" ]; then
    echo "note: $APP exists and is not a link to $MANDO_ROOT/app; nxnative's docs and tests use that folder, this repository's app is $MANDO_ROOT/app"
else
    ln -s "$MANDO_ROOT/app" "$APP"; say "linked $APP -> $MANDO_ROOT/app"
fi
cfg_set NXNATIVE_DIR "$DIR"

cat <<EOF

nxnative is ready in $DIR (saved for the other scripts).
Next, once per Mac (nxnative README, step 1):
  xcodebuild -downloadComponent MetalToolchain
  brew install xcodegen zstd glslang && brew install --cask dotnet-sdk
  python3 -m pip install lz4 capstone fonttools "backports.zstd; python_version < '3.14'"
Then pack your game once (your own NSPs and prod.keys; the files stay in the game's folder):
  python3 "$DIR/scripts/build_ipa_from_nsp.py" ~/Games/MarioKart -k ~/keys/prod.keys
and build the Wi-Fi host for it:
  "$MANDO_ROOT/scripts/build_host.sh" --build ~/Games/MarioKart/<title ID>_build
EOF
