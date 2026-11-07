import Testing
@testable import Lumen

@Suite struct SessionReducerTests {
    @Test func startStop() {
        #expect(SessionReducer.reduce(.idle, .userStart) == (.listening, .startCapture))
        #expect(SessionReducer.reduce(.listening, .captureStarted) == (.listening, nil))
        #expect(SessionReducer.reduce(.listening, .userStop) == (.idle, .stopCapture))
        #expect(SessionReducer.reduce(.idle, .userStop) == (.idle, nil))
        #expect(SessionReducer.reduce(.error("x"), .userStart) == (.listening, .startCapture))
    }

    @Test func interruptionPauses() {
        let (paused, effect) = SessionReducer.reduce(.listening, .interruptionBegan)
        #expect(paused == .paused(.interruption))
        #expect(effect == .pauseCapture)
    }

    @Test func interruptionEndListensAgain() {
        let (paused, _) = SessionReducer.reduce(.listening, .interruptionBegan)
        #expect(SessionReducer.reduce(paused, .interruptionEnded(shouldResume: false)) == (.listening, .resumeCapture), "D74")
        let waiting = SessionState.paused(.awaitingUserResume)
        #expect(SessionReducer.reduce(waiting, .userResume) == (.listening, .resumeCapture))
        #expect(SessionReducer.reduce(waiting, .userStop) == (.idle, .stopCapture))
    }

    @Test func airPodsRemovedPausesAndResumesWhenTheyAreBack() {
        let (paused, effect) = SessionReducer.reduce(.listening, .outputDeviceLost)
        #expect(paused == .paused(.outputDeviceLost))
        #expect(effect == .pauseCapture)
        #expect(SessionReducer.reduce(paused, .outputDeviceRestored) == (.listening, .resumeCapture), "D74")
        // interruption end while paused for another reason does not resume
        #expect(SessionReducer.reduce(paused, .interruptionEnded(shouldResume: true)) == (.paused(.outputDeviceLost), nil))
    }

    @Test func mediaServicesResetRebuildsGraph() {
        #expect(SessionReducer.reduce(.listening, .mediaServicesReset) == (.paused(.mediaServicesReset), .rebuildAudioGraph))
        #expect(SessionReducer.reduce(.idle, .mediaServicesReset) == (.idle, .rebuildAudioGraph))
        #expect(SessionReducer.reduce(.paused(.mediaServicesReset), .userResume) == (.listening, .resumeCapture))
    }

    @Test func failureFromAnyState() {
        #expect(SessionReducer.reduce(.listening, .failed("boom")) == (.error("boom"), .stopCapture))
        #expect(SessionReducer.reduce(.idle, .failed("boom")) == (.error("boom"), .stopCapture))
        #expect(SessionReducer.reduce(.paused(.interruption), .failed("boom")) == (.error("boom"), .stopCapture))
    }

    @Test func idleIgnoresAudioEvents() {
        #expect(SessionReducer.reduce(.idle, .interruptionBegan) == (.idle, nil))
        #expect(SessionReducer.reduce(.idle, .outputDeviceLost) == (.idle, nil))
        #expect(SessionReducer.reduce(.idle, .interruptionEnded(shouldResume: true)) == (.idle, nil))
    }
}
