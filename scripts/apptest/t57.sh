#!/bin/bash
# T57 (Toby, D258): the app while the server's model is down. /answer answers 503 provider_quota inside the test
# process (no Claude, no credits), /stt-token and /tts are closed (D180: 0 ElevenLabs), the phone's model is A159's
# pretend one (-OnDeviceMock, test builds only). Simulator only: never a device test.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/t57"
mkdir -p "$OUT/logs"
python3 -I -c "import sys, wave; w = wave.open(sys.argv[1], 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(2 * 16000 * 10)); w.close()" "$OUT/silence.wav"

echo "::group::Generate project"
xcodegen generate || exit 1
echo "::endgroup::"

JSON="$(xcrun simctl list devices available -j)"
RUNTIME="$(echo "$JSON" | jq -r '.devices | keys[] | select(test("iOS-26"))' | sort -V | tail -n 1)"
UDID="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" '.devices[$rt][] | select(.name | test("^iPhone 17 Pro$|^iPhone 17$")) | .udid' | head -n 1)"
test -n "$UDID" || { echo "::error::no iPhone 17 simulator"; exit 1; }
echo "Simulator: $UDID on $RUNTIME"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl privacy "$UDID" grant microphone com.rsolutions.lumen || true

echo "::group::Model down (T57)"
TEST_RUNNER_LUMEN_E2E_MODELDOWN_SILENCE="$OUT/silence.wav" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-t57" \
  -resultBundlePath "$OUT/logs/t57.xcresult" \
  -only-testing:"LumenE2ETests/ModelDownE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/t57-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T57 " "$OUT/logs/t57-test.log" | cut -c1-500 | tail -n 60
echo "::endgroup::"

{
  echo "### T57 – the app while the model is down (Simulator)"
  echo
  echo "| Case | Phone model | Language | Verdict | /answer | Credits |"
  echo "|---|---|---|---|---|---|"
  if [ -f "$OUT/modeldown.json" ]; then
    jq -r '.[] | "| \(.id) | \(.mock) | \(.language) | \(.verdict) | \(.answerCalls) | \(.creditsBefore // "?") → \(.creditsAfter // "?") |"' "$OUT/modeldown.json"
  else
    echo "| (no modeldown.json) | | | | | |"
  fi
} > "$OUT/summary.md"
cat "$OUT/summary.md"
[ -f "$OUT/modeldown.json" ] && jq -r '.[] | "--- \(.id)", (.log[] | "  " + .)' "$OUT/modeldown.json" | grep -E "answered|log Fel|log On-device|log Answer|asked|---" | cut -c1-300 | head -n 80
exit $STATUS
