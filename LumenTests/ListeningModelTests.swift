import Foundation
import Testing
@testable import Lumen

@MainActor
@Suite struct ListeningModelTests {
    @Test func startIsRefusedWithoutConsent() async {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: false))

        await model.startListening()

        #expect(model.state == .idle)
        #expect(h.session.permissionRequests == 0)
        #expect(h.capture.startCalls == 0)
        #expect(h.controller.eventLog.first?.text == "Start refused: no consent")
    }

    @Test func toggleStartsThenStops() async {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true))

        await model.toggleListening()
        #expect(model.isListening)
        #expect(model.isActiveSession)
        #expect(model.routeSummary == "AirPods Pro · HFP")

        await model.toggleListening()
        #expect(model.state == .idle)
        #expect(!model.isActiveSession)
        #expect(h.session.deactivateCalls == 1)
    }

    @Test func toggleWhilePausedStops() async {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true))
        await model.startListening()
        await h.controller.apply(.outputDeviceLost)
        #expect(model.canResume, "AirPods removed: the user may tap Resume")
        #expect(model.isActiveSession, "paused still counts as an active session for the Stop button")

        await model.toggleListening()
        #expect(model.state == .idle)
    }

    @Test func withdrawConsentStopsClearsAndRevokes() async {
        let h = ControllerHarness()
        let consent = FakeConsentStore(granted: true)
        let model = ListeningModel(controller: h.controller, consent: consent)
        await model.startListening()
        model.receiveFinalTranscript("Vad är fotosyntes?")
        model.receiveAnswer(question: "Vad är fotosyntes?", answer: "Växternas sätt att …", source: "mock")

        await model.withdrawConsent()

        #expect(model.state == .idle)
        #expect(consent.revokeCalls == 1)
        #expect(!consent.isGranted)
        #expect(model.conversation.isEmpty)
        #expect(h.session.deactivateCalls == 1)

        await model.startListening()
        #expect(model.state == .idle, "no microphone after consent is withdrawn")
    }

    @Test func transcriptFeedBuildsSegments() {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true))

        model.receivePartialTranscript("vad är")
        model.receivePartialTranscript("vad är foto")
        #expect(model.conversation.segments.count == 1)
        #expect(model.conversation.segments.first?.isFinal == false)

        model.receiveFinalTranscript("Vad är fotosyntes?")
        #expect(model.conversation.segments.count == 1)
        #expect(model.conversation.segments.first?.isFinal == true)
        #expect(model.conversation.segments.first?.text == "Vad är fotosyntes?")
    }

    @Test func speechDuringOurPlaybackIsTagged() {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true))

        h.playback.isSpeaking = true
        model.receivePartialTranscript("växternas sätt")
        h.playback.isSpeaking = false
        model.receiveFinalTranscript("växternas sätt att")

        #expect(model.conversation.finalSegments.first?.overlapsPlayback == true)
        #expect(model.conversation.recentText(seconds: 60).isEmpty, "echo of our own answer is not context")
    }

    @Test func answersAppendAndClearHistory() {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true))

        model.receiveAnswer(question: "Q1", answer: "A1", latencyMs: 812, source: "cloud")
        model.receiveAnswer(question: "Q2", answer: "A2", source: "cloud")
        #expect(model.conversation.answers.map(\.question) == ["Q1", "Q2"])
        #expect(model.conversation.answers.first?.latencyMs == 812)

        model.clearHistory()
        #expect(model.conversation.isEmpty)
    }
}
