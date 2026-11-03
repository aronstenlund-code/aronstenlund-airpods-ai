import Foundation
import Speech

/// "Check SpeechTranscriber locales" (Phase 1 §3.6): is sv-SE supported on this device?
enum SpeechLocaleCheck {
    static func run() async -> String {
        var lines: [String] = []
        lines.append("SpeechTranscriber.isAvailable: \(SpeechTranscriber.isAvailable)")
        let supported = await SpeechTranscriber.supportedLocales
        let installed = await SpeechTranscriber.installedLocales
        let dictation = await DictationTranscriber.supportedLocales
        lines.append(section("SpeechTranscriber.supportedLocales", supported))
        lines.append(section("SpeechTranscriber.installedLocales", installed))
        lines.append(section("DictationTranscriber.supportedLocales", dictation))
        return lines.joined(separator: "\n")
    }

    static func section(_ title: String, _ locales: [Locale]) -> String {
        let ids = locales.map { $0.identifier(.bcp47) }.sorted()
        let hasSwedish = ids.contains { $0.lowercased().hasPrefix("sv") }
        let hasEnglishUS = ids.contains { $0.lowercased() == "en-us" }
        let swedishIDs = ids.filter { $0.lowercased().hasPrefix("sv") }
        return "\(title) (\(ids.count)): sv-SE \(hasSwedish ? "YES \(swedishIDs.joined(separator: ","))" : "NO") · en-US \(hasEnglishUS ? "YES" : "NO")\n  \(ids.joined(separator: ", "))"
    }
}
