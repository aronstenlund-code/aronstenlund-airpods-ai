#!/usr/bin/env bash
# For Angela Fable's A95: XCTest's accessibility audit on each Debug scene (`-LumenScreenshot <scene>`), plus the
# accessibility tree, per scene (AppTests/E2E/Screens/AccessibilityAuditTests.swift). Findings never fail the run.
#
#   A11Y_DEVICE="iPhone SE (3rd generation)" A11Y_TEXT_SIZE=accessibility-extra-extra-extra-large \
#   A11Y_SCENES="fsWelcome repList" scripts/apptest/a11y.sh
#
# Output: apptest-out/a11y/<config>/a11y-<scene>.audit.txt, .tree.txt, .png and summary.md, written per scene;
# a scene whose audit hangs over A11Y_SCENE_LIMIT s (240) is recorded as STOPPED and the rest go on. Light mode. Free (no
# network). Simulator only: never a verification on a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
DEVICE="${A11Y_DEVICE:-iPhone 17 Pro}"
SIZE="${A11Y_TEXT_SIZE:-default}"
SCENES="${A11Y_SCENES:?set A11Y_SCENES}"
CONFIG="$(echo "$DEVICE-$SIZE" | tr ' ()' '---' | tr -s '-')"
OUT="$ROOT/apptest-out/a11y/$CONFIG"
DD="$ROOT/DerivedData-e2e"
mkdir -p "$OUT/logs"

echo "::group::Generate and build"
cp AppTests/E2E/project-e2e.yml ./project-e2e.yml
xcodegen generate --spec project-e2e.yml || exit 1
xcodebuild build-for-testing \
  -project LumenE2E.xcodeproj \
  -scheme LumenScreenTour \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/build-for-testing.log" 2>&1
BUILD=$?
tail -n 20 "$OUT/logs/build-for-testing.log"
echo "::endgroup::"
if [ $BUILD -ne 0 ]; then
  grep -E "error:" "$OUT/logs/build-for-testing.log" | head -n 40
  echo "::error::build-for-testing failed"
  exit 1
fi

echo "::group::Simulator $DEVICE, text $SIZE"
JSON="$(xcrun simctl list devices available -j)"
RUNTIME="$(echo "$JSON" | jq -r '.devices | keys[] | select(test("iOS-26"))' | sort -V | tail -n 1)"
UDID="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" --arg want "$DEVICE" '.devices[$rt][] | select(.name == $want) | .udid' | head -n 1)"
if [ -z "$UDID" ]; then
  TYPE="$(xcrun simctl list devicetypes -j | jq -r --arg want "$DEVICE" '.devicetypes[] | select(.name == $want) | .identifier' | head -n 1)"
  if [ -n "$TYPE" ]; then UDID="$(xcrun simctl create "$DEVICE" "$TYPE" "$RUNTIME")"; fi
fi
test -n "$UDID" || { echo "::error::no simulator '$DEVICE'"; exit 1; }
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
if [ "$SIZE" != "default" ]; then xcrun simctl ui "$UDID" content_size "$SIZE"; fi
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true
echo "::endgroup::"


# The test writes each scene's files as soon as it is done, and a11y-<scene>.started before its audit. A watchdog
# stops xcodebuild when no scene has finished for A11Y_SCENE_LIMIT seconds (run 43590746967: the SE with the largest
# text stopped inside an audit and the whole artifact was empty), records the stuck scene and goes on with the rest.
LIMIT="${A11Y_SCENE_LIMIT:-240}"
STATUS=0
ROUND=0
while :; do
  REMAINING=""
  for s in $SCENES; do
    [ -f "$OUT/a11y-$s.audit.txt" ] || REMAINING="$REMAINING $s"
  done
  REMAINING="${REMAINING# }"
  [ -z "$REMAINING" ] && break
  ROUND=$((ROUND + 1))
  [ $ROUND -gt 12 ] && { echo "::warning::too many restarts, stopping"; break; }
  echo "::group::Audit round $ROUND: $REMAINING"
  RESULT="$OUT/logs/a11y-$ROUND.xcresult"
  rm -rf "$RESULT"
  TEST_RUNNER_LUMEN_A11Y_SCENES="$REMAINING" \
  TEST_RUNNER_LUMEN_A11Y_OUT="$OUT" \
  xcodebuild test-without-building \
    -project LumenE2E.xcodeproj \
    -scheme LumenScreenTour \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DD" \
    -resultBundlePath "$RESULT" \
    -only-testing:"LumenScreenTour/AccessibilityAuditTests" \
    CODE_SIGNING_ALLOWED=NO \
    > "$OUT/logs/test-$ROUND.log" 2>&1 &
  PID=$!
  LAST=$(date +%s)
  DONE_BEFORE=$(ls "$OUT"/a11y-*.audit.txt 2>/dev/null | wc -l)
  STUCK=""
  while kill -0 $PID 2>/dev/null; do
    sleep 5
    DONE_NOW=$(ls "$OUT"/a11y-*.audit.txt 2>/dev/null | wc -l)
    if [ "$DONE_NOW" -ne "$DONE_BEFORE" ]; then DONE_BEFORE=$DONE_NOW; LAST=$(date +%s); fi
    if [ $(( $(date +%s) - LAST )) -gt "$LIMIT" ]; then
      for s in $REMAINING; do
        if [ -f "$OUT/a11y-$s.started" ] && [ ! -f "$OUT/a11y-$s.audit.txt" ]; then STUCK="$s"; fi
      done
      echo "::warning::no scene finished for $LIMIT s (stuck: ${STUCK:-before the first scene}), stopping xcodebuild"
      pkill -P $PID >/dev/null 2>&1 || true
      kill $PID >/dev/null 2>&1 || true
      sleep 5
      kill -9 $PID >/dev/null 2>&1 || true
      xcrun simctl terminate "$UDID" com.rsolutions.lumen >/dev/null 2>&1 || true
      break
    fi
  done
  wait $PID 2>/dev/null
  CODE=$?
  grep -E "error:|failed|passed|skipped" "$OUT/logs/test-$ROUND.log" | tail -n 10
  echo "::endgroup::"
  if [ -n "$STUCK" ]; then
    printf '%s: STOPPED after %s s without a result (the audit got stuck; the tree and the picture are from before the audit)\n' "$STUCK" "$LIMIT" > "$OUT/a11y-$STUCK.audit.txt"
    STATUS=1
    continue
  fi
  if [ $CODE -ne 0 ]; then
    # Ended without a stuck scene: the first unfinished scene that was started is recorded so the loop moves on.
    for s in $REMAINING; do
      if [ ! -f "$OUT/a11y-$s.audit.txt" ]; then
        printf '%s: NO RESULT, xcodebuild ended with %s (see logs/test-%s.log)\n' "$s" "$CODE" "$ROUND" > "$OUT/a11y-$s.audit.txt"
        STATUS=1
        break
      fi
    done
  fi
done
rm -f "$OUT"/a11y-*.started

FENCE='```'
{
  echo "## A11y audit, $DEVICE, text $SIZE (simulator, inte enhet)"
  echo
  echo "$FENCE"
  for s in $SCENES; do head -n 1 "$OUT/a11y-$s.audit.txt" 2>/dev/null || echo "$s: no file"; done
  echo "$FENCE"
} > "$OUT/summary.md"
cp "$OUT/summary.md" "$OUT/a11y-summary.txt"
cat "$OUT/summary.md"
# Findings and stuck scenes never fail the job: the files are the result.
exit 0
