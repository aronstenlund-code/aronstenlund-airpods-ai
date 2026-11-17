import Foundation
import Testing
@testable import Lumen

/// D221 (A138, G7 step 7d): the smaller parts that left `ListeningModel`: the test mode's debug audio, the phone
/// tools, the photographed page and the flip cards. The model keeps the calls the screens use; the parts do the work.
@MainActor
@Suite struct G7PartsTests {
    @MainActor final class FakeTools: PhoneToolRunning {
        var available: [PhoneTool] { PhoneTool.allCases }
        var ran: [String] = []
        func run(_ call: PhoneToolCall) async -> (status: ToolRound.Status, result: JSONValue?) {
            ran.append(call.name)
            return (.ok, .object(["alarm_id": .string("A")]))
        }
    }

    func model(events: [AnswerEvent] = []) -> (ListeningModel, FakeAnswerProvider) {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: events)
        let fresh = { UserDefaults(suiteName: "g7parts-\(UUID().uuidString)")! }
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider),
                                   speaker: makeTestSpeaker(h.playback, apple: FakeTTSProvider(name: "apple")),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   activity: FakeActivityPresenter(), history: makeTestHistory(), memory: makeTestMemory(),
                                   microphone: MicrophoneSettings(defaults: fresh()), modeSettings: ModeSettings(defaults: fresh()))
        return (model, provider)
    }

    @Test func thePartsBelongToTheModel() {
        let (model, _) = model()
        #expect(model.debugAudio.host === model && model.tools.host === model)
        #expect(model.pagePhoto.host === model && model.flipCards.host === model)

        // A76: without the switch nothing is kept, and the indicator follows the part.
        #expect(model.testMode == nil && !model.isRecordingDebugAudio)
        model.updateDebugAudio()
        #expect(!model.isRecordingDebugAudio)
        let settings = TestModeSettings(defaults: UserDefaults(suiteName: "g7parts-\(UUID().uuidString)")!)
        model.testMode = settings
        #expect(model.debugAudio.testMode === settings, "the screens set and read the switch through the model")
        model.updateDebugAudio()
        #expect(!model.isRecordingDebugAudio, "the switch is off, and Lumen is not listening")

        // A36 and A46: nothing is being read, and the deck is the part's.
        #expect(model.pagePhotoStatus == nil && !model.isReadingPage)
        model.clearPagePhotoStatus()
        let exam = ExamPlan(grade: .y9, area: .no, subject: "Biologi", date: Date().addingTimeInterval(5 * 86_400), topics: "fotosyntes")
        #expect((model.flipDeck(for: exam) == nil) == (model.flipCards.deck(for: exam) == nil))
    }

    /// A48: a tool that changes something is asked about first; "ja" runs it, and the same question is sent again
    /// with the tool's result.
    @Test func aToolIsAskedAboutRunAndAnsweredInASecondCall() async {
        let (model, provider) = model()
        let fake = FakeTools()
        model.phoneTools = fake
        let call = PhoneToolCall(id: "toolu_1", name: "alarm_set", input: .object(["time": .string("06:30")]),
                                 confirm: "Ska jag ställa ett larm?", kind: "write")
        model.answerToolCall(call)
        #expect(model.pendingToolConfirm == nil, "no question was sent yet, so the call belongs to nothing")

        model.submitText("väck mig halv sju")
        #expect(await waitUntil { provider.requests.count == 1 })
        model.answerToolCall(call)
        #expect(model.pendingToolConfirm == "Ska jag ställa ett larm?" && fake.ran.isEmpty, "asked first, not run")

        model.confirmTool(true)
        #expect(model.pendingToolConfirm == nil)
        #expect(await waitUntil { fake.ran == ["alarm_set"] && provider.requests.count == 2 })
        guard provider.requests.count == 2 else { return }
        #expect(provider.requests[1].context.toolRound?.status == .ok, "the second call carries the tool's result")
        #expect(provider.requests[1].fragment == provider.requests[0].fragment, "the same question")
    }

    @Test func aDeclinedToolIsNotRunAndTheModelIsToldSo() async {
        let (model, provider) = model()
        let fake = FakeTools()
        model.phoneTools = fake
        model.submitText("väck mig halv sju")
        #expect(await waitUntil { provider.requests.count == 1 })
        model.answerToolCall(PhoneToolCall(id: "toolu_2", name: "alarm_set", input: .object([:]),
                                           confirm: "Ska jag ställa ett larm?", kind: "write"))
        model.confirmTool(false)
        #expect(await waitUntil { provider.requests.count == 2 })
        #expect(fake.ran.isEmpty)
        guard provider.requests.count == 2 else { return }
        #expect(provider.requests[1].context.toolRound?.status == .declined)
    }
}
