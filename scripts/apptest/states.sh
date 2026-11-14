#!/usr/bin/env bash
# T23 and T22 (Toby 2): A99/A100 states, and EarMind on the icon and every scene (D179), through Angela's Debug scenes (AppTests/E2E/Screens/RepetitionStatesTests.swift):
# no BETA line for a new user, the used-up month, the length classes, "Ljudet kan inte göras just nu".
#
#   scripts/apptest/states.sh
#
# Output: apptest-out/states/t23-*.png, t23-states-log.txt, summary.md. Free: no network, no ElevenLabs (D180).
# Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/states"
DD="$ROOT/DerivedData-e2e"
mkdir -p "$OUT/logs"

echo "::group::Generate and build"
cp AppTests/E2E/project-e2e.yml ./project-e2e.yml
xcodegen generate --spec project-e2e.yml || exit 1
xcodebuild build-for-testing \
  -project LumenE2E.xcodeproj \
  -scheme LumenScreenTour \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/build-for-testing.log" 2>&1
BUILD=$?
tail -n 20 "$OUT/logs/build-for-testing.log"
echo "::endgroup::"
if [ $BUILD -ne 0 ]; then
  grep -E "error:" "$OUT/logs/build-for-testing.log" | head -n 40
  echo "::error::build-for-testing failed"
  exit 1
fi

JSON="$(xcrun simctl list devices available -j)"
RUNTIME="$(echo "$JSON" | jq -r '.devices | keys[] | select(test("iOS-26"))' | sort -V | tail -n 1)"
UDID="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" '.devices[$rt][] | select(.name | test("^iPhone 17 Pro$|^iPhone 17$")) | .udid' | head -n 1)"
test -n "$UDID" || { echo "::error::no iPhone 17 simulator"; exit 1; }
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true

echo "::group::States"
RESULT="$OUT/logs/states.xcresult"
rm -rf "$RESULT"
TEST_RUNNER_LUMEN_T23_STATES="1" \
xcodebuild test-without-building \
  -project LumenE2E.xcodeproj \
  -scheme LumenScreenTour \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DD" \
  -resultBundlePath "$RESULT" \
  -only-testing:"LumenScreenTour/RepetitionStatesTests" \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/test.log" 2>&1
STATUS=$?
grep -E "error:|failed|passed|skipped" "$OUT/logs/test.log" | tail -n 20
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT" || echo "::warning::attachment export failed"
python3 -I "$ROOT/scripts/apptest/screens_index.py" rename "$OUT"
echo "::endgroup::"

FENCE='```'
{
  echo "## T23 states (Debug scenes, simulator, inte enhet): $([ $STATUS -eq 0 ] && echo grön || echo röd)"
  echo
  echo "$FENCE"
  grep -E "^(OK |FEL)" "$OUT"/t23-states-log*.txt 2>/dev/null || echo "no T23 log"
  echo
  grep -E "^(icon|FEL)" "$OUT"/t22-name-log*.txt 2>/dev/null || echo "no T22 log"
  echo "$FENCE"
} > "$OUT/summary.md"
cat "$OUT/summary.md"
exit $STATUS
