#!/usr/bin/env bash
# T62 (Toby (moln)): the app's start time in the Simulator, the app of this checkout. LABEL names it (before/after).
# AppTests/E2E/Screens/LaunchTimeTests.swift. Simulator only: the difference between two apps is what counts.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
LABEL="${LABEL:-app}"
TEST="${TEST:-LaunchTimeTests}"
OUT="$ROOT/apptest-out/t62"
DD="$ROOT/DerivedData-e2e"
mkdir -p "$OUT/logs"
echo "::group::Generate and build ($LABEL, $(git rev-parse --short HEAD))"
cp AppTests/E2E/project-e2e.yml ./project-e2e.yml
xcodegen generate --spec project-e2e.yml || exit 1
xcodebuild build-for-testing -project LumenE2E.xcodeproj -scheme LumenScreenTour -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/build-$LABEL.log" 2>&1 || { grep -E "error:" "$OUT/logs/build-$LABEL.log" | head -n 30; echo "::error::build failed"; exit 1; }
echo "::endgroup::"
JSON="$(xcrun simctl list devices available -j)"
RUNTIME="$(echo "$JSON" | jq -r '.devices | keys[] | select(test("iOS-26"))' | sort -V | tail -n 1)"
UDID="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" '.devices[$rt][] | select(.name == "iPhone 17 Pro") | .udid' | head -n 1)"
test -n "$UDID" || { echo "::error::no Simulator"; exit 1; }
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
xcrun simctl erase "$UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
echo "::group::$TEST ($LABEL)"
TEST_RUNNER_LUMEN_T62_OUT="$OUT" TEST_RUNNER_LUMEN_T62_LABEL="$LABEL" \
xcodebuild test-without-building -project LumenE2E.xcodeproj -scheme LumenScreenTour \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DD" -resultBundlePath "$OUT/logs/t62-$LABEL.xcresult" \
  -only-testing:"LumenScreenTour/$TEST" CODE_SIGNING_ALLOWED=NO > "$OUT/logs/t62-$LABEL.log" 2>&1
STATUS=$?
grep -E "T62 |error:|passed|failed" "$OUT/logs/t62-$LABEL.log" | tail -n 10
echo "::endgroup::"
cat "$OUT/launch-$LABEL.json" "$OUT/t63-log.txt" 2>/dev/null
exit $STATUS
