#!/bin/bash
# Writes host/nxnative.patch from an nxnative checkout: everything that differs from the pinned commit (host/NXNATIVE_COMMIT), committed or not, plus new files, except the
# app link (dm/remote_pad), local notes and game folders. Also refreshes docs/protocol.md from nxnative's docs/wifi-controllers.md. Run it after changing host code there.
#   scripts/export_patch.sh [--nxnative <folder>] [--commit <nxnative commit the patch is for>]
# Only source and docs paths go in (dm/, docs/, scripts/, README.md, CONTRIBUTING.md, AGENTS.md); anything else, or any file over 1 MB, stops the script, so game files,
# keys or dumps never reach this repository.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
NX=""; COMMIT="$NX_COMMIT"
while [ $# -gt 0 ]; do
    case "$1" in
        --nxnative) NX="${2:?}"; shift 2 ;;
        --commit) COMMIT="${2:?}"; shift 2 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) die "unknown option $1 (see --help)" ;;
    esac
done
NX="$(cd "$(nx_dir "$NX")" && pwd)"
nx_patched "$NX" || die "$NX has no Wi-Fi host files"
COMMIT="$(git -C "$NX" rev-parse "$COMMIT^{commit}")"
T="$(mktemp -d -t mando-patch)"; trap 'rm -rf "$T"' EXIT
LIST="$T/files.txt"
{ git -C "$NX" diff --name-only "$COMMIT"; git -C "$NX" ls-files --others --exclude-standard; } | sort -u \
    | grep -v -E '^(dm/remote_pad(/|$)|docs/controller-progress\.md$|mariokart/)' > "$LIST" || true
[ -s "$LIST" ] || die "no changes from $COMMIT in $NX"
while read -r f; do
    [[ "$f" =~ ^(dm/|docs/|scripts/|README\.md$|CONTRIBUTING\.md$|AGENTS\.md$) ]] || die "refusing $f: not a source or docs path (move it out of the nxnative tree, or extend the list in this script on purpose)"
    if [ -f "$NX/$f" ] && [ "$(stat -f %z "$NX/$f")" -gt 1048576 ]; then die "refusing $f: over 1 MB"; fi
done < "$LIST"

mkdir "$T/tree"; git -C "$NX" archive "$COMMIT" | tar -x -C "$T/tree"
cd "$T/tree"; git init -q; git add -A; git -c user.name=x -c user.email=x@x commit -qm base
while read -r f; do
    if [ -e "$NX/$f" ]; then mkdir -p "$(dirname "$f")"; cp -p "$NX/$f" "$f"; else rm -f "$f"; fi   # a file deleted in the checkout is deleted in the patch
done < "$LIST"
git add -A
git diff --cached --binary > "$NX_PATCH"
echo "$COMMIT" > "$MANDO_ROOT/host/NXNATIVE_COMMIT"
[ -f "$NX/docs/wifi-controllers.md" ] && cp "$NX/docs/wifi-controllers.md" "$MANDO_ROOT/docs/protocol.md"
say "wrote host/nxnative.patch ($(git diff --cached --name-only | wc -l | tr -d ' ') files, for nxnative ${COMMIT:0:7}) and docs/protocol.md"
