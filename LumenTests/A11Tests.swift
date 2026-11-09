import Foundation
import Testing
@testable import Lumen

/// A11: Lumen never stays deaf: Scribe is tried again with a growing wait, also after the phone's recogniser failed.
@MainActor
@Suite struct ScribeRetryTests {
    @MainActor final class Recorder {
        var created: [FakeSTTProvider] = []
        var scribeError: STTError?
    }

    private func makeCoordinator(_ h: ControllerHarness, available: SpeechEngineAvailability) -> (TranscriptionCoordinator, Recorder) {
        let suite = "lumen.tests.a11.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = STTSettings(defaults: defaults)
        settings.useCloud = true
        let recorder = Recorder()
        let coordinator = TranscriptionCoordinator(controller: h.controller,
                                                   language: LanguageSettings(defaults: defaults, systemLocale: Locale(identifier: "sv_SE")),
                                                   settings: settings,
                                                   probe: { _ in available },
                                                   makeProvider: { locale, engine in
            let provider = FakeSTTProvider(locale: locale, engine: engine)
            if engine == .scribe { provider.prepareError = recorder.scribeError }
            recorder.created.append(provider)
            return provider
        })
        return (coordinator, recorder)
    }

    @Test func theWaitDoublesUpToThirtySeconds() {
        #expect((1...7).map { TranscriptionCoordinator.retryDelay(attempt: $0) } == [1, 2, 4, 8, 16, 30, 30])
    }

    @Test func scribeComesBackAfterThePhoneFailedToo() async {
        let h = ControllerHarness()
        let (coordinator, recorder) = makeCoordinator(h, available: .nothing)
        var statuses: [TranscriptionCoordinator.Status] = []
        coordinator.onStatusChanged = { statuses.append($0) }
        recorder.scribeError = .startFailed(detail: "offline")
        await h.controller.start()

        // Scribe fails, the phone has no engine: not running, and a retry is planned.
        #expect(await waitUntil { if case .unavailable = coordinator.status { return true }; return false })
        #expect(coordinator.scribeRetryAttempt == 1)
        #expect(h.controller.eventLog.contains { $0.text.hasPrefix("Scribe retry 1 in 1 s") })

        recorder.scribeError = nil
        #expect(await waitUntil(timeout: .seconds(5)) { coordinator.status == .running(.scribe) })
        #expect(statuses.contains(.running(.scribe)), "the screen hears that recognition is back")
    }

    @Test func noRetryAfterTheUserStops() async {
        let h = ControllerHarness()
        let (coordinator, recorder) = makeCoordinator(h, available: .nothing)
        recorder.scribeError = .startFailed(detail: "offline")
        await h.controller.start()
        #expect(await waitUntil { coordinator.scribeRetryAttempt == 1 })
        await h.controller.stop()
        let created = recorder.created.count
        try? await Task.sleep(for: .milliseconds(1_500))
        #expect(recorder.created.count == created, "stopped means stopped")
    }

    @Test func aScribeSessionLogsItsKeyterms() async {
        let h = ControllerHarness()
        let (coordinator, _) = makeCoordinator(h, available: .nothing)
        coordinator.setContextualStrings(["Fotosyntes", "Elektromagnetisk induktion"])
        await h.controller.start()
        #expect(await waitUntil { coordinator.status == .running(.scribe) })
        #expect(h.controller.eventLog.contains { $0.text == "Scribe keyterms: 3, longest 16 characters (Elektromagnetisk)" })
    }
}

@Suite struct CannotHearProblemTests {
    @Test func theCardSaysItAndRetriesByItself() {
        let problem = LumenProblem.cannotHear
        #expect(problem.title == "Jag hör inte just nu")
        #expect(problem.spoken == "Jag hör inte just nu, försöker igen.")
        #expect(problem.actionTitle == nil)
    }
}
