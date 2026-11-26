#!/usr/bin/env bash
# T58 (Toby (moln)): "Spela in själv" through the views (A165, D263), fake audio only (D180: LUMEN_TEST_HEADER),
# -FakeOwnRecorder 1 (no microphone in CI). AppTests/E2E/Screens/OwnDeckFlowTests.swift.
#
#   scripts/apptest/t58ui.sh
#
# The Simulator has no network switch of its own: it uses the Mac's. When the test writes t58-net-off.request this
# script turns every network service of the runner off (networksetup), and on again at t58-net-on.request. A watchdog
# turns them on after 5 minutes whatever happens, and the EXIT trap does too, so the runner is never left without one.
# Output: apptest-out/t58ui/*.png, t58-log.txt, logs/app.log (the app's own log), summary.md. Simulator only.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/t58ui"
DD="$ROOT/DerivedData-e2e"
mkdir -p "$OUT/logs"

SERVICES=()
while IFS= read -r line; do
  case "$line" in ""|"An asterisk"*|"*"*) continue ;; esac
  SERVICES+=("$line")
done < <(networksetup -listallnetworkservices 2>/dev/null)
echo "network services: ${SERVICES[*]:-(none)}"

net_on() {
  for S in "${SERVICES[@]}"; do sudo networksetup -setnetworkserviceenabled "$S" on 2>/dev/null || true; done
  for _ in $(seq 1 30); do curl -sS -m 3 -o /dev/null https://api.github.com && return 0; sleep 2; done
  echo "::warning::network not back after 60 s"
}
net_off() {
  for S in "${SERVICES[@]}"; do sudo networksetup -setnetworkserviceenabled "$S" off 2>/dev/null || true; done
  sleep 3
  if curl -sS -m 3 -o /dev/null https://api.github.com 2>/dev/null; then echo "note: api.github.com still answers"; fi
}
WATCHDOG=""
cleanup() {
  [ -n "$WATCHDOG" ] && kill "$WATCHDOG" 2>/dev/null
  [ -n "${WATCHER:-}" ] && kill "$WATCHER" 2>/dev/null
  [ -n "${LOGPID:-}" ] && kill "$LOGPID" 2>/dev/null
  net_on >/dev/null 2>&1
}
trap cleanup EXIT

echo "::group::Generate and build"
cp AppTests/E2E/project-e2e.yml ./project-e2e.yml
xcodegen generate --spec project-e2e.yml || exit 1
xcodebuild build-for-testing -project LumenE2E.xcodeproj -scheme LumenScreenTour -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/build-for-testing.log" 2>&1
BUILD=$?
tail -n 20 "$OUT/logs/build-for-testing.log"
echo "::endgroup::"
if [ $BUILD -ne 0 ]; then
  grep -E "error:" "$OUT/logs/build-for-testing.log" | head -n 40
  echo "::error::build-for-testing failed"
  exit 1
fi

echo "::group::Simulator"
JSON="$(xcrun simctl list devices available -j)"
RUNTIME="$(echo "$JSON" | jq -r '.devices | keys[] | select(test("iOS-26"))' | sort -V | tail -n 1)"
UDID="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" '.devices[$rt][] | select(.name == "iPhone 17 Pro") | .udid' | head -n 1)"
test -n "$UDID" || { echo "::error::no Simulator"; exit 1; }
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false || true
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
xcrun simctl erase "$UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
xcrun simctl spawn "$UDID" log stream --style compact --level info \
  --predicate 'subsystem == "com.rsolutions.lumen"' > "$OUT/logs/app.log" 2>&1 &
LOGPID=$!
echo "::endgroup::"

rm -f "$OUT"/t58-net-*
(
  while true; do
    if [ -f "$OUT/t58-net-off.request" ]; then
      rm -f "$OUT/t58-net-off.request"
      echo "$(date -u +%H:%M:%S) network off" >> "$OUT/logs/net.log"
      net_off >> "$OUT/logs/net.log" 2>&1
      touch "$OUT/t58-net-off.done"
      ( sleep 300; echo "$(date -u +%H:%M:%S) watchdog: network on" >> "$OUT/logs/net.log"; net_on ) &
      DOG=$!
    fi
    if [ -f "$OUT/t58-net-on.request" ]; then
      rm -f "$OUT/t58-net-on.request"
      [ -n "${DOG:-}" ] && kill "$DOG" 2>/dev/null; DOG=""
      echo "$(date -u +%H:%M:%S) network on" >> "$OUT/logs/net.log"
      net_on >> "$OUT/logs/net.log" 2>&1
      touch "$OUT/t58-net-on.done"
    fi
    sleep 1
  done
) &
WATCHER=$!

echo "::group::T58 views"
RESULT="$OUT/logs/t58ui.xcresult"
rm -rf "$RESULT"
TEST_RUNNER_LUMEN_T58_OUT="$OUT" \
xcodebuild test-without-building -project LumenE2E.xcodeproj -scheme LumenScreenTour \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DD" -resultBundlePath "$RESULT" \
  -only-testing:"LumenScreenTour/OwnDeckFlowTests" CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/t58ui-test.log" 2>&1
STATUS=$?
kill "$WATCHER" 2>/dev/null; WATCHER=""
net_on
grep -E "error:|failed|passed|skipped" "$OUT/logs/t58ui-test.log" | tail -n 15
kill "$LOGPID" 2>/dev/null; LOGPID=""
mkdir -p "$OUT/screens"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/screens" || echo "::warning::attachment export failed"
python3 -I "$ROOT/scripts/apptest/screens_index.py" rename "$OUT/screens" || true
echo "::endgroup::"

{
  echo "## T58 Spela in själv genom vyerna (simulator, inte enhet): $([ "$STATUS" = 0 ] && echo grön || echo röd)"
  echo
  echo '```'
  cat "$OUT/t58-log.txt" 2>/dev/null | cut -c1-400 || echo "no log"
  echo '```'
  echo
  echo "Nätet:"
  echo '```'
  cat "$OUT/logs/net.log" 2>/dev/null
  echo '```'
  echo
  echo "Appens rader om nät och ljud under övningen:"
  echo '```'
  grep -E "OwnDeck|own deck|Own|request|Request|URLError|offline|drill|exam|quota" "$OUT/logs/app.log" 2>/dev/null | cut -c1-220 | tail -n 40
  echo '```'
} > "$OUT/summary.md"
cat "$OUT/summary.md"
exit $STATUS
