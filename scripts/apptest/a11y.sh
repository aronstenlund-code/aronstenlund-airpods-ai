#!/usr/bin/env bash
# For Angela Fable's A95: XCTest's accessibility audit on each Debug scene (`-LumenScreenshot <scene>`), plus the
# accessibility tree, per scene (AppTests/E2E/Screens/AccessibilityAuditTests.swift). Findings never fail the run.
#
#   A11Y_DEVICE="iPhone SE (3rd generation)" A11Y_TEXT_SIZE=accessibility-extra-extra-extra-large \
#   A11Y_SCENES="fsWelcome repList" scripts/apptest/a11y.sh
#
# Output: apptest-out/a11y/<config>/a11y-<scene>.audit.txt, .tree.txt, .png and summary.md. Light mode. Free (no
# network). Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
DEVICE="${A11Y_DEVICE:-iPhone 17 Pro}"
SIZE="${A11Y_TEXT_SIZE:-default}"
SCENES="${A11Y_SCENES:?set A11Y_SCENES}"
CONFIG="$(echo "$DEVICE-$SIZE" | tr ' ()' '---' | tr -s '-')"
OUT="$ROOT/apptest-out/a11y/$CONFIG"
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

echo "::group::Simulator $DEVICE, text $SIZE"
JSON="$(xcrun simctl list devices available -j)"
RUNTIME="$(echo "$JSON" | jq -r '.devices | keys[] | select(test("iOS-26"))' | sort -V | tail -n 1)"
UDID="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" --arg want "$DEVICE" '.devices[$rt][] | select(.name == $want) | .udid' | head -n 1)"
if [ -z "$UDID" ]; then
  TYPE="$(xcrun simctl list devicetypes -j | jq -r --arg want "$DEVICE" '.devicetypes[] | select(.name == $want) | .identifier' | head -n 1)"
  if [ -n "$TYPE" ]; then UDID="$(xcrun simctl create "$DEVICE" "$TYPE" "$RUNTIME")"; fi
fi
test -n "$UDID" || { echo "::error::no simulator '$DEVICE'"; exit 1; }
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
if [ "$SIZE" != "default" ]; then xcrun simctl ui "$UDID" content_size "$SIZE"; fi
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true
echo "::endgroup::"

echo "::group::Audit"
RESULT="$OUT/logs/a11y.xcresult"
rm -rf "$RESULT"
TEST_RUNNER_LUMEN_A11Y_SCENES="$SCENES" \
xcodebuild test-without-building \
  -project LumenE2E.xcodeproj \
  -scheme LumenScreenTour \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DD" \
  -resultBundlePath "$RESULT" \
  -only-testing:"LumenScreenTour/AccessibilityAuditTests" \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/test.log" 2>&1
STATUS=$?
grep -E "error:|failed|passed|skipped" "$OUT/logs/test.log" | tail -n 20
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT" || echo "::warning::attachment export failed"
python3 -I "$ROOT/scripts/apptest/screens_index.py" rename "$OUT"
echo "::endgroup::"

FENCE='```'
{
  echo "## A11y audit, $DEVICE, text $SIZE (simulator, inte enhet): test $([ $STATUS -eq 0 ] && echo körde || echo "FEL ($STATUS)")"
  echo
  echo "$FENCE"
  cat "$OUT"/a11y-summary*.txt 2>/dev/null || echo "no summary (the test did not get that far)"
  echo "$FENCE"
} > "$OUT/summary.md"
cat "$OUT/summary.md"
exit $STATUS
