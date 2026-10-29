#!/bin/bash
# Starts a game on this Mac with phones as controllers (the Mando NX app) over Wi-Fi. Double-click it in Finder, or run it from a terminal.
# The first phone to join is player 1 (the keyboard plays player 1 too); more phones are players 2, 3 and 4. The pairing QR opens with the game (Controllers > Phone Pairing QR…, ⌘J).
#   --build DIR     the game's <title ID>_build folder (default: the one scripts/build_host.sh saved)
#   --players N     highest player a phone may take (default 4; up to 8)
#   --keyboard-own  the keyboard is player 1 on its own, phones from player 2 on
#   --no-wifi       plain keyboard / controller run, no network socket
#   --new-code      make a new pairing code (phones must type or scan it again)
#   --lang CODE     game language (default en-US; e.g. es, es-419)
# Keyboard keys: Controllers > Keyboard Controls (⌘K) in the game window; saved in ~/Library/Application Support/nxnative/keyboard.txt.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
fail() { echo "[RED] $*" >&2; echo; read -r -p "Press Return to close." _ || true; exit 1; }
PORT="${DM_REMOTE_PORT:-47800}"
BUILD=""; PLAYERS=4; WIFI=1; NEWCODE=0; KBD_OWN=0; GAME_LANG="${GAME_LANG:-en-US}"
while [ $# -gt 0 ]; do
    case "$1" in
        --build) BUILD="${2:?--build needs a folder}"; shift 2 ;;
        --players) PLAYERS="${2:?--players needs a number}"; shift 2 ;;
        --keyboard-own) KBD_OWN=1; shift ;;
        --no-wifi) WIFI=0; shift ;;
        --new-code) NEWCODE=1; shift ;;
        --lang) GAME_LANG="${2:?--lang needs a code}"; shift 2 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) fail "unknown option: $1 (see --help)" ;;
    esac
done
case "$PLAYERS" in [1-8]) ;; *) fail "--players must be 1 to 8" ;; esac

W="$( (build_dir "$BUILD") 2>&1)" || fail "$W"
INFO="$( (build_info "$W") 2>&1)" || fail "$INFO"
build_info "$W"; W="$B_DIR"
HOST="$W/tools/dmhost-wifi"
[ -x "$HOST" ] || fail "no Wi-Fi host at $HOST: run scripts/build_host.sh --build \"$W\""
for f in "$W/shader/cache" "$W/font"; do [ -e "$f" ] || fail "missing $f (pack the game again with nxnative's scripts/build_ipa_from_nsp.py)"; done
if pgrep -f "$W/tools/dmhost" >/dev/null 2>&1; then fail "the game is already running (close its window first); this launcher does not stop it"; fi
NAME="$(awk -F'\t' '$1 == "name" { print $2; exit }' "$W/profile/$B_ID/game.tsv" 2>/dev/null)"; NAME="${NAME:-$B_ID}"

CFG="$HOME/Library/Application Support/nxnative"; mkdir -p "$CFG"
CODE_FILE="$CFG/wifi_pair_code"
if [ "$WIFI" = 1 ]; then
    if [ "$NEWCODE" = 1 ] || ! grep -Eq '^[0-9A-Za-z]{4,32}$' "$CODE_FILE" 2>/dev/null; then
        (umask 077; python3 -c 'import secrets; print(f"{secrets.randbelow(10**6):06d}")' > "$CODE_FILE")
    fi
    CODE="$(cat "$CODE_FILE")"
    IPS="$(ifconfig | awk '/^[a-z]/{i=$1} /inet / && $2 != "127.0.0.1" && $2 !~ /^169\.254\./ {sub(":","",i); print $2 "  (" i ")"}')"
    echo
    echo "=========  $NAME - Wi-Fi controllers  ========="
    if [ "$KBD_OWN" = 1 ]; then echo " Players: keyboard = player 1, phones = players 2 to $PLAYERS"
    else echo " Players: first phone = player 1 (the keyboard plays player 1 too), more phones = players 2 to $PLAYERS"; fi
    echo
    echo " In the Mando NX app: scan the QR the game shows, or type"
    echo "   IP del Mac : $(echo "$IPS" | head -1 | awk '{print $1}')"
    [ "$(echo "$IPS" | wc -l)" -gt 1 ] && echo "$IPS" | tail -n +2 | sed 's/^/                (or) /'
    echo "   Puerto     : $PORT"
    echo "   Codigo     : $CODE"
    echo
    echo " The phone and this Mac must be on the same network. If macOS asks whether"
    echo " dmhost-wifi may accept incoming network connections, choose Allow."
    if /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall 2>/dev/null | grep -qi "enabled"; then
        echo " [RED] The macOS firewall blocks all incoming connections: phones cannot connect"
        echo "       (System Settings > Network > Firewall > Options)."
    fi
    echo " The same code stays valid for the next runs (--new-code makes a new one)."
    echo " Close the QR window to give the game the controls back."
    echo "=============================================="
    echo
fi

LOG="$W/run/gameplay_wifi.log"
mkdir -p "$W/run/save" "$W/run/temp"
cd "$W/run"
export DM_ROOT="$W" DM_ROMFS="$W/extract/v$B_VER/RomFS.img" DM_SAVE="$W/run/save" DM_TEMP="$W/run/temp" DM_MSL_DIR="$W/shader/cache" DM_FONT_DIR="$W/font"
export DM_LANG="$GAME_LANG" DM_WINDOW=1 DM_AUDIO=1
[ -d "$W/aoc" ] && export DM_AOC_DIR="$W/aoc"
[ -f "$W/profile/$B_ID/shader_map.tsv" ] && export DM_NVN_SHMAP="$W/profile/$B_ID/shader_map.tsv"
if [ "$WIFI" = 1 ]; then
    if [ "$KBD_OWN" = 1 ]; then export DM_KBD_PLAYER=own; fi
    export DM_REMOTE=1 DM_REMOTE_QR=1 DM_REMOTE_PORT="$PORT" DM_REMOTE_CODE="$CODE" DM_REMOTE_PLAYERS="$PLAYERS"
fi
echo "Starting $NAME (log: $LOG) ..."
set +e
"$HOST" "$W/patched_v$B_VER" > "$LOG" 2>&1
rc=$?
set -e
echo "The game exited ($rc). Log: $LOG"
grep -E "Wi-Fi|\[RED\]" "$LOG" | tail -15 || true
exit $rc
