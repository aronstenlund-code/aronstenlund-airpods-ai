#!/usr/bin/env bash
# T36 (Toby (moln)): "Säg i AirPods" (A115, D203), fake audio only (D180: LUMEN_TEST_HEADER sends
# x-earmind-test). AppTests/E2E/Screens/SayFlowTests.swift.
#
#   scripts/apptest/t36.sh
#
# The Simulator has no network switch of its own: it uses the Mac's. When the test writes t36-net-off.request this
# script turns every network service of the runner off (networksetup), and on again at t36-net-on.request. A watchdog
# turns them on after 5 minutes whatever happens, and the EXIT trap does too, so the runner is never left without one.
# Output: apptest-out/t36/*.png, t36-log.txt, logs/app.log (the app's own log), summary.md. Simulator only.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/t36"
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

echo "::group::Material picture and Simulator"
xcrun swift "$ROOT/scripts/apptest/material_png.swift" "$OUT/material.png" "Fotosyntes. Växter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre bildas och släpps ut. Sockret ger växten energi och byggmaterial." || { echo "::error::no material picture"; exit 1; }
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
xcrun simctl addmedia "$UDID" "$OUT/material.png" || echo "::warning::addmedia failed"
xcrun simctl spawn "$UDID" log config --mode "private_data:on" >/dev/null 2>&1 || echo "note: private_data not allowed"
xcrun simctl spawn "$UDID" log stream --style compact --level info \
  --predicate 'subsystem == "com.rsolutions.lumen"' > "$OUT/logs/app.log" 2>&1 &
LOGPID=$!
echo "::endgroup::"

# The network switch, driven by the test's request files.
rm -f "$OUT"/t36-net-*
(
  while true; do
    if [ -f "$OUT/t36-net-off.request" ]; then
      rm -f "$OUT/t36-net-off.request"
      echo "$(date -u +%H:%M:%S) network off" >> "$OUT/logs/net.log"
      net_off >> "$OUT/logs/net.log" 2>&1
      touch "$OUT/t36-net-off.done"
      ( sleep 300; echo "$(date -u +%H:%M:%S) watchdog: network on" >> "$OUT/logs/net.log"; net_on ) &
      DOG=$!
    fi
    if [ -f "$OUT/t36-net-on.request" ]; then
      rm -f "$OUT/t36-net-on.request"
      [ -n "${DOG:-}" ] && kill "$DOG" 2>/dev/null; DOG=""   # two offline windows: the first one's watchdog must not cut the second
      echo "$(date -u +%H:%M:%S) network on" >> "$OUT/logs/net.log"
      net_on >> "$OUT/logs/net.log" 2>&1
      touch "$OUT/t36-net-on.done"
    fi
    sleep 1
  done
) &
WATCHER=$!

echo "::group::T28 reading"
RESULT="$OUT/logs/t36.xcresult"
rm -rf "$RESULT"
TEST_RUNNER_LUMEN_T36_HEADER="1" \
TEST_RUNNER_LUMEN_T36_OUT="$OUT" \
xcodebuild test-without-building -project LumenE2E.xcodeproj -scheme LumenScreenTour \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DD" -resultBundlePath "$RESULT" \
  -only-testing:"LumenScreenTour/SayFlowTests" CODE_SIGNING_ALLOWED=NO \
  > "$OUT/logs/t36-test.log" 2>&1
STATUS=$?
kill "$WATCHER" 2>/dev/null; WATCHER=""
net_on
grep -E "error:|failed|passed|skipped" "$OUT/logs/t36-test.log" | tail -n 15
kill "$LOGPID" 2>/dev/null; LOGPID=""
# (screens_index.py rename removes every folder it finds, so the pictures get a folder of their own, not $OUT/logs)
mkdir -p "$OUT/screens"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/screens" || echo "::warning::attachment export failed"
python3 -I "$ROOT/scripts/apptest/screens_index.py" rename "$OUT/screens"
echo "::endgroup::"

# The app's own lines while the network was off: what the player played and any request that was tried.
grep -E "Reading:|offline|Offline|network|Network|drill_audio|download" "$OUT/logs/app.log" | cut -c1-300 > "$OUT/logs/app-repetition.log" || true
{
  echo "## T36 Säg i AirPods (simulator, inte enhet): $([ "$STATUS" = 0 ] && echo grön || echo röd)"
  echo
  echo '```'
  sed -n '1,/^Log:/p' "$OUT/t36-log.txt" 2>/dev/null || echo "no log"
  echo '```'
  echo
  echo "Detaljer:"
  echo '```'
  grep -E "MISS|UNCLEAR|questions seen|offline texts|sound lines|launched|MARK|ALERT|GREY|spela-|PRESS|T36|SYSTEM ALERT" "$OUT/t36-log.txt" 2>/dev/null | cut -c1-900
  echo '```'
  echo
  echo "Tryck (testkroken, appens logg):"
  echo '```'
  grep -E "Test press|Reading: (paused|go on|next|previous|tap on|start at)" "$OUT/logs/app.log" 2>/dev/null | cut -c1-220 | head -n 30
  echo '```'
  echo
  echo "Spelaren (appens logg, Reading:):"
  echo '```'
  grep -E "Drill saved|Drill audio|Repetition: (start|waiting|question [0-9]+$)" "$OUT/logs/app.log" 2>/dev/null | cut -c1-220 | tail -n 60
  echo '```'
  echo
  echo "Appen i det andra fönstret utan nät (omstarten) (alla kategorier):"
  echo '```'
  awk '/PLAY-END spela-1/{f=1} f' "$OUT/t36-log.txt" >/dev/null 2>&1
  START="$(grep -o 'NET-OFF request at [0-9T:-]*' "$OUT/t36-log.txt" 2>/dev/null | tail -n1 | sed 's/.* at //; s/T/ /')"
  STOP="$(grep -o 'NET-ON request at [0-9T:-]*' "$OUT/t36-log.txt" 2>/dev/null | tail -n1 | sed 's/.* at //; s/T/ /')"
  if [ -n "$START" ] && [ -n "$STOP" ]; then
    awk -v a="$START" -v b="$STOP" 'substr($0,1,19) >= a && substr($0,1,19) <= b' "$OUT/logs/app.log" | grep -v "Reading: \(question\|thinking\)" | cut -c1-260 | head -n 80
  fi
  echo '```'
  echo
  echo "Nätet (runner):"
  echo '```'
  cat "$OUT/logs/net.log" 2>/dev/null || echo "(no network switch)"
  echo '```'
  echo
  echo "Appens Repetition-rader: $(grep -c 'Reading:' "$OUT/logs/app.log" 2>/dev/null || echo 0)"
} > "$OUT/summary.md"
cat "$OUT/summary.md"
exit $STATUS
