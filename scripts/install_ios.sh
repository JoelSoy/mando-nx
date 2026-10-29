#!/bin/bash
# Builds the Mando NX app for an iPhone or iPad, signed with your own Apple team, installs it on the connected device and opens it.
#   scripts/install_ios.sh [--team <team ID>] [--bundle-id <ID>] [--device <UDID>] [--no-launch]
# The team and bundle ID go into app/ios/Flutter/Signing.xcconfig (git ignores it) and are reused next time. Without --team on the first run, the team of your
# "Apple Development" certificate is used (Xcode > Settings > Accounts makes one when you sign in). A free Apple account's install works for 7 days: run this again then.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
TEAM=""; BUNDLE=""; DEVICE=""; LAUNCH=1
while [ $# -gt 0 ]; do
    case "$1" in
        --team) TEAM="${2:?--team needs an ID}"; shift 2 ;;
        --bundle-id) BUNDLE="${2:?--bundle-id needs an ID}"; shift 2 ;;
        --device) DEVICE="${2:?--device needs a UDID}"; shift 2 ;;
        --no-launch) LAUNCH=0; shift ;;
        -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
        *) die "unknown option $1 (see --help)" ;;
    esac
done
command -v flutter >/dev/null || die "Flutter is missing: brew install --cask flutter (or https://docs.flutter.dev/get-started/install/macos)"
APP="$MANDO_ROOT/app"; SIGN="$APP/ios/Flutter/Signing.xcconfig"

if [ -z "$TEAM" ] && ! grep -q '^DEVELOPMENT_TEAM *= *[A-Z0-9]\{10\}' "$SIGN" 2>/dev/null; then
    TEAM="$(security find-certificate -a -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject -nameopt multiline 2>/dev/null | awk '/organizationalUnitName/ { print $3; exit }')"
    [ -n "$TEAM" ] || die "no Apple team found: sign in with your Apple ID in Xcode > Settings > Accounts, or pass --team <team ID>"
    say "using the team of your Apple Development certificate: $TEAM"
fi
if [ -n "$TEAM" ] || [ -n "$BUNDLE" ]; then
    [ -z "$TEAM" ] && TEAM="$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' "$SIGN" 2>/dev/null)"
    [ -z "$BUNDLE" ] && BUNDLE="$(sed -n 's/^PRODUCT_BUNDLE_IDENTIFIER *= *//p' "$SIGN" 2>/dev/null)"
    { echo "// Your signing for Mando NX (scripts/install_ios.sh); not committed."
      echo "DEVELOPMENT_TEAM = $TEAM"
      [ -n "$BUNDLE" ] && echo "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE"; } > "$SIGN"
fi

if [ -z "$DEVICE" ]; then
    J="$(mktemp -t mando-devices)"; trap 'rm -f "$J"' EXIT
    xcrun devicectl list devices --json-output "$J" >/dev/null 2>&1 || die "xcrun devicectl failed (Xcode 15 or later is needed)"
    DEVICE="$(python3 -I -c '
import json, sys
devs = json.load(open(sys.argv[1]))["result"]["devices"]
ok = [d for d in devs if d.get("hardwareProperties", {}).get("reality") == "physical" and d.get("hardwareProperties", {}).get("platform") == "iOS"
      and d.get("connectionProperties", {}).get("pairingState") == "paired"]
print(ok[0]["hardwareProperties"]["udid"] if ok else "")' "$J")"
    [ -n "$DEVICE" ] || die "no paired iPhone or iPad: connect it with a cable, unlock it, tap Trust, and turn on Developer Mode (Settings > Privacy & Security)"
fi
say "device $DEVICE"

cd "$APP"
flutter pub get >/dev/null
say "building (release)"
flutter build ios --release
say "installing"
xcrun devicectl device install app --device "$DEVICE" build/ios/iphoneos/Runner.app
if [ "$LAUNCH" = 1 ]; then
    xcrun devicectl device process launch --device "$DEVICE" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' build/ios/iphoneos/Runner.app/Info.plist)" \
        || echo "Installed, but iOS did not open it: on the phone, Settings > General > VPN & Device Management > trust your developer account, then open Mando NX."
fi
say "done. The first time, allow Local Network (and the camera for the QR) when the app asks."
