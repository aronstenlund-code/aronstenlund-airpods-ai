#!/bin/bash
# T59 (Toby): D269 Försök igen and Pausa, Ke91 English commands, K124 the phone voice on tts_quota; a pretend server,
# the same credits. /answer, /stt-token and /tts are closed (no live /answer, D180: 0 ElevenLabs).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/t59"
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

echo "::group::Flow (T59)"
TEST_RUNNER_LUMEN_E2E_FLOW_SILENCE="$OUT/silence.wav" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-t59" \
  -resultBundlePath "$OUT/logs/t59.xcresult" \
  -only-testing:"LumenE2ETests/FlowE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/t59-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T59 " "$OUT/logs/t59-test.log" | cut -c1-500 | tail -n 60
echo "::endgroup::"

{
  echo "### T59 – Försök igen, Pausa, English commands, the phone voice (Simulator)"
  echo
  if [ -f "$OUT/flow.jsonl" ]; then
    jq -r '"- **\(.id)**: \(.verdict)", (.notes[] | "  - " + .), (.answerBodies[] | "  - /answer: " + (.[0:200]))' "$OUT/flow.jsonl"
  else
    echo "(no flow.jsonl)"
  fi
} > "$OUT/summary.md"
cat "$OUT/summary.md"
[ -f "$OUT/flow.jsonl" ] && jq -r '"--- \(.id)", (.log[] | "  " + .)' "$OUT/flow.jsonl" | head -n 120
exit $STATUS
