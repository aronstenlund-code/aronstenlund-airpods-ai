import Foundation
import Testing
@testable import Lumen

/// Deangelo 2026-11-27 05:52: Start's line says how things stand – the AirPods, the credits, the phone's model – before
/// one starts listening. Read without activating anything; fake route, no network.
@MainActor
@Suite struct StartStatusTests {
    @Test func theLineSaysEachPartShortly() {
        #expect(StartStatus(airPods: true, credits: "1 200 kr", phoneModel: true).line
                == "AirPods anslutna · 1 200 kr · Telefonens modell redo")
        #expect(StartStatus(airPods: false, credits: nil, phoneModel: false).line
                == "Inga AirPods – svaren hörs i högtalaren", "unknown credits and no model: not said")
    }

    private func model(_ h: ControllerHarness) -> ListeningModel {
        ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                       transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                       answers: makeTestAnswerEngine(FakeAnswerProvider()), speaker: makeTestSpeaker(h.playback),
                       voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
    }

    private func snapshot(_ port: String) -> SessionSnapshot {
        var snapshot = FakeSessionManager.makeSnapshot(config: .bHQ)
        snapshot.outputs = [PortInfo(portType: port, portName: port, uid: "o", channelCount: 1, dataSource: nil)]
        return snapshot
    }

    @Test func theAirPodsAreReadFromTheRouteAsItIsNow() {
        let h = ControllerHarness()
        let model = model(h)
        h.session.snapshot = snapshot("Speaker")
        #expect(!model.startStatus.airPods)
        h.session.snapshot = snapshot("BluetoothA2DPOutput")
        model.refreshStartStatus()
        #expect(model.startStatus.airPods)
        #expect(!model.isActiveSession, "nothing was started to read it")
    }

    @Test func aRouteChangeIsSaidAtOnce() {
        let h = ControllerHarness()
        let model = model(h)
        let before = model.conditionsTick
        h.session.eventHandler?(.routeChanged(reason: "newDeviceAvailable", outputLost: false, snapshot: snapshot("BluetoothHFP")))
        #expect(model.conditionsTick > before, "Start's line follows the AirPods in and out")
    }

    @Test func thePhonesModelIsSaidWhenItIsReady() {
        let h = ControllerHarness()
        let model = model(h)
        #expect(!model.startStatus.phoneModel)
        model.answers.offline = OnDeviceAnswerProvider(model: FakeOnDeviceModel(reply: "Tio.", languages: ["sv", "en"]))
        #expect(model.startStatus.phoneModel)
        model.answers.offline = OnDeviceAnswerProvider(model: FakeOnDeviceModel(reply: nil, languages: []))
        #expect(!model.startStatus.phoneModel, "no Apple Intelligence: not said")
    }
}
