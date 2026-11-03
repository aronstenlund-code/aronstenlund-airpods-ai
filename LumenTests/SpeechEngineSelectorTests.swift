import Foundation
import Testing
@testable import Lumen

@Suite struct SpeechEngineSelectorTests {
    private let sv = Locale(identifier: "sv-SE")
    private let en = Locale(identifier: "en_US")

    @Test func normalizesUnderscoresAndCase() {
        #expect(SpeechEngineSelector.normalize("sv_SE") == "sv-se")
        #expect(SpeechEngineSelector.normalize(Locale(identifier: "en_US")) == "en-us")
    }

    @Test func exactLocaleMatches() {
        #expect(SpeechEngineSelector.matches(sv, in: ["en-us", "sv-se"]))
        #expect(!SpeechEngineSelector.matches(sv, in: ["en-us", "da-dk"]))
    }

    @Test func sameLanguageOtherRegionMatches() {
        #expect(SpeechEngineSelector.matches(sv, in: ["sv-fi"]))
        #expect(SpeechEngineSelector.matches(sv, in: ["sv"]))
        #expect(SpeechEngineSelector.matches(en, in: ["en-gb"]))
        #expect(!SpeechEngineSelector.matches(sv, in: ["svk-xx", "es-es"]), "prefix must be the whole language code")
    }

    @Test func chainOrderIsSpeechTranscriberThenDictationThenLegacy() {
        let all = SpeechEngineAvailability(speechTranscriberLocales: ["sv-se"], dictationLocales: ["sv-se"], legacyOnDeviceLocales: ["sv-se"])
        #expect(SpeechEngineSelector.choose(for: sv, availability: all) == .speechTranscriber)
        #expect(all.engines(for: sv) == [.speechTranscriber, .dictationTranscriber, .legacyOnDevice])

        let noTranscriber = SpeechEngineAvailability(speechTranscriberLocales: ["en-us"], dictationLocales: ["sv-se"], legacyOnDeviceLocales: ["sv-se"])
        #expect(SpeechEngineSelector.choose(for: sv, availability: noTranscriber) == .dictationTranscriber)

        let legacyOnly = SpeechEngineAvailability(speechTranscriberLocales: [], dictationLocales: [], legacyOnDeviceLocales: ["sv-se"])
        #expect(SpeechEngineSelector.choose(for: sv, availability: legacyOnly) == .legacyOnDevice)
    }

    @Test func nothingSupportsTheLanguage() {
        let english = SpeechEngineAvailability(speechTranscriberLocales: ["en-us"], dictationLocales: ["en-gb"], legacyOnDeviceLocales: ["en-us"])
        #expect(SpeechEngineSelector.choose(for: sv, availability: english) == nil)
        #expect(SpeechEngineSelector.choose(for: sv, availability: .nothing) == nil)
    }
}

@MainActor
@Suite struct LanguageSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.language.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultFollowsThePhoneLanguage() {
        #expect(LanguageSettings(defaults: freshDefaults(), systemLocale: Locale(identifier: "sv_SE")).selected == .swedish)
        #expect(LanguageSettings(defaults: freshDefaults(), systemLocale: Locale(identifier: "en_GB")).selected == .english)
        #expect(LanguageSettings(defaults: freshDefaults(), systemLocale: Locale(identifier: "de_DE")).selected == .english)
        #expect(TranscriptionLanguage.systemDefault(Locale(identifier: "sv")) == .swedish)
    }

    @Test func selectionPersists() {
        let defaults = freshDefaults()
        let settings = LanguageSettings(defaults: defaults, systemLocale: Locale(identifier: "sv_SE"))
        settings.selected = .english
        #expect(LanguageSettings(defaults: defaults, systemLocale: Locale(identifier: "sv_SE")).selected == .english)
    }

    @Test func unknownStoredValueFallsBackToDefault() {
        let defaults = freshDefaults()
        defaults.set("xx-YY", forKey: LanguageSettings.defaultsKey)
        #expect(LanguageSettings(defaults: defaults, systemLocale: Locale(identifier: "sv_SE")).selected == .swedish)
    }

    @Test func localesAreBCP47() {
        #expect(TranscriptionLanguage.swedish.locale.identifier(.bcp47) == "sv-SE")
        #expect(TranscriptionLanguage.english.locale.identifier(.bcp47) == "en-US")
    }
}

@MainActor
@Suite struct ChunkFanOutTests {
    @Test func subscribersReceiveEveryChunkAndUnsubscribeEndsTheStream() async {
        let h = ControllerHarness()
        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream()
        h.capture.chunks = stream
        await h.controller.start()

        let a = h.controller.subscribeToChunks()
        let b = h.controller.subscribeToChunks()
        let chunk = AudioChunk(samples: [Int16](repeating: 3, count: 640), hostTime: 9, firstSampleIndex: 0)
        continuation.yield(chunk)

        var iteratorA = a.stream.makeAsyncIterator()
        var iteratorB = b.stream.makeAsyncIterator()
        #expect(await iteratorA.next() == chunk)
        #expect(await iteratorB.next() == chunk)
        #expect(h.controller.chunkCount == 1)
        #expect(h.controller.lastChunkFrames == 640)

        h.controller.unsubscribeFromChunks(a.id)
        #expect(await iteratorA.next() == nil, "unsubscribing finishes the subscriber's stream")

        continuation.yield(chunk)
        #expect(await iteratorB.next() == chunk, "other subscribers keep receiving")
    }
}
