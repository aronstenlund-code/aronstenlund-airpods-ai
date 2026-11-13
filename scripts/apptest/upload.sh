#!/bin/bash
# T20 (Toby 1): K53, many photos to questions, in the Simulator against the live /exam.
#   scripts/apptest/upload.sh
# Runs AppTests/E2E/Upload (live: 1, 4, 10, 30 photos and a flaky 10; stub: the error paths). Paid: Claude Haiku for
# the questions only, no answers, no ElevenLabs. Simulator only: never a device test.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/upload"
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

echo "::group::Upload (live /exam)"
TEST_RUNNER_LUMEN_E2E_UPLOAD=1 \
TEST_RUNNER_LUMEN_E2E_OUT="$OUT" \
xcodebuild test \
  -project Lumen.xcodeproj \
  -scheme LumenE2E \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/DerivedData-upload" \
  -resultBundlePath "$OUT/logs/upload.xcresult" \
  -only-testing:"LumenE2ETests/UploadE2ETests" \
  -testLanguage sv -testRegion SE \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/upload-test.log" 2>&1
STATUS=$?
grep -E "error:|✘|✔|Test run|T20 " "$OUT/logs/upload-test.log" | cut -c1-400 | tail -n 60
echo "::endgroup::"

python3 -I "$ROOT/scripts/apptest/upload_summary.py" "$OUT" > "$OUT/summary.md" || true
cat "$OUT/summary.md"
exit $STATUS
