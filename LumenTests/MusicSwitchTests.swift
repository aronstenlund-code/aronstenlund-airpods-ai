import Foundation
import Testing
@testable import Lumen

@MainActor
final class FakeActivityPresenter: ListeningActivityPresenting {
    var shown: [Bool] = []
    var endCalls = 0

    var lastState: ListeningActivityAttributes.ContentState?

    func show(_ state: ListeningActivityAttributes.ContentState) {
        shown.append(state.isPaused)
        lastState = state
    }
    func end() { endCalls += 1 }
}

/// D33: pausing releases the audio session, and nothing but the user brings Lumen back.
@Suite struct MusicSwitchReducerTests {
    @Test func userPauseReleasesAudioAndResumeTakesItBack() {
        #expect(SessionReducer.reduce(.listening, .userPause) == (.paused(.user), .stopCapture))
        #expect(SessionReducer.reduce(.paused(.user), .userResume) == (.listening, .resumeCapture))
        #expect(SessionReducer.reduce(.idle, .userPause) == (.idle, nil))
        #expect(SessionReducer.reduce(.paused(.interruption), .userPause) == (.paused(.interruption), nil))
    }

    @Test func anInterruptionResumesByItselfButTheUsersPauseNever() {
        // D74 replaces "never auto-resume" (D33): after a call or Siri, Lumen listens again.
        #expect(SessionReducer.reduce(.paused(.interruption), .interruptionEnded(shouldResume: true)) == (.listening, .resumeCapture))
        #expect(SessionReducer.reduce(.paused(.interruption), .interruptionEnded(shouldResume: false)) == (.listening, .resumeCapture))
        #expect(SessionReducer.reduce(.paused(.awaitingUserResume), .interruptionEnded(shouldResume: false)) == (.listening, .resumeCapture))
        #expect(SessionReducer.reduce(.paused(.user), .interruptionEnded(shouldResume: true)) == (.paused(.user), nil))
    }

    @Test func anotherAppHoldingAudioCanBeOverriddenByTheUser() {
        #expect(SessionReducer.reduce(.paused(.interruption), .userResume) == (.listening, .resumeCapture))
    }

    @Test func aRouteChangeDuringMusicKeepsTheUsersPause() {
        #expect(SessionReducer.reduce(.paused(.user), .outputDeviceLost) == (.paused(.user), nil))
    }

    @Test func aFailedResumeStaysPausedInsteadOfEndingTheSession() {
        #expect(SessionReducer.reduce(.listening, .resumeFailed) == (.paused(.awaitingUserResume), .pauseCapture))
    }
}

@MainActor
@Suite struct MusicSwitchControllerTests {
    @Test func pauseStopsTheEngineAndDeactivatesTheSession() async {
        let h = ControllerHarness()
        await h.controller.start()

        await h.controller.pause()

        #expect(h.controller.state == .paused(.user))
        #expect(!h.capture.isCapturing)
        #expect(h.session.deactivateCalls == 1, "notifyOthersOnDeactivation lives in deactivate()")
        #expect(h.controller.canResume)
    }

    @Test func resumeAfterPauseSetsTheSessionUpAgain() async {
        let h = ControllerHarness()
        await h.controller.start()
        await h.controller.pause()

        await h.controller.resume()

        #expect(h.controller.state == .listening)
        #expect(h.session.activateCalls.count == 2, "the released session lost its config and preferred input")
        #expect(h.session.reactivateCalls == 0)
        #expect(h.capture.isCapturing)
    }

    @Test func aDeniedResumeLeavesOneTapToTryAgain() async {
        let h = ControllerHarness()
        await h.controller.start()
        await h.controller.pause()
        h.session.activationError = .sessionActivation(detail: "in a call")

        await h.controller.resume()

        #expect(h.controller.state == .paused(.awaitingUserResume))
        #expect(h.controller.lastError != nil)
        #expect(!h.capture.isCapturing)

        h.session.activationError = nil
        await h.controller.resume()
        #expect(h.controller.state == .listening)
        #expect(h.controller.lastError == nil)
    }

    @Test func aFinishedInterruptionListensAgain() async {
        let h = ControllerHarness()
        await h.controller.start()
        await h.controller.apply(.interruptionBegan)
        #expect(h.controller.canResume, "Spotify may never end its interruption: the user can always resume")

        await h.controller.apply(.interruptionEnded(shouldResume: false))

        #expect(h.controller.state == .listening, "D74: after a call or Siri, Lumen listens again")
        #expect(h.session.reactivateCalls == 1)
        #expect(h.capture.startCalls == 2)
    }

    @Test func theUsersPauseIsKeptWhenAnInterruptionEnds() async {
        let h = ControllerHarness()
        await h.controller.start()
        await h.controller.pause()

        await h.controller.apply(.interruptionEnded(shouldResume: true))

        #expect(h.controller.state == .paused(.user))
        #expect(h.capture.startCalls == 1)
    }
}

@MainActor
@Suite struct MusicSwitchModelTests {
    private func makeModel(apple: FakeTTSProvider = FakeTTSProvider(name: "apple")) -> (ControllerHarness, ListeningModel, FakeActivityPresenter) {
        let h = ControllerHarness()
        let activity = FakeActivityPresenter()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(), answers: makeTestAnswerEngine(), speaker: makeTestSpeaker(h.playback, apple: apple), voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(), activity: activity)
        return (h, model, activity)
    }

    @Test func togglePauseGoesBothWaysAndNeverStartsASession() async {
        let (h, model, _) = makeModel()
        await model.togglePause()
        #expect(model.state == .idle, "a Control must not switch the microphone on")

        await model.startListening()
        await model.togglePause()
        #expect(model.state == .paused(.user))
        #expect(h.session.deactivateCalls == 1)
        await model.togglePause()
        #expect(model.state == .listening)
    }

    @Test func theLiveActivityFollowsTheSession() async {
        let (h, model, activity) = makeModel()
        await model.startListening()
        await model.togglePause()
        await h.controller.resume()
        await model.stopListening()

        #expect(activity.shown == [false, true, false])
        #expect(activity.endCalls == 1)
    }

    @Test func nothingIsSpokenOverTheOtherAppWhilePaused() async {
        let apple = FakeTTSProvider(name: "apple")
        let (h, model, _) = makeModel(apple: apple)
        await model.startListening()

        await h.controller.apply(.interruptionBegan)
        model.answerSentence("Hej då.")
        try? await Task.sleep(for: .milliseconds(30))

        #expect(apple.calls.isEmpty)
        #expect(h.playback.stopCalls >= 1, "speech in progress stopped with the interruption")
    }
}
