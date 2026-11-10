import Foundation
import Testing
@testable import Lumen

/// A8.4: several questions in one breath become separate turns.
@Suite struct QuestionSplitterTests {
    @Test func aronsBlockBecomesThreeTurns() {
        let text = "vilka är de största bergen i världen fortsätt att du i framtiden bara ska ställa korta svar under en mening "
            + "alltså det är minnet vad är 250×250"
        #expect(QuestionSplitter.split(text) == [
            "vilka är de största bergen i världen",
            "fortsätt att du i framtiden bara ska ställa korta svar under en mening alltså det är minnet",
            "vad är 250×250",
        ])
    }

    @Test func twoQuestionsWithoutPunctuation() {
        #expect(QuestionSplitter.split("vad är fotosyntes hur många ben har en spindel")
            == ["vad är fotosyntes", "hur många ben har en spindel"])
        #expect(QuestionSplitter.split("Vad är pi? Vem skrev Hamlet?") == ["Vad är pi?", "Vem skrev Hamlet?"])
    }

    @Test func oneQuestionStaysWhole() {
        for text in ["kan du förklara hur fotosyntesen fungerar i en växt",
                     "vad är skillnaden mellan mitos och meios",
                     "vad är fotosyntes och hur fungerar den",
                     "jag undrar vad som händer med cellerna när de delar sig",
                     "under kriget som var viktigt för Sverige hände mycket",
                     "hur många invånare har Sverige ungefär",
                     "vet du vad huvudstaden i Australien heter",
                     "vad som helst går bra att svara på här"] {
            #expect(QuestionSplitter.split(text) == [text], "\(text)")
        }
    }

    @Test func shortTextIsNeverSplit() {
        #expect(QuestionSplitter.split("vad är pi vad") == ["vad är pi vad"])
        #expect(QuestionSplitter.split("") == [""])
    }
}

/// A8.3: the Diagnostics export says, per turn, what was sent and what the user got.
@Suite struct TurnLedgerTests {
    @Test func aTurnGoesFromPendingToItsOutcomeOnce() {
        var ledger = TurnLedger()
        let id = ledger.begin(fragment: "vad är pi", mode: "standard", trigger: "auto", transcript: String(repeating: "x", count: 500))
        #expect(ledger.record(id)?.outcome == .pending)
        #expect(ledger.record(id)?.transcriptTail.count == TurnRecord.transcriptTail)
        ledger.setStatus(id, status: "not_question", isQuestion: false)
        ledger.finish(id, outcome: .silent, reason: "backend: not a question")
        ledger.finish(id, outcome: .answered, reason: "later")
        #expect(ledger.record(id)?.outcome == .silent)
        #expect(ledger.record(id)?.reason == "backend: not a question")
        #expect(ledger.record(id)?.isQuestion == false)
    }

    @Test func markdownHasOneRowPerTurnAndASummary() {
        var ledger = TurnLedger()
        let a = ledger.begin(fragment: "vad är pi", mode: "standard", trigger: "auto", ahead: true)
        ledger.setStatus(a, status: "ok", isQuestion: true)
        ledger.finish(a, outcome: .answered)
        ledger.dropped("idag | pratar vi", mode: "standard", trigger: "auto", reason: "question gate 0.00 < 0.50")
        let markdown = ledger.markdown
        #expect(markdown.contains("2 turns · 1 sent · 1 answered"))
        #expect(markdown.contains("| vad är pi | true | ok | answered |"))
        #expect(markdown.contains("idag / pratar vi"), "a pipe would break the table")
    }

    @Test func theLedgerIsCapped() {
        var ledger = TurnLedger()
        for i in 0..<(TurnLedger.limit + 10) { ledger.begin(fragment: "q\(i)", mode: "standard", trigger: "auto") }
        #expect(ledger.records.count == TurnLedger.limit)
        #expect(ledger.records.first?.fragment == "q10")
    }
}

@MainActor
@Suite struct FragorTurnTests {
    private func makeModel(_ provider: FakeAnswerProvider) -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let suite = "lumen.tests.a8.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   modeSettings: ModeSettings(defaults: defaults))
        return (h, model)
    }

    @Test func everyTurnHasARowWithItsOutcome() async {
        let provider = FakeAnswerProvider(events: [.meta(AnswerMeta(isQuestion: true)), .delta("Fyrtiosex."), .done(AnswerDone(answered: true))])
        let (h, model) = makeModel(provider)
        await model.startListening()
        model.receiveFinalTranscript("idag pratar vi om celler och hur de delar sig")
        model.receiveFinalTranscript("hur många kromosomer har en människa?")

        #expect(await waitUntil { h.controller.turns.records.last?.outcome == .answered })
        let rows = h.controller.turns.records
        #expect(rows.map(\.outcome) == [.dropped, .answered])
        #expect(rows[1].fragment == "hur många kromosomer har en människa?")
        #expect(rows[1].status == "ok")
        #expect(rows[1].isQuestion == true)
        #expect(rows[0].reason?.hasPrefix("question gate") == true)
    }

    @Test func notAQuestionIsSilentInTheExport() async {
        let provider = FakeAnswerProvider(events: [.meta(AnswerMeta(isQuestion: false)), .done(AnswerDone(answered: false))])
        let (h, model) = makeModel(provider)
        await model.startListening()
        model.receiveFinalTranscript("hur många invånare har") // A21: "vilka är de största" waits for its rest now

        #expect(await waitUntil { h.controller.turns.records.last?.outcome == .silent })
        #expect(h.controller.turns.records.last?.status == "not_question")
        #expect(h.controller.turns.records.last?.isQuestion == false)
    }

    /// A8.2 end to end: the first half is "not a question"; the rest arrives and the whole question is sent.
    @Test func theRestOfAQuestionIsSentWithItsStart() async {
        let provider = FakeAnswerProvider(events: [.meta(AnswerMeta(isQuestion: false)), .done(AnswerDone(answered: false))])
        let (h, model) = makeModel(provider)
        await model.startListening()
        model.receiveFinalTranscript("hur många invånare har")
        #expect(await waitUntil { h.controller.turns.records.last?.outcome == .silent })

        provider.events = [.meta(AnswerMeta(isQuestion: true)), .delta("Cirka 10,5 miljoner."), .done(AnswerDone(answered: true))]
        model.receiveFinalTranscript("Sverige ungefär")

        #expect(await waitUntil { h.controller.turns.records.last?.outcome == .answered })
        #expect(provider.requests.map(\.fragment) == ["hur många invånare har", "hur många invånare har Sverige ungefär"])
    }
}
