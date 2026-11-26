#!/bin/bash
# T58 (Toby, D263): Spela in själv – make, record (pretend microphone), practise; no request while it happens,
# the same credits. /answer, /stt-token and /tts are closed (no live /answer, D180: 0 ElevenLabs).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/t58"
mkdir -p "$OUT/logs"

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

echo "::group::Own deck (T58)"
TEST_RUNNER_LUMEN_E2E_OWNDECK=1 \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-t58" \
  -resultBundlePath "$OUT/logs/t58.xcresult" \
  -only-testing:"LumenE2ETests/OwnDeckE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/t58-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T58 " "$OUT/logs/t58-test.log" | cut -c1-500 | tail -n 60
echo "::endgroup::"

{
  echo "### T58 – Spela in själv (Simulator)"
  echo
  echo "| Case | Verdict | Requests while practising | Credits |"
  echo "|---|---|---|---|"
  if [ -f "$OUT/owndeck.jsonl" ]; then
    jq -r '"| \(.id) | \(.verdict) | \(.requestsWhilePractising | length) | \(.creditsBefore // "?") → \(.creditsAfter // "?") |"' "$OUT/owndeck.jsonl"
    echo
    jq -r '"- \(.id): \(.phases | join(" → "))" , (.notes[] | "  - " + .), (.requestsWhilePractising[] | "  - request: " + .)' "$OUT/owndeck.jsonl"
  else
    echo "| (no owndeck.jsonl) | | | |"
  fi
} > "$OUT/summary.md"
cat "$OUT/summary.md"
exit $STATUS
