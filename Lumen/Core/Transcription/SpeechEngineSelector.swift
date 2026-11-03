import Foundation
import Speech

/// Which locales each engine supports on this device, as lower-case BCP-47 identifiers ("sv-se").
struct SpeechEngineAvailability: Sendable, Equatable {
    var speechTranscriberLocales: [String] = []
    var dictationLocales: [String] = []
    var legacyOnDeviceLocales: [String] = []

    static let nothing = SpeechEngineAvailability()

    /// Engines that can handle `locale`, best first.
    func engines(for locale: Locale) -> [STTEngine] {
        var out: [STTEngine] = []
        if SpeechEngineSelector.matches(locale, in: speechTranscriberLocales) { out.append(.speechTranscriber) }
        if SpeechEngineSelector.matches(locale, in: dictationLocales) { out.append(.dictationTranscriber) }
        if SpeechEngineSelector.matches(locale, in: legacyOnDeviceLocales) { out.append(.legacyOnDevice) }
        return out
    }
}

/// D18 chain: SpeechTranscriber → DictationTranscriber → on-device SFSpeechRecognizer. Pure, unit-tested.
enum SpeechEngineSelector {
    static func normalize(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    static func normalize(_ locale: Locale) -> String {
        normalize(locale.identifier(.bcp47))
    }

    /// Exact locale match ("sv-se"), else any locale of the same language ("sv", "sv-fi").
    static func matches(_ wanted: Locale, in identifiers: [String]) -> Bool {
        let want = normalize(wanted)
        if identifiers.contains(want) { return true }
        let language = want.split(separator: "-").first.map(String.init) ?? want
        return identifiers.contains { $0 == language || $0.hasPrefix(language + "-") }
    }

    static func choose(for locale: Locale, availability: SpeechEngineAvailability) -> STTEngine? {
        availability.engines(for: locale).first
    }
}

/// Live probe of the device. Only on-device paths count (ARCHITECTURE §12 / consent: audio never leaves the phone).
enum SpeechAvailabilityProbe {
    static func current(candidates: [Locale]) async -> SpeechEngineAvailability {
        var availability = SpeechEngineAvailability()
        if SpeechTranscriber.isAvailable {
            availability.speechTranscriberLocales = await SpeechTranscriber.supportedLocales.map(SpeechEngineSelector.normalize)
        }
        availability.dictationLocales = await DictationTranscriber.supportedLocales.map(SpeechEngineSelector.normalize)
        for locale in candidates {
            if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition {
                availability.legacyOnDeviceLocales.append(SpeechEngineSelector.normalize(locale))
            }
        }
        return availability
    }
}
