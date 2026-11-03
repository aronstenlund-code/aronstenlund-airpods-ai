import Foundation
import Testing
@testable import Lumen

@MainActor
@Suite struct AnswerEngineTests {
    private let question = ActivationRequest(query: "roten ur hundra", trigger: .pushToTalk, language: .swedish)

    private var happyEvents: [AnswerEvent] {
        [.meta(AnswerMeta(reconstructedQuestion: "Vad är roten ur hundra?", confidence: 0.96, isQuestion: true)),
         .delta("Roten ur hundra "), .delta("är tio. "), .delta("Det är "), .delta("enkelt."),
         .done(AnswerDone(answered: true, timing: nil, usage: AnswerDone.Usage(inputTokens: 1, outputTokens: 2, model: "claude-haiku-5-5")))]
    }

    @Test func streamsDeltasSentencesAndCompletes() async {
        let provider = FakeAnswerProvider(name: "cloud", events: happyEvents)
        let engine = makeTestAnswerEngine(provider)
        let sink = FakeAnswerSink()
        engine.sink = sink

        engine.answer(question, context: AnswerContext(transcript: "ctx"))
        #expect(engine.status == .answering(query: "roten ur hundra"))
        #expect(await waitUntil { sink.completed.count == 1 })

        #expect(sink.started == [question])
        #expect(sink.sources == ["cloud"])
        #expect(sink.reconstructed == ["Vad är roten ur hundra?"])
        #expect(sink.deltas.joined() == "Roten ur hundra är tio. Det är enkelt.")
        #expect(sink.sentences == ["Roten ur hundra är tio.", "Det är enkelt."])
        #expect(sink.completed[0].done?.usage?.model == "claude-haiku-5-5")
        #expect(sink.completed[0].latencyMs.map { $0 >= 0 } == true)
        #expect(engine.status == .idle)
        #expect(engine.answersCompleted == 1)
        #expect(provider.requests.first?.context.transcript == "ctx")
        #expect(provider.requests.first?.mode == "push_to_talk")
    }

    @Test func notAQuestionIsSkipped() async {
        let provider = FakeAnswerProvider(events: [.meta(AnswerMeta(isQuestion: false)), .done(AnswerDone(answered: false))])
        let engine = makeTestAnswerEngine(provider)
        let sink = FakeAnswerSink()
        engine.sink = sink

        engine.answer(ActivationRequest(query: "idag pratar vi om celler", trigger: .auto, language: .swedish), context: AnswerContext())
        #expect(await waitUntil { sink.skipped.count == 1 })
        #expect(sink.completed.isEmpty)
        #expect(sink.deltas.isEmpty)
        #expect(engine.status == .idle)
    }

    @Test func confirmationQuestionIsNotUsedAsReconstructedQuestion() async {
        let provider = FakeAnswerProvider(events: [
            .meta(AnswerMeta(reconstructedQuestion: "Vad är roten ur hundra?", confidence: 0.4, isQuestion: true, needsConfirmation: true)),
            .delta("Menar du roten ur hundra?"), .done(AnswerDone(answered: true)),
        ])
        let engine = makeTestAnswerEngine(provider)
        let sink = FakeAnswerSink()
        engine.sink = sink
        engine.answer(question, context: AnswerContext())
        #expect(await waitUntil { sink.completed.count == 1 })
        #expect(sink.reconstructed.isEmpty)
        #expect(sink.sentences == ["Menar du roten ur hundra?"])
    }

    @Test func backendFailureIsReportedWithFallbackFlag() async {
        let failure = AnswerFailure(code: "provider_quota", message: "credits exhausted", fallback: true)
        let provider = FakeAnswerProvider(events: [], error: .backend(status: 503, failure: failure))
        let engine = makeTestAnswerEngine(provider)
        let sink = FakeAnswerSink()
        engine.sink = sink

        engine.answer(question, context: AnswerContext())
        #expect(await waitUntil { sink.failures.count == 1 })
        #expect(sink.failures[0].wantsFallback)
        #expect(sink.failures[0].message.contains("provider_quota"))
        #expect(engine.status == .failed(AnswerError.backend(status: 503, failure: failure).localizedDescription))
        #expect(sink.completed.isEmpty)
    }

    @Test func offlineGivesTheInternetMessage() async {
        let provider = FakeAnswerProvider(error: .offline)
        let engine = makeTestAnswerEngine(provider)
        let sink = FakeAnswerSink()
        engine.sink = sink
        engine.answer(question, context: AnswerContext())
        #expect(await waitUntil { sink.failures.count == 1 })
        #expect(sink.failures[0].message == "Answers need an internet connection")
        #expect(sink.failures[0].wantsFallback)
    }

    @Test func newQuestionInterruptsTheCurrentAnswer() async {
        let slow = FakeAnswerProvider(name: "slow", events: happyEvents)
        slow.delay = .milliseconds(150)
        let engine = makeTestAnswerEngine(slow)
        let sink = FakeAnswerSink()
        engine.sink = sink

        engine.answer(question, context: AnswerContext())
        #expect(await waitUntil { sink.deltas.count >= 1 })
        let second = ActivationRequest(query: "vad är pi", trigger: .pushToTalk, language: .swedish)
        slow.delay = .zero
        engine.answer(second, context: AnswerContext())

        #expect(await waitUntil { sink.completed.count == 1 })
        try? await Task.sleep(for: .milliseconds(400))
        #expect(sink.started == [question, second])
        #expect(sink.completed.count == 1, "the interrupted answer never completes")
        #expect(slow.requests.count == 2)
        #expect(await waitUntil { slow.cancellations == 1 })
        #expect(engine.status == .idle)
    }

    @Test func cancelStopsAnAnswerQuietly() async {
        let slow = FakeAnswerProvider(events: happyEvents)
        slow.delay = .milliseconds(200)
        let engine = makeTestAnswerEngine(slow)
        let sink = FakeAnswerSink()
        engine.sink = sink
        engine.answer(question, context: AnswerContext())
        engine.cancel()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(engine.status == .idle)
        #expect(sink.completed.isEmpty)
        #expect(sink.failures.isEmpty)
    }

    @Test func mockSwitchUsesTheMockProvider() async {
        let cloud = FakeAnswerProvider(name: "cloud", events: happyEvents)
        let mock = MockAnswerProvider()
        mock.delayPerChunk = .zero
        let engine = AnswerEngine(provider: cloud, mock: mock)
        let sink = FakeAnswerSink()
        engine.sink = sink
        engine.useMock = true

        engine.answer(question, context: AnswerContext())
        #expect(await waitUntil { sink.completed.count == 1 })
        #expect(sink.sources == ["mock"])
        #expect(cloud.requests.isEmpty)
        #expect(sink.deltas.joined().contains("roten ur hundra"))
        #expect(sink.completed[0].done?.usage?.model == "mock")
    }
}

@MainActor
@Suite struct ListeningAnswerTests {
    private func makeModel(provider: any AnswerProvider) -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback), voices: makeTestVoiceCatalog())
        return (h, model)
    }

    @Test func holdToAskEndsWithAnAnswerInTheHistory() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [
            .meta(AnswerMeta(reconstructedQuestion: "Vad är roten ur hundra?", isQuestion: true)),
            .delta("Tio."), .done(AnswerDone(answered: true)),
        ])
        let (h, model) = makeModel(provider: provider)
        await model.startListening()
        model.receiveFinalTranscript("läraren pratade om kvadratrötter")
        model.pressPushToTalk()
        model.receiveFinalTranscript("roten ur hundra")
        model.releasePushToTalk()

        #expect(await waitUntil { model.conversation.answers.count == 1 })
        #expect(model.conversation.answers[0].question == "Vad är roten ur hundra?")
        #expect(model.conversation.answers[0].answer == "Tio.")
        #expect(model.conversation.answers[0].source == "cloud")
        #expect(model.conversation.streamingAnswer == nil)
        #expect(model.answerNotice == nil)
        #expect(provider.requests.first?.context.transcript.contains("kvadratrötter") == true, "context pack carries the recent transcript")
        #expect(h.controller.eventLog.contains { $0.text.hasPrefix("Answer · first text after") })
    }

    @Test func failureShowsANoticeAndClearsTheStreamingAnswer() async {
        let provider = FakeAnswerProvider(error: .offline)
        let (_, model) = makeModel(provider: provider)
        await model.startListening()
        model.submitText("vad är pi")
        #expect(await waitUntil { model.answerNotice != nil })
        #expect(model.answerNotice == "Answers need an internet connection")
        #expect(model.conversation.streamingAnswer == nil)
        #expect(model.conversation.answers.isEmpty)
    }

    @Test func notAQuestionShowsANotice() async {
        let provider = FakeAnswerProvider(events: [.meta(AnswerMeta(isQuestion: false)), .done(AnswerDone(answered: false))])
        let (_, model) = makeModel(provider: provider)
        await model.startListening()
        model.submitText("idag pratar vi om celler")
        #expect(await waitUntil { model.answerNotice != nil })
        #expect(model.answerNotice == "Not a question — no answer (auto mode)")
    }

    @Test func typedQuestionWorksWithoutTheMicrophone() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [
            .meta(AnswerMeta(reconstructedQuestion: "Vad är pi?", isQuestion: true)),
            .delta("Ungefär 3,14."), .done(AnswerDone(answered: true)),
        ])
        let (h, model) = makeModel(provider: provider)
        #expect(!model.isListening)

        model.draftQuestion = "   "
        #expect(!model.canSendDraft)
        model.sendDraft()
        #expect(model.pendingQuestion == nil)

        model.draftQuestion = " vad är pi "
        #expect(model.canSendDraft)
        model.sendDraft()

        #expect(model.draftQuestion.isEmpty, "the field is cleared on send")
        #expect(model.pendingQuestion?.trigger == .text)
        #expect(model.pendingQuestion?.query == "vad är pi")
        #expect(await waitUntil { model.conversation.answers.count == 1 })
        #expect(model.conversation.answers[0].answer == "Ungefär 3,14.")
        #expect(provider.requests.first?.mode == "text")
        #expect(h.session.permissionRequests == 0, "no microphone involved")
    }

    @Test func stopListeningCancelsTheAnswer() async {
        let slow = FakeAnswerProvider(events: [.delta("x"), .done(AnswerDone(answered: true))])
        slow.delay = .milliseconds(300)
        let (_, model) = makeModel(provider: slow)
        await model.startListening()
        model.submitText("vad är pi")
        #expect(await waitUntil { model.conversation.streamingAnswer != nil })
        await model.stopListening()
        #expect(model.conversation.streamingAnswer == nil)
        try? await Task.sleep(for: .milliseconds(400))
        #expect(model.conversation.answers.isEmpty)
    }
}
