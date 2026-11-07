import Foundation
import Testing
@testable import Lumen

@MainActor
@Suite struct SessionControllerTests {
    @Test func startRequestsPermissionActivatesAndCaptures() async {
        let h = ControllerHarness()
        h.controller.config = .cHFPMeasurement

        await h.controller.start()

        #expect(h.controller.state == .listening)
        #expect(h.session.permissionRequests == 1)
        #expect(h.session.activateCalls == [.cHFPMeasurement])
        #expect(h.capture.startCalls == 1)
        #expect(h.controller.isCapturing)
        #expect(h.controller.isActiveSession)
        #expect(h.controller.lastError == nil)
        // The snapshot is refreshed with the engine's input format after the tap is installed.
        #expect(h.session.snapshot?.engineInputFormat == "16000 Hz · 1 ch · Int16")
    }

    @Test func permissionDeniedEndsInErrorWithoutCapture() async {
        let h = ControllerHarness()
        h.session.permissionGranted = false

        await h.controller.start()

        guard case .error(let message) = h.controller.state else {
            Issue.record("expected error state, got \(h.controller.state.label)")
            return
        }
        #expect(message == AudioError.permissionDenied.localizedDescription)
        #expect(h.session.activateCalls.isEmpty)
        #expect(h.capture.startCalls == 0)
        #expect(h.session.deactivateCalls == 1, "stopCapture effect releases the session")
        #expect(!h.controller.isActiveSession)
    }

    @Test func startFromBackgroundIsRefused() async {
        let h = ControllerHarness(foreground: false)

        await h.controller.start()

        #expect(h.controller.state == .error("Capture must be started from the foreground"))
        #expect(h.session.permissionRequests == 0)
        #expect(h.capture.startCalls == 0)
    }

    @Test func activationFailureEndsInError() async {
        let h = ControllerHarness()
        h.session.activationError = .sessionActivation(detail: "busy")

        await h.controller.start()

        guard case .error = h.controller.state else {
            Issue.record("expected error state, got \(h.controller.state.label)")
            return
        }
        #expect(h.capture.startCalls == 0)
        #expect(h.session.deactivateCalls == 1)
    }

    @Test func captureStartFailureEndsInError() async {
        let h = ControllerHarness()
        h.capture.startError = .engineStart(detail: "no input")

        await h.controller.start()

        guard case .error = h.controller.state else {
            Issue.record("expected error state, got \(h.controller.state.label)")
            return
        }
        #expect(h.session.activateCalls.count == 1)
        #expect(h.session.deactivateCalls == 1)
        #expect(!h.capture.isCapturing)
    }

    @Test func stopReturnsToIdleAndReleasesSession() async {
        let h = ControllerHarness()
        await h.controller.start()

        await h.controller.stop()

        #expect(h.controller.state == .idle)
        #expect(!h.capture.isCapturing)
        #expect(h.capture.stopCalls == 1)
        #expect(h.playback.stopCalls == 1)
        #expect(h.session.deactivateCalls == 1)
        #expect(h.session.activeConfig == nil)
    }

    @Test func interruptionPausesAndKeepsTheSession() async {
        let h = ControllerHarness()
        await h.controller.start()

        await h.controller.apply(.interruptionBegan)
        #expect(h.controller.state == .paused(.interruption))
        #expect(!h.capture.isCapturing)
        #expect(h.session.deactivateCalls == 0, "pause keeps the session, only the engine stops")

        await h.controller.resume()
        #expect(h.controller.state == .listening)
        #expect(h.session.reactivateCalls == 1)
        #expect(h.capture.startCalls == 2)
        #expect(h.capture.isCapturing)
    }

    @Test func interruptionWithoutResumeHintStillListensAgain() async {
        let h = ControllerHarness()
        await h.controller.start()

        await h.controller.apply(.interruptionBegan)
        await h.controller.apply(.interruptionEnded(shouldResume: false))
        #expect(h.controller.state == .listening, "D74: listening comes back without a tap")
        #expect(h.capture.startCalls == 2)
    }

    @Test func airPodsRemovedPausesAndResumesWhenTheyAreBack() async {
        let h = ControllerHarness()
        await h.controller.start()

        await h.controller.apply(.outputDeviceLost)
        #expect(h.controller.state == .paused(.outputDeviceLost))
        #expect(!h.capture.isCapturing)

        await h.controller.apply(.outputDeviceRestored)
        #expect(h.controller.state == .listening, "D74: the AirPods are back, Lumen listens again")
        #expect(h.capture.startCalls == 2)
    }

    @Test func stopWhilePausedReturnsToIdle() async {
        let h = ControllerHarness()
        await h.controller.start()
        await h.controller.apply(.outputDeviceLost)

        await h.controller.stop()

        #expect(h.controller.state == .idle)
        #expect(h.session.deactivateCalls == 1)
    }

    @Test func restartAfterErrorWorks() async {
        let h = ControllerHarness()
        h.session.permissionGranted = false
        await h.controller.start()
        guard case .error = h.controller.state else {
            Issue.record("expected error state first")
            return
        }

        h.session.permissionGranted = true
        await h.controller.start()

        #expect(h.controller.state == .listening)
        #expect(h.controller.lastError == nil)
        #expect(h.capture.startCalls == 1)
    }

    @Test func eventLogRecordsTransitionsNewestFirst() async {
        let h = ControllerHarness()
        await h.controller.start()
        await h.controller.stop()

        let texts = h.controller.eventLog.map(\.text)
        #expect(texts.first == "State Listening → Idle")
        #expect(texts.contains("State Idle → Listening"))
    }
}
