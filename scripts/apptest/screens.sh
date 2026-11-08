#!/usr/bin/env bash
# T3 (Toby): screen tour in the iOS Simulator, one pass per configuration.
# Builds the app + the LumenScreenTour UI tests once, then for each config: fresh simulator (erased, so the first start
# shows), appearance, text size, microphone permission, run the tour, export the screenshots.
#
#   scripts/apptest/screens.sh [config ...]     (default: all configs below)
#
# Output: apptest-out/screens/<config>/*.png, <config>-tour-log.txt, apptest-out/screens/index.html, summary.md
# Simulator only: nothing here is a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/screens"
DD="$ROOT/DerivedData-e2e"
mkdir -p "$OUT/logs"

# name:device:appearance:content_size:mic
ALL_CONFIGS=(
  "pro-light:pro:light:large:allow"
  "pro-dark:pro:dark:large:allow"
  "pro-light-storsta-text:pro:light:accessibility-extra-extra-extra-large:allow"
  "pro-dark-storsta-text:pro:dark:accessibility-extra-extra-extra-large:allow"
  "liten-light:small:light:large:allow"
  "liten-dark:small:dark:large:allow"
  "pro-light-mikrofon-nekad:pro:light:large:deny"
)
if [ "$#" -gt 0 ]; then
  CONFIGS=()
  for want in "$@"; do
    for c in "${ALL_CONFIGS[@]}"; do [ "${c%%:*}" = "$want" ] && CONFIGS+=("$c"); done
  done
else
  CONFIGS=("${ALL_CONFIGS[@]}")
fi

echo "::group::Generate LumenE2E project"
cp AppTests/E2E/project-e2e.yml ./project-e2e.yml
xcodegen generate --spec project-e2e.yml || exit 1
echo "::endgroup::"

echo "::group::Build for testing"
xcodebuild build-for-testing \
  -project LumenE2E.xcodeproj \
  -scheme LumenScreenTour \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/build-for-testing.log" 2>&1
BUILD=$?
tail -n 40 "$OUT/logs/build-for-testing.log"
echo "::endgroup::"
if [ $BUILD -ne 0 ]; then
  grep -E "error:" "$OUT/logs/build-for-testing.log" | head -n 40
  echo "::error::build-for-testing failed"
  exit 1
fi

JSON="$(xcrun simctl list -j)"
RUNTIME="$(echo "$JSON" | jq -r '.runtimes[] | select(.isAvailable and (.identifier | test("iOS-26"))) | .identifier' | sort -V | tail -n 1)"
echo "Runtime: $RUNTIME"

device_for() { # pro | small -> UDID (creates the device if needed)
  local kind="$1" names name udid
  if [ "$kind" = "pro" ]; then
    names=("iPhone 17 Pro" "iPhone 17" "iPhone Air" "iPhone 16 Pro")
  else
    names=("iPhone SE (3rd generation)" "iPhone 13 mini" "iPhone 12 mini" "iPhone 16e")
  fi
  for name in "${names[@]}"; do
    udid="$(xcrun simctl list devices -j | jq -r --arg rt "$RUNTIME" --arg n "Lumen $name" '.devices[$rt][]? | select(.name == $n) | .udid' | head -n 1)"
    if [ -z "$udid" ]; then
      udid="$(xcrun simctl create "Lumen $name" "$name" "$RUNTIME" 2>/dev/null)" || udid=""
    fi
    if [ -n "$udid" ]; then echo "$udid|$name"; return 0; fi
  done
  return 1
}

FAILED=0
: > "$OUT/summary.md"
{
  echo "## Skärmbilder (T3, simulator)"
  echo
  echo "Simulator only, never a verification on a device. Runtime \`$RUNTIME\`."
  echo
  echo "| Config | Device | Screenshots | Unreachable | Test |"
  echo "|---|---|---|---|---|"
} >> "$OUT/summary.md"

for config in "${CONFIGS[@]}"; do
  IFS=: read -r NAME KIND APPEARANCE SIZE MIC <<< "$config"
  echo "::group::Config $NAME"
  PICK="$(device_for "$KIND")" || { echo "::error::no simulator for $KIND"; FAILED=1; echo "::endgroup::"; continue; }
  UDID="${PICK%%|*}"; DEVICE="${PICK#*|}"
  echo "Device: $DEVICE ($UDID)"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl ui "$UDID" appearance "$APPEARANCE"
  xcrun simctl ui "$UDID" content_size "$SIZE" || echo "::warning::content_size $SIZE not set"
  if [ "$MIC" = "deny" ]; then
    xcrun simctl privacy "$UDID" revoke microphone com.rsolutions.lumen || true
  else
    xcrun simctl privacy "$UDID" grant microphone com.rsolutions.lumen || true
  fi
  # Clean status bar, so screenshots compare.
  xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true

  RESULT="$OUT/logs/$NAME.xcresult"
  rm -rf "$RESULT"
  TEST_RUNNER_LUMEN_SHOT_PREFIX="$NAME" \
  TEST_RUNNER_LUMEN_TOUR_MIC="$([ "$MIC" = "deny" ] && echo denied || echo granted)" \
  xcodebuild test-without-building \
    -project LumenE2E.xcodeproj \
    -scheme LumenScreenTour \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DD" \
    -resultBundlePath "$RESULT" \
    CODE_SIGNING_ALLOWED=NO \
    > "$OUT/logs/$NAME-test.log" 2>&1
  STATUS=$?
  grep -E "error:|XCTAssert|failed|passed" "$OUT/logs/$NAME-test.log" | tail -n 40

  mkdir -p "$OUT/$NAME"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/$NAME" || echo "::warning::attachment export failed for $NAME"
  python3 -I "$ROOT/scripts/apptest/screens_index.py" rename "$OUT/$NAME"
  SHOTS="$(ls "$OUT/$NAME"/*.png 2>/dev/null | wc -l | tr -d ' ')"
  MISSES="$(grep -c '^MISS:' "$OUT/$NAME/$NAME-tour-log.txt" 2>/dev/null || echo '?')"
  RESULT_TEXT="$([ $STATUS -eq 0 ] && echo 'grön' || echo 'röd')"
  echo "| $NAME | $DEVICE | $SHOTS | $MISSES | $RESULT_TEXT |" >> "$OUT/summary.md"
  [ $STATUS -ne 0 ] && FAILED=1
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  echo "::endgroup::"
done

python3 -I "$ROOT/scripts/apptest/screens_index.py" index "$OUT"
cat "$OUT/summary.md"
exit $FAILED
