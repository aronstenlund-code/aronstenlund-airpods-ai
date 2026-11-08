#!/usr/bin/env bash
# T1 (Toby): the audio chain test. Speech files (macOS `say`, Swedish voice; Kevin's D88 audio replaces them when it
# exists) go through the app's real chain in the Simulator: VAD → Scribe live → utterance joining → QuestionGate /
# Provläge → /answer. Live and paid (Scribe, /answer): manual and nightly only.
#
#   scripts/apptest/chain.sh
#
# Output: apptest-out/chain/{fragor,prov}.json, audio/ (the generated files), logs/. Simulator only.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/chain"
AUDIO="$OUT/audio"
mkdir -p "$OUT/logs" "$AUDIO"

echo "::group::Speech files"
VOICE="${LUMEN_TTS_VOICE:-}"
if [ -z "$VOICE" ]; then
  # "Alva                sv_SE    # Hej! ..." → "Alva" (names can hold spaces, so cut at the locale column)
  VOICE="$(say -v '?' | grep -E '[[:space:]]sv_SE[[:space:]]' | head -n 1 | sed -E 's/[[:space:]]+sv_SE.*$//')"
fi
if [ -z "$VOICE" ]; then
  say -v '?' | head -n 40
  echo "::error::no Swedish voice for say on this runner"
  exit 1
fi
echo "Voice: $VOICE"
cp AppTests/E2E/Audio/cases.tsv "$AUDIO/cases.tsv"
tail -n +2 AppTests/E2E/Audio/cases.tsv | while IFS=$'\t' read -r SET ID KIND TEXT; do
  [ -z "$SET" ] && continue
  say -v "$VOICE" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/$SET-$ID.wav" "$TEXT"
  echo "$SET-$ID ($KIND): $TEXT"
done
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

echo "::group::Chain test (real time, live Scribe and /answer)"
TEST_RUNNER_LUMEN_E2E_DIR="$AUDIO" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-chain" \
  -resultBundlePath "$OUT/logs/chain.xcresult" \
  -only-testing:LumenE2ETests/AudioChainE2ETests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/chain-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T1 result|passed|failed" "$OUT/logs/chain-test.log" | tail -n 60
echo "::endgroup::"

python3 -I "$ROOT/scripts/apptest/chain_summary.py" "$OUT" > "$OUT/summary.md" || true
cat "$OUT/summary.md"
exit $STATUS
