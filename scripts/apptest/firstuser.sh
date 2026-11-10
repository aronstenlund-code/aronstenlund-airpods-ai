#!/usr/bin/env bash
# T8 (Toby): the first-time user in the Simulator (AppTests/E2E/Screens/FirstUserTests.swift). Erased Simulator, no
# permissions given, then from the intro to the first answer in Frågor and in Provläge. One pass per path:
#   skip  "Hoppa över" at the exam step, Provläge from the start screen
#   exam  add an exam at the first start, Provläge from its card
#
#   scripts/apptest/firstuser.sh [skip|exam ...]
#
# Output: apptest-out/firstuser/<path>/*.png, t8-<path>-log.txt, summary.md. Live (Scribe, /answer, the default
# voice). Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/firstuser"
DD="$ROOT/DerivedData-e2e"
AUDIO="$OUT/audio"
mkdir -p "$OUT/logs" "$AUDIO"
PATHS=("$@")
[ "${#PATHS[@]}" -eq 0 ] && PATHS=(skip exam)

echo "::group::Speech file"
VOICE="$(say -v '?' | grep -E '[[:space:]]sv_SE[[:space:]]' | head -n 1 | sed -E 's/[[:space:]]+sv_SE.*$//')"
test -n "$VOICE" || { echo "::error::no Swedish voice"; exit 1; }
say -v "$VOICE" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/question.wav" "Vad är huvudstaden i Australien?"
python3 -I -c "import sys, wave; w = wave.open(sys.argv[1], 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(2 * 16000 * 6)); w.close()" "$AUDIO/lead.wav"
ls -la "$AUDIO"
echo "::endgroup::"

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

FAILED=0
{
  echo "## T8 Förstagångsanvändaren (simulator, inte enhet)"
  echo
  echo "| Väg | Test | Milstolpar (sekunder, tryck, skärmar) |"
  echo "|---|---|---|"
} > "$OUT/summary.md"

for P in "${PATHS[@]}"; do
  echo "::group::Path $P"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl ui "$UDID" appearance light
  xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
  RESULT="$OUT/logs/$P.xcresult"
  rm -rf "$RESULT"
  TEST_RUNNER_LUMEN_T8_PATH="$P" \
  TEST_RUNNER_LUMEN_AUDIO_FILES="$AUDIO/lead.wav:$AUDIO/question.wav" \
  TEST_RUNNER_LUMEN_AUDIO_GAP="20" \
  xcodebuild test-without-building \
    -project LumenE2E.xcodeproj \
    -scheme LumenScreenTour \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DD" \
    -resultBundlePath "$RESULT" \
    -only-testing:"LumenScreenTour/FirstUserTests" \
    CODE_SIGNING_ALLOWED=NO \
    > "$OUT/logs/$P-test.log" 2>&1
  STATUS=$?
  grep -E "error:|XCTAssert|failed|passed|skipped" "$OUT/logs/$P-test.log" | tail -n 30
  mkdir -p "$OUT/$P"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/$P" || echo "::warning::attachment export failed for $P"
  python3 -I "$ROOT/scripts/apptest/screens_index.py" rename "$OUT/$P"
  LOG="$(ls "$OUT/$P"/*log*.txt 2>/dev/null | head -n 1)"
  MILES="$(grep '^MILESTONE' "$LOG" 2>/dev/null | sed 's/^MILESTONE //' | tr '\n' ';' | sed 's/;/<br>/g')"
  echo "| $P | $([ $STATUS -eq 0 ] && echo grön || echo röd) | $MILES |" >> "$OUT/summary.md"
  [ $STATUS -ne 0 ] && FAILED=1
  echo "::endgroup::"
done
cat "$OUT/summary.md"
exit $FAILED
