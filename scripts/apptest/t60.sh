#!/bin/bash
# T60 (Toby): D273 (Lyssnar when something goes wrong) and D271 (Historik) from the app's wiring, with fake sources
# (network, battery, low power, the route event) and a pretend server (D180: 0 ElevenLabs, no live /answer).
# Two passes: the microphone allowed (everything else), then refused (the microphone card). Simulator only.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/t60"
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

run_pass() { # $1 name, $2 extra env (KEY=VALUE or empty)
  echo "::group::Trouble and history (T60, $1)"
  env TEST_RUNNER_LUMEN_E2E_TROUBLE_SILENCE="$OUT/silence.wav" TEST_RUNNER_LUMEN_E2E_OUT="$OUT" ${2:+TEST_RUNNER_$2} \
  xcodebuild test \
    -project Lumen.xcodeproj \
    -scheme LumenE2E \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$ROOT/DerivedData-t60" \
    -resultBundlePath "$OUT/logs/t60-$1.xcresult" \
    -only-testing:"LumenE2ETests/TroubleE2ETests" \
    -testLanguage sv -testRegion SE \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    > "$OUT/logs/t60-$1.log" 2>&1
  local status=$?
  grep -E "error:|✘|✔|Test run|T60 " "$OUT/logs/t60-$1.log" | cut -c1-600 | tail -n 60
  echo "::endgroup::"
  return $status
}

xcrun simctl privacy "$UDID" grant microphone com.rsolutions.lumen || true
run_pass allowed ""
STATUS=$?
xcrun simctl privacy "$UDID" revoke microphone com.rsolutions.lumen || true
run_pass denied "LUMEN_E2E_MIC=denied"
DENIED=$?
xcrun simctl privacy "$UDID" grant microphone com.rsolutions.lumen || true
[ "$STATUS" = 0 ] && STATUS=$DENIED

{
  echo "### T60 – Lyssnar när något går fel (D273) och Historik (D271) (Simulator)"
  echo
  if [ -f "$OUT/trouble.jsonl" ]; then
    jq -r '"- **\(.id)**: \(.verdict)", (.notes[] | "  - " + .)' "$OUT/trouble.jsonl"
  else
    echo "(no trouble.jsonl)"
  fi
} > "$OUT/summary.md"
cat "$OUT/summary.md"
exit $STATUS
