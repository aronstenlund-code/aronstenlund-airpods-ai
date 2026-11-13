#!/usr/bin/env bash
# T17 (Toby): the wake word "Lumen" (A75) in the Simulator (AppTests/E2E/Wake/WakeE2ETests.swift).
#
#   WAKE_SETS=wake,nowake WAKE_APP_REF=<commit> scripts/apptest/wake.sh
#
# WAKE_APP_REF (optional): build the app code (Lumen/, project.yml) from that commit, for the baseline before A75
# (ec35d41^). The test itself always comes from the checked-out tree.
# Audio: `say` with three Swedish voices and the rates in AppTests/E2E/Audio/wake.tsv, rooms by wake_audio.py.
# Output: apptest-out/wake/wake-<set>.json, summary.md, logs/. Live and paid (Scribe, /answer), Apple's voice and
# answers not spoken (no /tts). Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/wake"
AUDIO="$OUT/audio"
mkdir -p "$OUT/logs" "$AUDIO"

if [ -n "${WAKE_APP_REF:-}" ]; then
  echo "::group::App code from $WAKE_APP_REF (baseline)"
  git fetch --quiet --depth=200 origin "$WAKE_APP_REF" 2>/dev/null || git fetch --quiet --unshallow origin || true
  # Files added since then (A78 and later) must go too, or the old code does not build: the app code and every E2E
  # test come from that commit (2026-11-13: E2E/Repetition/ stayed and broke the baseline build), and only this
  # test (Wake/) and its cases (Audio/wake.tsv) come back from this checkout.
  KEEP="$(mktemp -d)"
  cp -R AppTests/E2E/Wake "$KEEP/Wake" && cp AppTests/E2E/Audio/wake.tsv "$KEEP/wake.tsv" || exit 1
  rm -rf Lumen AppTests/E2E
  git checkout "$WAKE_APP_REF" -- Lumen project.yml AppTests/E2E || exit 1
  mkdir -p AppTests/E2E/Audio
  cp -R "$KEEP/Wake" AppTests/E2E/Wake && cp "$KEEP/wake.tsv" AppTests/E2E/Audio/wake.tsv || exit 1
  git log -1 --format='%h %s' "$WAKE_APP_REF"
  echo "::endgroup::"
fi

echo "::group::Speech files"
# macOS ships bash 3.2: no mapfile, and an empty array is "unbound" under set -u, so count separately.
VOICES=()
NV=0
while IFS= read -r v; do
  [ -n "$v" ] && { VOICES+=("$v"); NV=$((NV + 1)); }
done < <(say -v '?' | grep -E '[[:space:]]sv_SE[[:space:]]' | sed -E 's/[[:space:]]+sv_SE.*$//')
if [ "$NV" -eq 0 ]; then
  say -v '?' | head -n 40
  echo "::error::no Swedish voice for say on this runner"
  exit 1
fi
echo "Voices: ${VOICES[*]}"
cp AppTests/E2E/Audio/wake.tsv "$AUDIO/wake.tsv"
mk() { say -v "$1" -r "$2" --file-format=WAVE --data-format=LEI16@16000 -o "$3" "$4"; }
# Babble: three long sentences in the other voices, never the case texts, and never a question (2026-11-13: "Kan du
# tänka dig att …" was answered as a question in two nowake files, which said nothing about the name).
mk "${VOICES[0]}" 180 "$AUDIO/babble-0.wav" "Vi pratade länge om semestern och om hur dyrt det har blivit att äta ute på restaurang nu för tiden."
mk "${VOICES[$((1 % $NV))]}" 170 "$AUDIO/babble-1.wav" "Hon berättade att bilen hade gått sönder igen och att verkstaden inte kunde ta emot den förrän nästa vecka."
mk "${VOICES[$((2 % $NV))]}" 200 "$AUDIO/babble-2.wav" "Det finns fortfarande ingen parkering vid stationen trots alla löften från kommunen, så vi tar bussen dit."
tail -n +2 AppTests/E2E/Audio/wake.tsv | while IFS=$'\t' read -r ID EXPECT VOICE RATE COND KEY TEXT; do
  [ -z "$ID" ] && continue
  V="${VOICES[$((VOICE % $NV))]}"
  mk "$V" "$RATE" "$AUDIO/clean-$ID.wav" "$TEXT"
  # Babble never uses the speaker's own voice file twice in a row: the two others plus one more.
  python3 -I "$ROOT/scripts/apptest/wake_audio.py" "$COND" "$AUDIO/clean-$ID.wav" "$AUDIO/$ID.wav" \
    "$AUDIO/babble-$(((VOICE + 1) % 3)).wav" "$AUDIO/babble-$(((VOICE + 2) % 3)).wav" || exit 1
  rm -f "$AUDIO/clean-$ID.wav"
  echo "$ID ($EXPECT, $V, $RATE, $COND): $TEXT"
done
python3 -I -c "import sys, wave; w = wave.open(sys.argv[1], 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(2 * 16000 * 20)); w.close()" "$AUDIO/lead-silence.wav"
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

echo "::group::Wake (real time, live Scribe and /answer)"
TEST_RUNNER_LUMEN_E2E_WAKE_DIR="$AUDIO" \
TEST_RUNNER_LUMEN_E2E_WAKE_SETS="${WAKE_SETS:-}" \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-wake" \
  -resultBundlePath "$OUT/logs/wake.xcresult" \
  -only-testing:"LumenE2ETests/WakeE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/wake-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T17 result|passed|failed" "$OUT/logs/wake-test.log" | cut -c1-400 | tail -n 60
echo "::endgroup::"

python3 -I "$ROOT/scripts/apptest/wake_summary.py" "$OUT" "${WAKE_APP_REF:-main}" > "$OUT/summary.md" || true
cat "$OUT/summary.md"
exit $STATUS
