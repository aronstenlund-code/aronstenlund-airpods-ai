#!/usr/bin/env bash
# T5 (Toby): the retest after Angela's A8 and A11 in the Simulator (AppTests/E2E/Retest/RetestE2ETests.swift):
# Frågor with 10 questions (3 continuations after a pause), Provläge with three questions and a wish in one breath,
# Provläge with an exam whose topics are longer than 20 characters. The long run (T5 part 4) is apptest-long.yml.
#
#   RETEST_SETS=fragor,block scripts/apptest/retest.sh   (D120: only the sets named; empty = all three)
#
# Output: apptest-out/retest/retest-<set>.json, summary.md, logs/. Live and paid (Scribe, /answer). Answers in
# Frågor are spoken in Apple's voice (no /tts). Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/retest"
AUDIO="$OUT/audio"
mkdir -p "$OUT/logs" "$AUDIO"

echo "::group::Speech files"
VOICE="${LUMEN_TTS_VOICE:-}"
if [ -z "$VOICE" ]; then
  VOICE="$(say -v '?' | grep -E '[[:space:]]sv_SE[[:space:]]' | head -n 1 | sed -E 's/[[:space:]]+sv_SE.*$//')"
fi
if [ -z "$VOICE" ]; then
  say -v '?' | head -n 40
  echo "::error::no Swedish voice for say on this runner"
  exit 1
fi
echo "Voice: $VOICE"
cp AppTests/E2E/Audio/retest.tsv "$AUDIO/retest.tsv"
tail -n +2 AppTests/E2E/Audio/retest.tsv | while IFS=$'\t' read -r SET ID KIND PAUSE KEY TEXT; do
  [ -z "$SET" ] && continue
  if [ "$KIND" = "continuation" ]; then
    # "first half | second half": two files with PAUSE seconds of silence between them, as one file.
    FIRST="${TEXT%%|*}"; SECOND="${TEXT#*|}"
    say -v "$VOICE" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/part-a.wav" "$FIRST"
    say -v "$VOICE" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/part-b.wav" "$SECOND"
    python3 -I -c "
import sys, wave
a, b, pause, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
frames = []
for path in (a, b):
    with wave.open(path, 'rb') as w:
        frames.append(w.readframes(w.getnframes()))
with wave.open(out, 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
    w.writeframes(frames[0] + bytes(2 * int(16000 * pause)) + frames[1])
" "$AUDIO/part-a.wav" "$AUDIO/part-b.wav" "$PAUSE" "$AUDIO/$SET-$ID.wav"
    rm -f "$AUDIO/part-a.wav" "$AUDIO/part-b.wav"
  else
    say -v "$VOICE" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/$SET-$ID.wav" "$TEXT"
  fi
  echo "$SET-$ID ($KIND, pause $PAUSE): $TEXT"
done
python3 -I -c "import sys, wave; w = wave.open(sys.argv[1], 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(2 * 16000 * 4)); w.close()" "$AUDIO/lead-silence.wav"
ls -la "$AUDIO"
echo "::endgroup::"

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

echo "::group::Retest (real time, live Scribe and /answer)"
TEST_RUNNER_LUMEN_E2E_RETEST_DIR="$AUDIO" \
TEST_RUNNER_LUMEN_E2E_RETEST_SETS="${RETEST_SETS:-}" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-retest" \
  -resultBundlePath "$OUT/logs/retest.xcresult" \
  -only-testing:"LumenE2ETests/RetestE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/retest-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T5 result|passed|failed" "$OUT/logs/retest-test.log" | cut -c1-400 | tail -n 40
echo "::endgroup::"

python3 -I "$ROOT/scripts/apptest/retest_summary.py" "$OUT" > "$OUT/summary.md" || true
cat "$OUT/summary.md"
exit $STATUS
