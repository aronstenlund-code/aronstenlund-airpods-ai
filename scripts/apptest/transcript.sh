#!/bin/bash
# T17c (Toby 1, D180): the listening tests with recorded or written transcripts, never ElevenLabs.
#   TRANSCRIPT_SETS=t17,web,fynd8,a97,t16 scripts/apptest/transcript.sh
# Scribe is off in the app (stt.useCloud = false), the capture plays silence, the answers come from the live /answer
# (Claude) and are not spoken except in T16 (Apple's voice). Simulator only: never a device test.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/transcript"
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

# Toby's branches name their sets in scripts/apptest/transcript-branch-sets (one runner per set, in parallel).
if [ -z "${TRANSCRIPT_SETS:-}" ]; then
  TRANSCRIPT_SETS="$(tr -d ' \n' < scripts/apptest/transcript-branch-sets 2>/dev/null || true)"
fi
echo "Sets: ${TRANSCRIPT_SETS:-all}"
echo "::group::Transcript tests (live /answer, no ElevenLabs)"
TEST_RUNNER_LUMEN_E2E_TRANSCRIPT_FILE="$ROOT/AppTests/E2E/Audio/transcript-cases.json" \
TEST_RUNNER_LUMEN_E2E_TRANSCRIPT_SETS="${TRANSCRIPT_SETS:-}" \
TEST_RUNNER_LUMEN_E2E_SILENCE="$OUT/silence.wav" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-transcript" \
  -resultBundlePath "$OUT/logs/transcript.xcresult" \
  -only-testing:"LumenE2ETests/TranscriptE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/transcript-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T17c|T16c" "$OUT/logs/transcript-test.log" | cut -c1-400 | tail -n 80
echo "::endgroup::"

python3 -I "$ROOT/scripts/apptest/transcript_summary.py" "$OUT" > "$OUT/summary.md" || true
cat "$OUT/summary.md"
exit $STATUS
