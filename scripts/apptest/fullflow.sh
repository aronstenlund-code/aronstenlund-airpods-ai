#!/usr/bin/env bash
# T24 (Toby 2): the whole repetition flow as a new user, fake audio only (D180: the app sends x-earmind-test through
# LUMEN_TEST_HEADER, and the Simulator in Actions is a `ci` test). AppTests/E2E/Screens/FullFlowTests.swift.
#
#   scripts/apptest/fullflow.sh            # phases a (Simulator A), b (Simulator B), c (Simulator A again)
#   T24_PHASES="a c" scripts/apptest/fullflow.sh
#
# a: first start → photo → questions → first question → list → ChatGPT import → Dela → Publicera prov
# b: a second new account finds the exam at the school and adds it; the server's slow and unavailable modes
# c: Mina svar → Spela in; Ta bort publiceringen and Ta bort provet (the test exam does not stay published)
# Output: apptest-out/fullflow/<phase>/*.png, t24-<phase>-log.txt, summary.md. Simulator only, never a device.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/apptest-out/fullflow"
DD="$ROOT/DerivedData-e2e"
mkdir -p "$OUT/logs"
PHASES="${T24_PHASES:-a b c}"

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

echo "::group::Material picture and Simulators"
xcrun swift "$ROOT/scripts/apptest/material_png.swift" "$OUT/material.png" "Fotosyntes. Växter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre bildas och släpps ut. Sockret ger växten energi och byggmaterial." || { echo "::error::no material picture"; exit 1; }
JSON="$(xcrun simctl list devices available -j)"
RUNTIME="$(echo "$JSON" | jq -r '.devices | keys[] | select(test("iOS-26"))' | sort -V | tail -n 1)"
SIM_A="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" '.devices[$rt][] | select(.name == "iPhone 17 Pro") | .udid' | head -n 1)"
SIM_B="$(echo "$JSON" | jq -r --arg rt "$RUNTIME" '.devices[$rt][] | select(.name == "iPhone 17") | .udid' | head -n 1)"
if [ -z "$SIM_B" ] || [ "$SIM_B" = "$SIM_A" ]; then
  TYPE="$(xcrun simctl list devicetypes -j | jq -r '.devicetypes[] | select(.name == "iPhone 17 Pro") | .identifier' | head -n 1)"
  SIM_B="$(xcrun simctl create "T24 B" "$TYPE" "$RUNTIME")"
fi
test -n "$SIM_A" && test -n "$SIM_B" || { echo "::error::no Simulators"; exit 1; }
echo "A=$SIM_A B=$SIM_B"
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false || true
for U in "$SIM_A" "$SIM_B"; do
  xcrun simctl shutdown "$U" >/dev/null 2>&1 || true
  xcrun simctl erase "$U"
  xcrun simctl boot "$U"
  xcrun simctl bootstatus "$U" -b >/dev/null
  xcrun simctl ui "$U" appearance light
  xcrun simctl status_bar "$U" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
done
xcrun simctl addmedia "$SIM_A" "$OUT/material.png" || echo "::warning::addmedia failed"
echo "::endgroup::"

FAILED=0
: > "$OUT/summary.md"
for P in $PHASES; do
  if [ "$P" = "b" ]; then U="$SIM_B"; else U="$SIM_A"; fi
  echo "::group::Phase $P on $U"
  mkdir -p "$OUT/$P"
  RESULT="$OUT/logs/$P.xcresult"
  rm -rf "$RESULT"
  TEST_RUNNER_LUMEN_T24_PHASE="$P" \
  TEST_RUNNER_LUMEN_T24_HEADER="1" \
  TEST_RUNNER_LUMEN_T24_OUT="$OUT" \
  xcodebuild test-without-building -project LumenE2E.xcodeproj -scheme LumenScreenTour \
    -destination "platform=iOS Simulator,id=$U" -derivedDataPath "$DD" -resultBundlePath "$RESULT" \
    -only-testing:"LumenScreenTour/FullFlowTests" CODE_SIGNING_ALLOWED=NO \
    > "$OUT/logs/$P-test.log" 2>&1
  STATUS=$?
  grep -E "error:|failed|passed|skipped" "$OUT/logs/$P-test.log" | tail -n 15
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/$P" || echo "::warning::attachment export failed"
  python3 -I "$ROOT/scripts/apptest/screens_index.py" rename "$OUT/$P"
  echo "::endgroup::"
  {
    echo "## T24 phase $P (simulator, inte enhet): $([ $STATUS -eq 0 ] && echo grön || echo röd)"
    echo
    echo '```'
    sed -n '1,/^Log:/p' "$OUT/t24-$P-log.txt" 2>/dev/null || echo "no log"
    echo '```'
    echo
  } >> "$OUT/summary.md"
  [ $STATUS -ne 0 ] && FAILED=1
done
cat "$OUT/summary.md"
exit $FAILED
