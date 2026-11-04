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

    @Test func interruptionWithoutResumeWaitsForUser() {
        let (paused, _) = SessionReducer.reduce(.listening, .interruptionBegan)
        let (waiting, effect) = SessionReducer.reduce(paused, .interruptionEnded(shouldResume: false))
        #expect(waiting == .paused(.awaitingUserResume))
        #expect(effect == nil)
        #expect(SessionReducer.reduce(waiting, .userResume) == (.listening, .resumeCapture))
        #expect(SessionReducer.reduce(waiting, .userStop) == (.idle, .stopCapture))
    }

    @Test func airPodsRemovedPausesAndNeverAutoResumes() {
        let (paused, effect) = SessionReducer.reduce(.listening, .outputDeviceLost)
        #expect(paused == .paused(.outputDeviceLost))
        #expect(effect == .pauseCapture)
        let (restored, effect2) = SessionReducer.reduce(paused, .outputDeviceRestored)
        #expect(restored == .paused(.awaitingUserResume))
        #expect(effect2 == nil)
        #expect(SessionReducer.reduce(restored, .userResume) == (.listening, .resumeCapture))
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
