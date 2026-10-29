# Shared by the scripts in this folder (sourced, not run): where things are, the pinned nxnative commit, the saved settings, and how to read a game's build folder
# (the <title ID>_build folder that nxnative's scripts/build_ipa_from_nsp.py makes beside the game's NSPs).
MANDO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NX_URL="https://github.com/seedds/nxnative.git"
NX_COMMIT="$(tr -d ' \n' < "$MANDO_ROOT/host/NXNATIVE_COMMIT")"
NX_PATCH="$MANDO_ROOT/host/nxnative.patch"
MANDO_CFG_DIR="$HOME/Library/Application Support/mando-nx"
MANDO_CFG="$MANDO_CFG_DIR/config"   # NXNATIVE_DIR=… and BUILD_DIR=…, written by setup_nxnative.sh and build_host.sh

die() { echo "[RED] $*" >&2; exit 1; }
say() { echo "==> $*"; }

cfg_get() { [ -f "$MANDO_CFG" ] && sed -n "s/^$1=//p" "$MANDO_CFG" | tail -1; }
cfg_set() {   # cfg_set KEY VALUE
    mkdir -p "$MANDO_CFG_DIR"
    { [ -f "$MANDO_CFG" ] && grep -v "^$1=" "$MANDO_CFG"; echo "$1=$2"; } > "$MANDO_CFG.tmp" && mv "$MANDO_CFG.tmp" "$MANDO_CFG"
}

# The nxnative checkout: the given one, else NXNATIVE_DIR, else the saved one, else nxnative beside this repository
nx_dir() {
    local d="${1:-${NXNATIVE_DIR:-$(cfg_get NXNATIVE_DIR)}}"
    [ -n "$d" ] || d="$(dirname "$MANDO_ROOT")/nxnative"
    echo "$d"
}
nx_patched() { [ -f "$1/dm/host/remote_mac.c" ] && [ -f "$1/dm/host/remote_proto.h" ]; }   # the patch is in that checkout

# A game's build folder: sets B_ID (title ID), B_VER (the newest version with both its rewritten code and its RomFS), B_DIR
build_info() {
    B_DIR="$(cd "$1" 2>/dev/null && pwd)" || die "no folder $1"
    [ -d "$B_DIR/profile" ] || die "$B_DIR is not a game build folder (no profile/): run nxnative's scripts/build_ipa_from_nsp.py on the game's NSP folder first"
    local ids=(); for p in "$B_DIR"/profile/*/; do [ -d "$p" ] && ids+=("$(basename "$p")"); done
    [ ${#ids[@]} = 1 ] || die "$B_DIR/profile has ${#ids[@]} game profiles; expected one"
    B_ID="${ids[0]}"
    B_VER=""
    for p in "$B_DIR"/patched_v*/; do
        local v="${p%/}"; v="${v##*/patched_v}"
        [[ "$v" =~ ^[0-9]+$ ]] && [ -f "$B_DIR/extract/v$v/RomFS.img" ] || continue
        if [ -z "$B_VER" ] || [ "$v" -gt "$B_VER" ]; then B_VER="$v"; fi
    done
    [ -n "$B_VER" ] || die "$B_DIR has no patched_v<version> with its extract/v<version>/RomFS.img"
}

# The build folder for the launcher: the given one, else MANDO_BUILD, else the saved one, else a single *_build folder beside the script
build_dir() {
    local d="${1:-${MANDO_BUILD:-$(cfg_get BUILD_DIR)}}"
    if [ -z "$d" ]; then
        local found=(); for p in "$MANDO_ROOT"/../*_build/; do [ -d "$p/profile" ] && found+=("$p"); done
        [ ${#found[@]} = 1 ] && d="${found[0]}"
    fi
    [ -n "$d" ] || die "which game? Pass --build <the game's <title ID>_build folder> once (scripts/build_host.sh saves it)"
    echo "$d"
}
