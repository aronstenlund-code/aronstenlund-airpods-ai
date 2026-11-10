#!/usr/bin/env bash
# T10 part 2 (Toby): ElevenLabs down in the Simulator (AppTests/E2E/Outage/OutageE2ETests.swift). The test answers
# 503 to /stt-token and /tts inside its own process, so no ElevenLabs credits are used (D120): Scribe never opens and
# the premium voice never plays. Two questions in Frågor (macOS `say`, free) and one sentence in an ElevenLabs voice.
#
#   scripts/apptest/outage.sh
#
# Output: apptest-out/outage/outage.json, summary.md, logs/. /answer is live. Simulator only: never a device test.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/outage"
AUDIO="$OUT/audio"
mkdir -p "$OUT/logs" "$AUDIO"

echo "::group::Speech files"
VOICE="${LUMEN_TTS_VOICE:-$(say -v '?' | grep -E '[[:space:]]sv_SE[[:space:]]' | head -n 1 | sed -E 's/[[:space:]]+sv_SE.*$//')}"
test -n "$VOICE" || { echo "::error::no Swedish voice for say on this runner"; exit 1; }
say -v "$VOICE" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/q1.wav" "Vad är huvudstaden i Australien?"
say -v "$VOICE" --file-format=WAVE --data-format=LEI16@16000 -o "$AUDIO/q2.wav" "Hur många planeter finns det i solsystemet?"
python3 -I -c "import sys, wave; w = wave.open(sys.argv[1], 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(2 * 16000 * 4)); w.close()" "$AUDIO/lead.wav"
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
xcrun simctl privacy "$UDID" grant speech-recognition com.rsolutions.lumen || true

echo "::group::Outage test (503 on /stt-token and /tts)"
TEST_RUNNER_LUMEN_E2E_OUTAGE_DIR="$AUDIO" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-outage" \
  -resultBundlePath "$OUT/logs/outage.xcresult" \
  -only-testing:"LumenE2ETests/OutageE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/outage-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T10 result|passed|failed" "$OUT/logs/outage-test.log" | cut -c1-400 | tail -n 40
echo "::endgroup::"

{
  echo "## T10 del 2: ElevenLabs nere (503 i testet, simulator)"
  echo
  echo "Test: $([ $STATUS -eq 0 ] && echo grön || echo röd)"
  echo
  python3 -I -c "
import json, sys
r = json.load(open(sys.argv[1], encoding='utf-8'))
print('| Mått | Värde |'); print('|---|---|')
for k in ('voiceAtStart', 'standInLines', 'noticeSeconds', 'noticeFirstAt', 'voiceFallbacks', 'spoken', 'lyssnarWithCannotHear', 'sessionEndedEarly', 'seconds'):
    print(f'| {k} | {r.get(k)} |')
print(f'| stub hits | {len(r[\"stubHits\"])}: ' + ', '.join(sorted(set(r['stubHits']))) + ' |')
print(f'| events | ' + '; '.join(e['kind'] + ' ' + e['text'][:60] for e in r['events'][:12]) + ' |')
" "$OUT/outage.json" 2>/dev/null || echo "(no outage.json)"
} > "$OUT/summary.md"
cat "$OUT/summary.md"
exit $STATUS
