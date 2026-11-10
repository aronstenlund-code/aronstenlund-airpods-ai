#!/usr/bin/env bash
# T7 (Toby): Angela's A15 "Mer?" window in the Simulator (AppTests/E2E/More/MoreE2ETests.swift). The test plays each
# probe ("ja", "mer", "gärna", a late "ja", "ja men ...", another voice's "ja", a new question) when the window is open.
#
#   scripts/apptest/more.sh
#
# Output: apptest-out/more/more.json, summary.md, logs/. Live and paid (Scribe, /answer). Answers are spoken in
# Apple's voice (no /tts). Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/more"
AUDIO="$OUT/audio"
mkdir -p "$OUT/logs" "$AUDIO"

echo "::group::Speech files"
VOICES="$(say -v '?' | grep -E '[[:space:]]sv_SE[[:space:]]' | sed -E 's/[[:space:]]+sv_SE.*$//')"
echo "Swedish voices:"
echo "$VOICES"
WEARER="${LUMEN_TTS_VOICE:-$(echo "$VOICES" | head -n 1)}"
OTHER="$(echo "$VOICES" | grep -v -x "$WEARER" | head -n 1)"
if [ -z "$WEARER" ]; then
  echo "::error::no Swedish voice for say on this runner"
  exit 1
fi
if [ -z "$OTHER" ]; then
  # Only one Swedish voice: the other speaker is an English voice saying the Swedish word.
  OTHER="$(say -v '?' | grep -E '[[:space:]]en_(US|GB)[[:space:]]' | head -n 1 | sed -E 's/[[:space:]]+en_.*$//')"
fi
echo "Wearer: $WEARER, other voice: $OTHER" | tee "$OUT/voices.txt"
cp AppTests/E2E/Audio/more.tsv "$AUDIO/more.tsv"
tail -n +2 AppTests/E2E/Audio/more.tsv | while IFS=$'\t' read -r ID KIND DELAY VOICE KEY QUESTION PROBE; do
  [ -z "$ID" ] && continue
  say -v "$WEARER" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/question-$ID.wav" "$QUESTION"
  PV="$WEARER"
  [ "$VOICE" = "other" ] && PV="$OTHER"
  say -v "$PV" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/probe-$ID.wav" "$PROBE"
  echo "$ID ($KIND, $DELAY s, $VOICE = $PV): $QUESTION -> $PROBE"
done
ENROLL="Jag läser en kort text så att appen lär sig min röst. Igår gick jag till skolan och vi hade biologi på morgonen."
ENROLL="$ENROLL Läraren berättade om fotosyntes och om hur växterna tar upp ljus. Efter lunch spelade vi fotboll på skolgården,"
ENROLL="$ENROLL och sedan gick jag hem och läste läxan till på fredag."
say -v "$WEARER" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/enroll-wearer.wav" "$ENROLL"
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

echo "::group::More window (real time, live Scribe and /answer)"
TEST_RUNNER_LUMEN_E2E_MORE_DIR="$AUDIO" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-more" \
  -resultBundlePath "$OUT/logs/more.xcresult" \
  -only-testing:"LumenE2ETests/MoreE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/more-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T7 case|passed|failed|known issue" "$OUT/logs/more-test.log" | cut -c1-400 | tail -n 50
echo "::endgroup::"

python3 -I "$ROOT/scripts/apptest/more_summary.py" "$OUT" > "$OUT/summary.md" || true
cat "$OUT/summary.md"
exit $STATUS
