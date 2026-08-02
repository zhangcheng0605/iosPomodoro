#!/bin/bash
#
# Build Pawmodoro and run it in an iOS Simulator. macOS with Xcode only.
#
#   tools/run-sim.sh                          build, install, launch
#   tools/run-sim.sh --demo                   ... with fast timers, no onboarding,
#                                             and no notification alert
#   tools/run-sim.sh --device "iPhone 16"     pick the simulator by name
#   tools/run-sim.sh --headless               don't open Apple's Simulator app
#   tools/run-sim.sh --demo -PawmodoroSeedStats
#
# Anything starting with "-Pawmodoro" is passed straight to the app as a launch
# argument; see docs/SIMULATOR.md for the full list.
#
# With no --device, an already-booted simulator wins, so this attaches to
# whatever device is showing in Claude Code Desktop's iOS Simulator pane.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="Pawmodoro.xcodeproj"
SCHEME="Pawmodoro"
# Must match PRODUCT_BUNDLE_IDENTIFIER in the project.
BUNDLE_ID="com.zhangcheng.pawmodoro"
DERIVED_DATA="build/simulator"

DEVICE_NAME=""
OPEN_SIMULATOR_APP=1
APP_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --demo)     APP_ARGS+=("-PawmodoroDemo"); shift ;;
        --device)   DEVICE_NAME="${2:-}"; shift 2 ;;
        --headless) OPEN_SIMULATOR_APP=0; shift ;;
        -h|--help)  sed -n '3,16p' "$0" | sed 's/^#[ ]\{0,1\}//'; exit 0 ;;
        *)          APP_ARGS+=("$1"); shift ;;
    esac
done

UDID_PATTERN='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'

first_udid() {
    grep -Eo "$UDID_PATTERN" | head -1
}

if [ -n "$DEVICE_NAME" ]; then
    UDID=$(xcrun simctl list devices available | grep -F -- "$DEVICE_NAME (" | first_udid || true)
    if [ -z "$UDID" ]; then
        echo "No available simulator named '$DEVICE_NAME'. Installed devices:" >&2
        xcrun simctl list devices available >&2
        exit 1
    fi
else
    # An already-booted device first, so this attaches to the simulator that is
    # already on screen rather than starting a second one.
    UDID=$(xcrun simctl list devices booted | first_udid || true)
    if [ -z "$UDID" ]; then
        UDID=$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone' | tail -1 | first_udid || true)
    fi
    if [ -z "$UDID" ]; then
        echo "No iPhone simulators are installed. Run: xcodebuild -downloadPlatform iOS" >&2
        exit 1
    fi
fi

echo "==> Simulator $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

if [ "$OPEN_SIMULATOR_APP" -eq 1 ]; then
    open -a Simulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null || true
fi

echo "==> Building $SCHEME (Debug)"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=$UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$SCHEME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Build finished but $APP_PATH is missing." >&2
    exit 1
fi

echo "==> Installing"
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

echo "==> Launching ${APP_ARGS[*]:-}"
xcrun simctl launch "$UDID" "$BUNDLE_ID" ${APP_ARGS[@]+"${APP_ARGS[@]}"}

cat <<EOF

Running. Useful follow-ups:
  xcrun simctl io $UDID screenshot /tmp/pawmodoro.png
  xcrun simctl spawn $UDID log stream --predicate 'process == "Pawmodoro"'
  xcrun simctl terminate $UDID $BUNDLE_ID
EOF
