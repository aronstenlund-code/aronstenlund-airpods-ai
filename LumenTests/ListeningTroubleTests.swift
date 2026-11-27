import Foundation
import Testing
@testable import Lumen

/// Deangelo 2026-11-27 02:59: listening when something goes wrong – no AirPods, AirPods gone mid-session, the
/// microphone refused, no network, low battery, low power mode. Each gives a short, clear line and a way on; nothing
/// stops silently. Fake route, fake network and fake battery; 0 ElevenLabs, no model.
@MainActor
final class FakeDeviceConditions: DeviceConditions {
    var isOnline = true
    var batteryPercent: Int?
    var isCharging = false
    var isLowPowerMode = false
    var onChange: (@MainActor () -> Void)?
    private(set) var started = 0
    private(set) var stopped = 0
    func startWatching() { started += 1 }
    func stopWatching() { stopped += 1 }
    func change(_ apply: (FakeDeviceConditions) -> Void) {
        apply(self)
        onChange?()
    }
}

@MainActor
@Suite struct ListeningTroubleTests {
    private func makeModel(_ h: ControllerHarness, pauseWhenAirPodsLost: Bool = true)
        -> (ListeningModel, FakeDeviceConditions) {
        let suite = "lumen.tests.trouble.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let microphone = MicrophoneSettings(defaults: defaults)
        microphone.pauseWhenAirPodsLost = pauseWhenAirPodsLost
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(FakeAnswerProvider()), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   microphone: microphone)
        let conditions = FakeDeviceConditions()
        model.deviceConditions = conditions
        return (model, conditions)
    }

    private func snapshot(_ port: String) -> SessionSnapshot {
        var snapshot = FakeSessionManager.makeSnapshot(config: .bHQ)
        snapshot.outputs = [PortInfo(portType: port, portName: port, uid: "o", channelCount: 1, dataSource: nil)]
        return snapshot
    }

    // MARK: No AirPods

    @Test func withoutAirPodsTheLineSaysTheSpeakerAndHowToGoOn() async {
        let h = ControllerHarness()
        h.session.outputPortType = "Speaker"
        let (model, _) = makeModel(h)
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        #expect(model.listeningCondition == .noAirPods)
        #expect(model.listeningCondition?.line.contains("AirPods") == true)

        // The AirPods come in: the line goes.
        h.session.snapshot = snapshot("BluetoothHFP")
        h.session.eventHandler?(.routeChanged(reason: "newDeviceAvailable", outputLost: false, snapshot: snapshot("BluetoothHFP")))
        #expect(await waitUntil { model.listeningCondition == nil })
        await model.stopListening()
    }

    @Test func withAirPodsNothingIsSaid() async {
        let h = ControllerHarness()
        let (model, _) = makeModel(h)
        #expect(model.listeningCondition == nil, "nothing before listening")
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        #expect(model.listeningCondition == nil)
        await model.stopListening()
    }

    // MARK: AirPods gone mid-session

    @Test func airPodsGoneMidSessionPausesAndSaysHowToGoOn() async {
        let h = ControllerHarness()
        let (model, _) = makeModel(h)
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        h.session.outputPortType = "Speaker"
        h.session.snapshot = snapshot("Speaker")
        h.session.eventHandler?(.routeChanged(reason: "oldDeviceUnavailable", outputLost: true, snapshot: snapshot("Speaker")))
        #expect(await waitUntil { model.state == .paused(.outputDeviceLost) })
        #expect(model.problem == .airPodsLostPaused, "paused: the card says so, not \"answers play on the speaker\"")
        #expect(model.problem?.text.contains("Lyssna igen") == true, "Kelly Ke95 (3): the card points to the footer's button")
        #expect(model.problem?.actionTitle == nil, "no second button: the footer's Lyssna igen is the way on")

        await model.togglePause(fromScreen: true) // the footer's "Lyssna igen": on with the phone's speaker
        #expect(await waitUntil { model.isListening })
        #expect(model.problem == nil)
        #expect(model.listeningCondition == .noAirPods, "and the line says where the answers are heard")
        await model.stopListening()
    }

    @Test func airPodsBackInListensAgainAndTheCardGoes() async {
        let h = ControllerHarness()
        let (model, _) = makeModel(h)
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        h.session.eventHandler?(.routeChanged(reason: "oldDeviceUnavailable", outputLost: true, snapshot: snapshot("Speaker")))
        #expect(await waitUntil { model.problem == .airPodsLostPaused })
        h.session.eventHandler?(.routeChanged(reason: "newDeviceAvailable", outputLost: false, snapshot: snapshot("BluetoothHFP")))
        #expect(await waitUntil { model.isListening && model.problem == nil })
        await model.stopListening()
    }

    @Test func withTheSettingOffItGoesOnInTheSpeakerAndSaysSo() async {
        let h = ControllerHarness()
        let (model, _) = makeModel(h, pauseWhenAirPodsLost: false)
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        h.session.eventHandler?(.routeChanged(reason: "oldDeviceUnavailable", outputLost: true, snapshot: snapshot("Speaker")))
        #expect(await waitUntil { model.problem == .airPodsDisconnected })
        #expect(model.isListening, "not stopped")
        #expect(model.problem?.text == "Svaren hörs nu i telefonens högtalare.")
        await model.stopListening()
    }

    // MARK: The microphone refused

    @Test func aRefusedMicrophoneSaysWhereToTurnItOn() async {
        let h = ControllerHarness()
        h.session.permissionGranted = false
        let (model, _) = makeModel(h)
        await model.startListening()
        #expect(await waitUntil { model.problem == .microphoneDenied })
        #expect(!model.isActiveSession)
        #expect(model.problem?.actionTitle == "Öppna Inställningar", "the way on")
        #expect(model.problem?.text.contains("Inställningar") == true)
    }

    // MARK: No network

    @Test func withoutANetworkTheLineSaysWhatHappensToTheAnswers() async {
        let h = ControllerHarness()
        let (model, conditions) = makeModel(h)
        conditions.isOnline = false
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        #expect(model.listeningCondition == .offline(phoneModel: false))
        #expect(model.listeningCondition?.line.contains("uppkopplad") == true)

        // With the phone's own model (A159) the line says it answers meanwhile.
        model.answers.offline = OnDeviceAnswerProvider(model: FakeOnDeviceModel(reply: "Tio.", languages: ["sv", "en"]))
        conditions.change { _ in }
        #expect(model.listeningCondition == .offline(phoneModel: true))

        conditions.change { $0.isOnline = true }
        #expect(model.listeningCondition == nil, "back online: the line goes")
        await model.stopListening()
    }

    @Test func theNetworkGoingMidSessionIsSaidAtOnce() async {
        let h = ControllerHarness()
        let (model, conditions) = makeModel(h)
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        let before = model.conditionsTick
        conditions.change { $0.isOnline = false }
        #expect(model.conditionsTick > before, "the screen is told")
        #expect(model.listeningCondition == .offline(phoneModel: false))
        await model.stopListening()
    }

    // MARK: Battery and low power mode

    @Test func aLowBatteryNotChargingSaysToChargeIt() async {
        let h = ControllerHarness()
        let (model, conditions) = makeModel(h)
        conditions.batteryPercent = 8
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        #expect(model.listeningCondition == .lowBattery(percent: 8))
        #expect(model.listeningCondition?.line.contains("8") == true)
        #expect(model.listeningCondition?.line.contains("laddning") == true)
        conditions.change { $0.isCharging = true }
        #expect(model.listeningCondition == nil, "charging: nothing to say")
        conditions.change { $0.batteryPercent = 40; $0.isCharging = false }
        #expect(model.listeningCondition == nil)
        await model.stopListening()
    }

    @Test func lowPowerModeIsSaidCalmly() async {
        let h = ControllerHarness()
        let (model, conditions) = makeModel(h)
        conditions.isLowPowerMode = true
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        #expect(model.listeningCondition == .lowPowerMode)
        #expect(model.isListening, "it goes on listening")
        await model.stopListening()
    }

    @Test func theWatchingFollowsTheSession() async {
        let h = ControllerHarness()
        let (model, conditions) = makeModel(h)
        await model.startListening()
        #expect(await waitUntil { conditions.started == 1 })
        await model.stopListening()
        #expect(await waitUntil { conditions.stopped == 1 })
        #expect(model.listeningCondition == nil, "nothing when not listening")
    }

    // MARK: The order, and the lines

    @Test func theMostImportantLineIsShown() {
        typealias C = ListeningCondition
        #expect(C.current(externalOutput: false, online: false, phoneModel: false, batteryPercent: 5, charging: false, lowPowerMode: true)
                == .offline(phoneModel: false), "no network first: the answers change")
        #expect(C.current(externalOutput: false, online: true, phoneModel: false, batteryPercent: 5, charging: false, lowPowerMode: true)
                == .noAirPods)
        #expect(C.current(externalOutput: true, online: true, phoneModel: false, batteryPercent: 5, charging: false, lowPowerMode: true)
                == .lowBattery(percent: 5))
        #expect(C.current(externalOutput: true, online: true, phoneModel: false, batteryPercent: 11, charging: false, lowPowerMode: true)
                == .lowPowerMode)
        #expect(C.current(externalOutput: true, online: true, phoneModel: false, batteryPercent: nil, charging: false, lowPowerMode: false) == nil)
    }

    @Test func everyLineIsShortAndSaysTheWayOn() {
        let all: [ListeningCondition] = [.noAirPods, .offline(phoneModel: true), .offline(phoneModel: false), .lowBattery(percent: 8), .lowPowerMode]
        for condition in all {
            #expect(!condition.line.isEmpty && condition.line.count <= 110, "\(condition): short")
            #expect(!condition.symbol.isEmpty)
        }
        for problem in [LumenProblem.microphoneDenied, .offline, .overloaded] {
            #expect(problem.actionTitle != nil, "\(problem): a button, a way on")
        }
        // Kelly Ke95 (3): the paused AirPods card has the footer's Lyssna igen as its way on, and says so.
        #expect(LumenProblem.airPodsLostPaused.text.contains("Lyssna igen"))
    }
}
