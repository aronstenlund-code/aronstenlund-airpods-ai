#!/usr/bin/env bash
# T18 (Toby 2): the repetition mode (A78–A81) in the Simulator with mock sound (AppTests/E2E/Repetition/).
#
#   scripts/apptest/repetition.sh
#
# Audio: quiet tones with known lengths, made here (no ElevenLabs, no say). Question 2.0 s, long answer 6.0 s with
# the short answer ending at 2.5 s, short answer file 2.5 s. The test drives the real RepetitionSession with the real
# AVAudioPlayer and timer, and presses through RemoteCommandHub, as AirPods do.
# Output: apptest-out/repetition/repetition.json, summary.md, logs/. Simulator only: never a device test. Free.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/repetition"
AUDIO="$OUT/audio"
mkdir -p "$OUT/logs" "$AUDIO"

echo "::group::Mock sound"
python3 -I - "$AUDIO" <<'PY'
import math, sys, wave, array
out = sys.argv[1]
def tone(name, seconds, hz):
    n = int(16000 * seconds)
    a = array.array("h", (int(600 * math.sin(2 * math.pi * hz * i / 16000)) for i in range(n)))
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(a.tobytes())
for i in range(4):
    tone(f"q{i}", 2.0, 300 + 40 * i)
    tone(f"l{i}", 6.0, 500 + 40 * i)
    tone(f"s{i}", 2.5, 700 + 40 * i)
PY
ls -la "$AUDIO"
echo "::endgroup::"

echo "::group::Generate project"
xcodegen generate || exit 1
echo "::endgroup::"

JSON="$(xcrun simctl list devices available -j)"
RUNTIME="$(echo "$JSON" | jq -r '.devices | keys[] | select(test("iOS-26"))' | sort -V | tail -n 1)"
UDID="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" '.devices[$rt][] | select(.name | test("^iPhone 17 Pro$|^iPhone 17$")) | .udid' | head -n 1)"
test -n "$UDID" || { echo "::error::no iPhone 17 simulator"; exit 1; }
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

echo "::group::Repetition (real time, mock sound)"
TEST_RUNNER_LUMEN_E2E_REPETITION_DIR="$AUDIO" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-repetition" \
  -resultBundlePath "$OUT/logs/repetition.xcresult" \
  -only-testing:"LumenE2ETests/RepetitionE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/repetition-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T18|passed|failed" "$OUT/logs/repetition-test.log" | cut -c1-400 | tail -n 60
echo "::endgroup::"
[ -f "$OUT/summary.md" ] || echo "# T18: no summary (the test did not get that far)" > "$OUT/summary.md"
cat "$OUT/summary.md"
exit $STATUS
