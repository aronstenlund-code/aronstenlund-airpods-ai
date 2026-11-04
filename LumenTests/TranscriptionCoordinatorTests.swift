import Foundation
import Testing
@testable import Lumen

@MainActor
@Suite struct TranscriptionCoordinatorTests {
    @Test func capturingStartsSpeechTranscriberForSwedish() async {
        let h = CoordinatorHarness()

        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })

        #expect(h.recorder.created.count == 1)
        #expect(h.provider?.engine == .speechTranscriber)
        #expect(h.provider?.locale.identifier(.bcp47) == "sv-SE")
        #expect(h.provider?.prepareCalls == 1)
        #expect(h.provider?.startCalls == 1)
        #expect(h.coordinator.status == .running(.speechTranscriber))
    }

    @Test func fallsBackToDictationWhenSpeechTranscriberLacksSwedish() async {
        let h = CoordinatorHarness(availability: SpeechEngineAvailability(speechTranscriberLocales: ["en-us"],
                                                                           dictationLocales: ["sv-se", "en-us"],
                                                                           legacyOnDeviceLocales: ["sv-se"]))
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })
        #expect(h.provider?.engine == .dictationTranscriber)
    }

    @Test func fallsBackToOnDeviceLegacyRecognizerLast() async {
        let h = CoordinatorHarness(availability: SpeechEngineAvailability(speechTranscriberLocales: [],
                                                                           dictationLocales: ["en-us"],
                                                                           legacyOnDeviceLocales: ["sv-se"]))
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })
        #expect(h.provider?.engine == .legacyOnDevice)
    }

    @Test func unavailableLanguageIsReportedAndSwitchingLanguageRecovers() async {
        let h = CoordinatorHarness(availability: SpeechEngineAvailability(speechTranscriberLocales: ["en-us"],
                                                                           dictationLocales: ["en-gb"],
                                                                           legacyOnDeviceLocales: []))
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status == .unavailable(.swedish) })
        #expect(h.recorder.created.isEmpty, "no engine is created for an unsupported language")
        #expect(h.session.controller.isCapturing, "the microphone keeps running; only transcription is missing")

        await h.coordinator.setLanguage(.english)
        #expect(await waitUntil { h.coordinator.status.isRunning })
        #expect(h.provider?.locale.identifier(.bcp47) == "en-US")
        #expect(h.defaults.string(forKey: LanguageSettings.defaultsKey) == "en-US")
    }

    @Test func resultsReachTheSink() async {
        let h = CoordinatorHarness()
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })

        h.provider?.emit.yield(STTResult(text: "vad är", isFinal: false, audioStart: 0, audioEnd: 0.4))
        h.provider?.emit.yield(STTResult(text: "vad är fotosyntes", isFinal: false, audioStart: 0, audioEnd: 0.9))
        h.provider?.emit.yield(STTResult(text: "Vad är fotosyntes?", isFinal: true, audioStart: 0, audioEnd: 1.1))

        #expect(await waitUntil { h.sink.finals.count == 1 })
        #expect(h.sink.partials == ["vad är", "vad är fotosyntes"])
        #expect(h.sink.finals == ["Vad är fotosyntes?"])
    }

    @Test func audioChunksReachTheProvider() async {
        let h = CoordinatorHarness()
        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream()
        h.session.capture.chunks = stream
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })

        continuation.yield(AudioChunk(samples: [Int16](repeating: 1, count: 640), hostTime: 1, firstSampleIndex: 0))
        continuation.yield(AudioChunk(samples: [Int16](repeating: 2, count: 640), hostTime: 2, firstSampleIndex: 640))

        #expect(await waitUntil { h.provider?.receivedChunks.count == 2 })
        #expect(h.provider?.receivedChunks.map(\.firstSampleIndex) == [0, 640])
        #expect(h.session.controller.chunkCount == 2)
    }

    @Test func stoppingCaptureStopsTheProvider() async {
        let h = CoordinatorHarness()
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })

        await h.session.controller.stop()

        #expect(await waitUntil { h.provider?.stopCalls == 1 })
        #expect(await waitUntil { h.coordinator.status == .idle })
    }

    @Test func pauseAndResumeRestartTheProvider() async {
        let h = CoordinatorHarness()
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })

        await h.session.controller.apply(.interruptionBegan)
        #expect(await waitUntil { h.recorder.created[0].stopCalls == 1 })

        await h.session.controller.resume()
        #expect(await waitUntil { h.recorder.created.count == 2 && h.coordinator.status.isRunning })
        #expect(h.recorder.created[1].startCalls == 1)
    }

    @Test func languageChangeWhileListeningRestartsWithTheNewLocale() async {
        let h = CoordinatorHarness()
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })

        await h.coordinator.setLanguage(.english)

        #expect(h.recorder.created.count == 2)
        #expect(h.recorder.created[0].stopCalls == 1)
        #expect(h.recorder.created[1].locale.identifier(.bcp47) == "en-US")
        #expect(h.coordinator.status.isRunning)
        #expect(h.language.selected == .english)
    }

    @Test func languageChangeWhileIdleOnlyPersists() async {
        let h = CoordinatorHarness()
        await h.coordinator.setLanguage(.english)
        #expect(h.recorder.created.isEmpty)
        #expect(LanguageSettings(defaults: h.defaults).selected == .english)
    }

    @Test func prepareFailureIsShownAndKeepsCapturing() async {
        let h = CoordinatorHarness()
        h.recorder.prepareError = .modelInstallFailed(detail: "offline")
        await h.session.controller.start()

        let expected = STTError.modelInstallFailed(detail: "offline").localizedDescription
        #expect(await waitUntil { h.coordinator.status == .failed(expected) })
        #expect(h.session.controller.isCapturing)
        #expect(h.provider?.startCalls == 0)
    }

    @Test func startFailureIsShownAndProviderIsStopped() async {
        let h = CoordinatorHarness()
        h.recorder.startError = .startFailed(detail: "boom")
        await h.session.controller.start()

        let expected = STTError.startFailed(detail: "boom").localizedDescription
        #expect(await waitUntil { h.coordinator.status == .failed(expected) })
        #expect(await waitUntil { h.provider?.stopCalls == 1 })
    }
}
