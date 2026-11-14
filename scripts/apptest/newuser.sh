#!/usr/bin/env bash
# T21 (Toby 2): a new user in A94's first start, from an erased Simulator to the first question of the first exam
# (AppTests/E2E/Screens/NewUserRepetitionTests.swift). Screens before the camera, BETA text, taps, time.
#
#   scripts/apptest/newuser.sh                       # both orders
#   LUMEN_T21_ORDERS=camera-first scripts/apptest/newuser.sh
#
# Output: apptest-out/newuser/*.png, t21-log.txt, summary.md. Live backend (drill, drill audio: 3 questions, about
# 0.15 USD of voice, D120). Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/newuser"
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

RUNTIME="$(xcrun simctl list -j | jq -r '.runtimes[] | select(.isAvailable and (.identifier | test("iOS-26"))) | .identifier' | sort -V | tail -n 1)"
UDID="$(xcrun simctl list devices -j | jq -r --arg rt "$RUNTIME" '.devices[$rt][]? | select(.name == "iPhone 17 Pro" or .name == "iPhone 17") | .udid' | head -n 1)"
test -n "$UDID" || { echo "::error::no iPhone 17 simulator"; exit 1; }
echo "Simulator: $UDID on $RUNTIME"

# One pass per order on an erased Simulator (LUMEN_T21_ORDERS, default "photo"):
#   photo         Fota sidor, then Välj bilder with a picture of the material (the default since 43587898100)
#   text-first    Skriv text before Fota sidor: the whole path to the first question
#   camera-first  a new user's order; runs 43585273570 and 43586474124 never got focus in Skriv text after the photo
#                 library sheet, so this pass shows whether that still happens
echo "::group::Material picture"
xcrun swift "$ROOT/scripts/apptest/material_png.swift" "$OUT/material.png" "Fotosyntes. Växter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre bildas och släpps ut. Sockret ger växten energi och byggmaterial." || { echo "::error::no material picture"; exit 1; }
echo "::endgroup::"
FAILED=0
: > "$OUT/summary.md"
for ORDER in ${LUMEN_T21_ORDERS:-photo}; do
  echo "::group::New user, $ORDER"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false || true
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl ui "$UDID" appearance light
  xcrun simctl addmedia "$UDID" "$OUT/material.png" || echo "::warning::addmedia failed"
  xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
  xcrun simctl spawn "$UDID" log stream --style compact --level info \
    --predicate 'subsystem == "com.rsolutions.lumen"' > "$OUT/logs/$ORDER-app.log" 2>&1 &
  LOGPID=$!
  RESULT="$OUT/logs/$ORDER.xcresult"
  rm -rf "$RESULT"
  TEST_RUNNER_LUMEN_T21="1" \
  TEST_RUNNER_LUMEN_T21_ORDER="$ORDER" \
  TEST_RUNNER_LUMEN_T21_STOP_AFTER="${LUMEN_T21_STOP_AFTER:-}" \
  xcodebuild test-without-building \
    -project LumenE2E.xcodeproj \
    -scheme LumenScreenTour \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DD" \
    -resultBundlePath "$RESULT" \
    -only-testing:"LumenScreenTour/NewUserRepetitionTests" \
    CODE_SIGNING_ALLOWED=NO \
    > "$OUT/logs/$ORDER-test.log" 2>&1
  STATUS=$?
  kill "$LOGPID" >/dev/null 2>&1 || true
  grep -E "error:|XCTAssert|failed|passed|skipped" "$OUT/logs/$ORDER-test.log" | tail -n 30
  mkdir -p "$OUT/$ORDER"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/$ORDER" || echo "::warning::attachment export failed"
  python3 -I "$ROOT/scripts/apptest/screens_index.py" rename "$OUT/$ORDER"
  echo "::endgroup::"
  LOG="$(ls "$OUT/$ORDER"/*t21-log*.txt 2>/dev/null | head -n 1)"
  {
    echo "## T21 Ny användare, $ORDER (simulator, inte enhet): $([ $STATUS -eq 0 ] && echo grön || echo röd)"
    echo
    if [ -n "$LOG" ]; then
      echo '```'
      sed -n '1,/^Log:/p' "$LOG"
      echo '```'
    else
      echo "Ingen logg (testet kom inte så långt)."
    fi
    echo
  } >> "$OUT/summary.md"
  [ $STATUS -ne 0 ] && FAILED=1
done
cat "$OUT/summary.md"
exit $FAILED
