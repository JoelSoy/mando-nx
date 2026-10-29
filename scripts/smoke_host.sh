#!/bin/bash
# Checks the built Wi-Fi host with the real game and no phone: starts tools/dmhost-wifi headless (no window, no sound) in a scratch run folder with a copy of the save,
# the receiver on loopback only, joins three fake phones (nxnative's dm/tools/remote_phone.py) for 20 s and one with a wrong code, then stops the host it started.
#   scripts/smoke_host.sh [--build <the game's <title ID>_build folder>] [--nxnative <folder>]
# Passes when every phone got a player, acks and an info message, and the wrong code was refused. Logs in <build>/logs/mando-smoke-*.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
BUILD=""; NX=""
while [ $# -gt 0 ]; do
    case "$1" in
        --build) BUILD="${2:?}"; shift 2 ;;
        --nxnative) NX="${2:?}"; shift 2 ;;
        -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
        *) die "unknown option $1 (see --help)" ;;
    esac
done
NX="$(nx_dir "$NX")"; PHONE="$NX/dm/tools/remote_phone.py"
[ -f "$PHONE" ] || die "no $PHONE: run scripts/setup_nxnative.sh first"
D="$(build_dir "$BUILD")" || exit 1; build_info "$D"; W="$B_DIR"; HOST="$W/tools/dmhost-wifi"
[ -x "$HOST" ] || die "no $HOST: run scripts/build_host.sh"
pgrep -f "$W/tools/dmhost" >/dev/null 2>&1 && die "the game is running: close it first"
L="$W/logs"; S="$(mktemp -d -t mando-smoke)"; mkdir -p "$L" "$S/temp"
[ -d "$W/run/save" ] && cp -R "$W/run/save" "$S/save" || mkdir -p "$S/save"
CODE=$(python3 -c 'import secrets; print(f"{secrets.randbelow(10**6):06d}")'); PORT=47899
EXTRA=(); [ -d "$W/aoc" ] && EXTRA+=(DM_AOC_DIR="$W/aoc"); [ -f "$W/profile/$B_ID/shader_map.tsv" ] && EXTRA+=(DM_NVN_SHMAP="$W/profile/$B_ID/shader_map.tsv")
cd "$S"
env DM_ROOT="$W" DM_ROMFS="$W/extract/v$B_VER/RomFS.img" DM_SAVE="$S/save" DM_TEMP="$S/temp" DM_MSL_DIR="$W/shader/cache" DM_FONT_DIR="$W/font" "${EXTRA[@]}" \
    DM_LANG=en-US DM_PSO_ARCHIVE=off DM_PSO_PREBUILD=0 DM_PSO_USER="$S/pso_user.tsv" \
    DM_REMOTE=1 DM_REMOTE_BIND=127.0.0.1 DM_REMOTE_PORT=$PORT DM_REMOTE_CODE="$CODE" DM_REMOTE_PLAYERS=4 \
    "$HOST" "$W/patched_v$B_VER" > "$L/mando-smoke-host.log" 2>&1 &
PID=$!
for i in $(seq 1 120); do grep -q "Wi-Fi controllers on" "$L/mando-smoke-host.log" && break; kill -0 $PID 2>/dev/null || break; sleep 0.5; done
if ! grep -q "Wi-Fi controllers on" "$L/mando-smoke-host.log"; then kill $PID 2>/dev/null; tail -20 "$L/mando-smoke-host.log"; rm -rf "$S"; die "the host did not start the receiver"; fi
sleep 8   # let the game reach its controller setup
python3 -I "$PHONE" --code "$CODE" --port $PORT --phones 3 --seconds 20 > "$L/mando-smoke-phones.jsonl"; PRC=$?
python3 -I "$PHONE" --code 000000 --port $PORT --phones 1 --seconds 2 > "$L/mando-smoke-wrongcode.jsonl"; WRC=$?
sleep 1
kill -TERM $PID 2>/dev/null; for i in $(seq 1 20); do kill -0 $PID 2>/dev/null || break; sleep 0.25; done; kill -KILL $PID 2>/dev/null; wait $PID 2>/dev/null
rm -rf "$S"
INFOS=$(grep -c '"ev": "info"' "$L/mando-smoke-phones.jsonl")
grep -E '"ev": "(info|done)"' "$L/mando-smoke-phones.jsonl"; grep reject "$L/mando-smoke-wrongcode.jsonl"
grep -E "Wi-Fi controller|hid supported" "$L/mando-smoke-host.log" | head -10
echo "phones rc=$PRC (0: every phone had a player and acks), info messages=$INFOS (3 or more), wrong code rc=$WRC (1 expected)"
[ $PRC = 0 ] && [ "$INFOS" -ge 3 ] && [ $WRC = 1 ] && say "smoke passed"
