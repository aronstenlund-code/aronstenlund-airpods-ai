#!/usr/bin/env bash
# Phase 1a 3.1 step 2 - API-name check.
# Greps the selected iOS SDK for every symbol in tools/ci/sdk-symbols.txt and prints the matching
# lines, then dumps the declarations we depend on most, so a wrong API name is caught before the build.
# Exit code 1 if any symbol is missing. Never guess an API name: fix the code instead.
set -uo pipefail

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
FW="$SDK/System/Library/Frameworks"
LIST="$(cd "$(dirname "$0")" && pwd)/sdk-symbols.txt"
echo "iOS SDK: $SDK"
echo "Symbol list: $LIST"
echo

missing=0
total=0
while IFS='|' read -r framework symbol; do
  case "$framework" in ''|'#'*) continue ;; esac
  total=$((total + 1))
  dir="$FW/$framework.framework"
  echo "::group::$framework :: $symbol"
  if [ ! -d "$dir" ]; then
    echo "!! framework directory missing: $dir"
    missing=$((missing + 1)); echo "::endgroup::"; continue
  fi
  out="$(grep -rIin --include='*.h' --include='*.swiftinterface' --include='*.apinotes' -m 2 -- "$symbol" "$dir" 2>/dev/null | head -n 8 || true)"
  if [ -z "$out" ]; then
    echo "!! NOT FOUND: $symbol in $framework"
    missing=$((missing + 1))
  else
    echo "$out" | sed "s|$FW/||"
  fi
  echo "::endgroup::"
done < "$LIST"

echo
echo "Checked $total symbols, missing: $missing"

dump() { # dump <title> <dir> <pattern> <after-lines>
  echo "::group::DECL $1"
  grep -rIn --include='*.h' --include='*.swiftinterface' -A "$4" -- "$3" "$2" 2>/dev/null | sed "s|$FW/||" | head -n 150 || true
  echo "::endgroup::"
}

echo
echo "===== Declarations we depend on (for reading, not graded) ====="
dump "AVAudioSessionPortExtensionBluetoothMicrophone" "$FW/AVFAudio.framework/Headers" "@interface AVAudioSessionPortExtensionBluetoothMicrophone" 30
dump "AVAudioSessionCapability" "$FW/AVFAudio.framework/Headers" "@interface AVAudioSessionCapability" 25
dump "bluetoothMicrophoneExtension property" "$FW/AVFAudio.framework/Headers" "bluetoothMicrophoneExtension" 3
dump "CategoryOptions HQ / HFP / A2DP" "$FW/AVFAudio.framework/Headers" "AVAudioSessionCategoryOptionBluetoothHighQualityRecording\|AVAudioSessionCategoryOptionAllowBluetoothHFP\|AVAudioSessionCategoryOptionAllowBluetoothA2DP" 2
dump "AVAudioApplication requestRecordPermission" "$FW/AVFAudio.framework/Headers" "requestRecordPermission" 3
dump "AVSpeechSynthesizer write" "$FW/AVFAudio.framework/Headers" "writeUtterance" 4
dump "SpeechTranscriber statics (swiftinterface)" "$FW/Speech.framework/Modules" "class SpeechTranscriber\|static var supportedLocales\|static var installedLocales\|static var isAvailable\|static func supportedLocales\|static func isAvailable" 6
dump "DictationTranscriber (swiftinterface)" "$FW/Speech.framework/Modules" "class DictationTranscriber" 20

if [ "$missing" -ne 0 ]; then
  echo "::error::$missing SDK symbol(s) not found - fix the code (do not guess API names)"
  exit 1
fi
echo "All $total symbols found in the iOS SDK."
