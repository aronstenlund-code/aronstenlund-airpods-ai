#!/usr/bin/env bash
# T6 (Toby): voice commands through the app's real chain in the Simulator. Every command in docs/COMMANDS.md in three
# wordings and ten ordinary sentences with command words (AppTests/E2E/Audio/commands.tsv), spoken by macOS `say`,
# fed through FileCaptureService → VAD → Scribe live → the app's command handling, in each mode.
#
#   scripts/apptest/commands.sh                          all five modes in one run
#   LUMEN_E2E_MODES=prov scripts/apptest/commands.sh     one mode (CI runs one per job)
#
# Output: apptest-out/commands/commands-<mode>.json, summary.md, logs/. Live and paid (Scribe, /answer for the
# level-2 instructions). Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/commands"
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
cp AppTests/E2E/Audio/commands.tsv "$AUDIO/commands.tsv"
tail -n +2 AppTests/E2E/Audio/commands.tsv | while IFS=$'\t' read -r ID EXPECT RUN FLAGS TEXT; do
  [ -z "$ID" ] && continue
  say -v "$VOICE" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/cmd-$ID.wav" "$TEXT"
done
python3 -I -c "import sys, wave; w = wave.open(sys.argv[1], 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(2 * 16000 * 4)); w.close()" "$AUDIO/lead-silence.wav"
ls "$AUDIO" | wc -l
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

echo "::group::Command test (real time, live Scribe)"
TEST_RUNNER_LUMEN_E2E_COMMANDS_DIR="$AUDIO" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
TEST_RUNNER_LUMEN_E2E_MODES="${LUMEN_E2E_MODES:-}" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-commands" \
  -resultBundlePath "$OUT/logs/commands.xcresult" \
  -only-testing:"LumenE2ETests/CommandsE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/commands-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T6 result|passed|failed" "$OUT/logs/commands-test.log" | cut -c1-400 | tail -n 40
echo "::endgroup::"

python3 -I "$ROOT/scripts/apptest/commands_summary.py" "$OUT" > "$OUT/summary.md" || true
cat "$OUT/summary.md"
exit $STATUS
