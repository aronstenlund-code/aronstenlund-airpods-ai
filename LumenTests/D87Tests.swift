import Foundation
import Testing
@testable import Lumen

/// D87: Provläge's keyterms from the active exam, the last three turns and the exam id, the study-session recording.
@Suite struct ExamKeytermTests {
    @Test func theExamsWordsComeFirst() {
        var profile = StudyProfile()
        profile.subject = "Biologi"
        profile.course = "Biologi 1"
        profile.topics = "fotosyntes, cellandning och klorofyll; kapitel 4"
        profile.terms = ["mitokondrie", "Fotosyntes", "kloroplast"]
        let exam = ExamKeyterms.terms(profile: profile)
        #expect(exam == ["Biologi", "Biologi 1", "fotosyntes", "cellandning", "klorofyll", "mitokondrie", "kloroplast"],
                "subject, course, topics (not 'kapitel 4'), then Kevin's terms, each once")
        let merged = ExamKeyterms.merged(exam: exam, rest: ["Spara", "biologi", "Fotosyntesen"])
        #expect(Array(merged.prefix(exam.count)) == exam)
        #expect(merged.suffix(2) == ["Spara", "Fotosyntesen"], "the rest after, without repeats")
    }

    @Test func theRequestCarriesTurnsAndTheExam() throws {
        var context = AnswerContext()
        context.recentTurns = (1...5).map { AnswerContext.Turn(text: "tur \($0)", answered: $0 % 2 == 0) }
        context.examID = "E1"
        let request = AnswerRequest(fragment: "vad är klorofyll", mode: "tutor", language: "sv", context: context)
        #expect(request.context.recentTurns.map(\.text) == ["tur 3", "tur 4", "tur 5"], "the last three")
        let json = String(data: CloudAnswerProvider.encodeBody(request), encoding: .utf8) ?? ""
        #expect(json.contains(#""recent_turns":[{"answered":false,"text":"tur 3"}"#))
        #expect(json.contains(#""exam_id":"E1""#))
        let plain = String(data: CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "x", mode: "auto", language: "sv")), encoding: .utf8) ?? ""
        #expect(!plain.contains("recent_turns") && !plain.contains("exam_id"), "only Provläge sends them")
    }

    @Test func theRecordingReadsInTimeOrder() {
        let events = [
            StudyRecordingModel.Event(t: 1.2, kind: "heard", text: "vad är fotosyntes", source: "Scribe"),
            StudyRecordingModel.Event(t: 1.3, kind: "asked", text: "vad är fotosyntes", trigger: "tutor"),
            StudyRecordingModel.Event(t: 2.1, kind: "answered", text: "Växter gör socker.", question: "vad är fotosyntes", firstTextMs: 640, source: "cloud"),
            StudyRecordingModel.Event(t: 62.5, kind: "spoke", text: "Växter gör socker."),
        ]
        let text = StudyRecordingModel.transcript(header: "Lumen plugg-session", events: events, recordedSeconds: 70)
        #expect(text.contains("[00:01.2] HÖRDE (Scribe): vad är fotosyntes"))
        #expect(text.contains("SVAR (cloud, 640 ms till första text)"))
        #expect(text.contains("[01:02.5] SA: Växter gör socker."))
    }
}

@MainActor
@Suite struct ProvlageContextFlowTests {
    @Test func everyProvlageCallCarriesTheLastTurnsAndTheExam() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Bra fråga, det handlar om ljus. "), .done(AnswerDone(answered: true))])
        let defaults = freshTestDefaults()
        let plans = ExamPlanStore(directory: tempDirectory("plans"))
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   study: StudySessionController(settings: StudySettings(defaults: defaults), session: h.controller),
                                   memory: makeTestMemory(), modeSettings: ModeSettings(defaults: defaults),
                                   studyProfile: StudyProfileStore(defaults: defaults), examPlans: plans)
        let plan = ExamPlan(grade: .y9, area: .no, subject: "Biologi", date: Date().addingTimeInterval(5 * 86_400), topics: "fotosyntes")
        plans.save(plan)
        await model.startProv(for: plan)
        #expect(model.study.isActive)

        func turn(_ text: String) async {
            #expect(await waitUntil { model.study.phase == .listening && !model.speaker.isSpeaking })
            try? await Task.sleep(for: .milliseconds(900))
            var time = Date().addingTimeInterval(-3)
            for _ in 0..<15 { model.study.level(-25, at: time); time = time.addingTimeInterval(0.04) }
            model.receiveFinalTranscript(text, at: time)
            for _ in 0..<45 { model.study.level(-70, at: time); time = time.addingTimeInterval(0.04) }
        }
        model.study.level(-70, at: Date())
        await turn("vad är fotosyntes för något")
        #expect(await waitUntil { provider.requests.count == 1 })
        await turn("och var sker den någonstans")
        #expect(await waitUntil { provider.requests.count == 2 })
        guard provider.requests.count == 2 else { return }
        #expect(provider.requests[1].context.examID == plan.id.uuidString)
        #expect(provider.requests[1].context.recentTurns.map(\.text) == ["vad är fotosyntes för något"], "the turn before, not the one asked")
        #expect(provider.requests[1].context.recentTurns.first?.answered == true)
    }
}
