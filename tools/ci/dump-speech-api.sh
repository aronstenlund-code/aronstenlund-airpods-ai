#!/usr/bin/env bash
# MVP item 2 — reading aid, never graded.
# Prints the public declarations of the SpeechAnalyzer family (and the SFSpeechRecognizer availability
# macros) from the selected iOS SDK, so the exact signatures we code against are in every CI log.
set -uo pipefail

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
MODULES="$SDK/System/Library/Frameworks/Speech.framework/Modules/Speech.swiftmodule"
HEADERS="$SDK/System/Library/Frameworks/Speech.framework/Headers"
mkdir -p build-logs
OUT="build-logs/speech-api.txt"

IFACE="$(ls "$MODULES"/*.swiftinterface 2>/dev/null | grep -v -i private | grep -i 'arm64-apple-ios\.swiftinterface' | head -n 1)"
if [ -z "$IFACE" ]; then
  IFACE="$(ls "$MODULES"/*.swiftinterface 2>/dev/null | grep -v -i private | head -n 1)"
fi
echo "swiftinterface: ${IFACE:-<none found>}"

TYPES='SpeechAnalyzer|SpeechTranscriber|DictationTranscriber|AnalyzerInput|AssetInventory|AssetInstallationRequest|AnalysisContext|SpeechModule|SpeechModuleResult|LocaleDependentSpeechModule'

{
  echo "# Speech.framework swiftinterface — top-level blocks mentioning: $TYPES"
  echo "# SDK: $SDK"
  echo
  if [ -n "$IFACE" ]; then
    # Top-level lines (no indentation) that name one of the types and open a block; print through the
    # matching top-level closing brace. Single-line top-level declarations naming a type are printed too.
    awk -v types="$TYPES" '
      BEGIN { printing = 0; pat = "(^|[^A-Za-z0-9_])(" types ")([^A-Za-z0-9_]|$)" }
      printing == 0 && /^[^ \t}]/ && $0 ~ pat && /\{[ \t]*$/ { printing = 1 }
      printing == 1 { print; if ($0 ~ /^}/) { printing = 0; print "" }; next }
      printing == 0 && /^[^ \t}]/ && $0 ~ pat { print; print "" }
    ' "$IFACE"
  fi
  echo
  echo "# SFSpeechRecognizer.h availability / deprecation markers"
  grep -n "API_DEPRECATED\|API_AVAILABLE\|API_UNAVAILABLE" "$HEADERS/SFSpeechRecognizer.h" "$HEADERS/SFSpeechRecognitionRequest.h" 2>/dev/null | head -n 40
} > "$OUT"

echo "wrote $OUT ($(wc -l < "$OUT") lines)"
echo "::group::Speech API declarations (SpeechAnalyzer family)"
head -n 3000 "$OUT"
echo "::endgroup::"
