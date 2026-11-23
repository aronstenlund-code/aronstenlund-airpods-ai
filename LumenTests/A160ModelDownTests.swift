import Foundation
import Testing
@testable import Lumen

/// A160 (D258, Aron 2026-11-23): the app works as far as it can when the model behind EarMind cannot answer
/// (503 `provider_*`: out of credits, busy, down). Saved quizzes are practised as before; an answer is graded by the
/// phone's own model when it is there and knows the language, and otherwise the answer key is shown with one short
/// line about why; a new quiz cannot be made, and the button says so instead of an error.
/// A pretend server and a pretend grader only: no model call, no sound, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A160ModelDownTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    static let down = #"{"error":{"code":"provider_quota","message":"LLM credits exhausted","fallback":true}}"#
    static let task = ExamTask(no: "2", text: "Vad gör klorofyllet?", points: ExamTask.Points(E: 2, C: 0, A: 0),
                               answer: "Det fångar ljusets energi.", assessment: "Ljus och energi ska nämnas.")

    /// The pretend grader: what it is asked, and the grade it gives.
    final class PretendGrader: AnswerGrading, @unchecked Sendable {
        // @unchecked: the tests drive it from the main actor only.
        var languages: Set<TranscriptionLanguage> = [.swedish, .english]
        var result: LocalGrade? = LocalGrade(verdict: .right, sentence: "Du fick med att klorofyllet fångar ljuset.")
        private(set) var asked: [(question: String, key: String, answer: String, language: TranscriptionLanguage)] = []

        func isAvailable(for language: TranscriptionLanguage) -> Bool { languages.contains(language) }
        func grade(question: String, key: String, answer: String, language: TranscriptionLanguage) async -> LocalGrade? {
            asked.append((question, key, answer, language))
            return result
        }
    }

    private func client(_ http: FakeHTTP, grader: PretendGrader?) -> ExamClient {
        let valid = SupabaseSession(accessToken: "jwt", refreshToken: "r1", expiresAt: t0.addingTimeInterval(3600))
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(valid), http: http, now: { [t0] in t0 })
        return ExamClient(config: config, auth: auth, http: http, grader: grader)
    }

    // MARK: The answer is graded on the phone

    @Test func thePhonesModelGradesWhenTheServersModelIsDown() async throws {
        let http = FakeHTTP([.init(status: 503, body: Self.down)])
        let grader = PretendGrader()
        let graded = try #require(await client(http, grader: grader).grade(task: Self.task, answer: "Det fångar ljuset.", practice: true))
        #expect(graded.by == .phone && !graded.isKeyOnly)
        #expect(graded.points == Self.task.points && graded.max == Self.task.points) // right: all the points
        #expect(graded.feedback == "Telefonens modell: Rätt. Du fick med att klorofyllet fångar ljuset.")
        #expect(grader.asked.count == 1)
        #expect(grader.asked.first?.question == "Vad gör klorofyllet?" && grader.asked.first?.key == "Det fångar ljusets energi.")
        #expect(grader.asked.first?.answer == "Det fångar ljuset." && grader.asked.first?.language == .swedish)
        // One call to the server (its no). Nothing more is sent, so nothing can be counted.
        #expect(http.requests.count == 1)
    }

    @Test func partlyGivesHalfAndWrongGivesNothingAndBothSayTheKey() async throws {
        let grader = PretendGrader()
        grader.result = LocalGrade(verdict: .partly, sentence: "Energin saknas.")
        var graded = try #require(await client(FakeHTTP([.init(status: 503, body: Self.down)]), grader: grader)
            .grade(task: Self.task, answer: "Det är grönt och fångar ljus.", practice: true))
        #expect(graded.points == ExamTask.Points(E: 1, C: 0, A: 0) && graded.max == Self.task.points)
        #expect(graded.feedback == "Telefonens modell: Delvis rätt. Energin saknas. Facit: Det fångar ljusets energi.")
        grader.result = LocalGrade(verdict: .wrong, sentence: "Klorofyll är inte en rot.")
        graded = try #require(await client(FakeHTTP([.init(status: 502, body: Self.down.replacingOccurrences(of: "provider_quota", with: "provider_unavailable"))]),
                                           grader: grader).grade(task: Self.task, answer: "Det är en rot.", practice: true))
        #expect(graded.by == .phone && graded.points == .zero)
        #expect(graded.feedback == "Telefonens modell: Inte rätt. Klorofyll är inte en rot. Facit: Det fångar ljusets energi.")
    }

    @Test func theGradeIsInTheLanguageThatIsSpoken() async throws {
        let grader = PretendGrader()
        grader.result = LocalGrade(verdict: .right, sentence: "You named the light.")
        let graded = try #require(await client(FakeHTTP([.init(status: 503, body: Self.down)]), grader: grader)
            .grade(task: Self.task, answer: "It captures light.", practice: true, language: .english))
        #expect(graded.feedback == "The phone's model: Right. You named the light.")
        #expect(grader.asked.first?.language == .english)
    }

    /// A task without points (a practice paper) is still right, partly or wrong in the run.
    @Test func aTaskWithoutPointsIsStillRightPartlyOrWrong() async throws {
        var task = Self.task
        task.points = .zero
        let grader = PretendGrader()
        grader.result = LocalGrade(verdict: .partly, sentence: "Energin saknas.")
        let graded = try #require(await client(FakeHTTP([.init(status: 503, body: Self.down)]), grader: grader)
            .grade(task: task, answer: "Ljus.", practice: true))
        let max = try #require(graded.max)
        #expect(max.total == 1 && graded.points.total == 0.5)
        let outcome = PracticeRun.Outcome(points: graded.points.total, max: max.total)
        #expect(outcome.isPartly && !outcome.isRight)
    }

    // MARK: No model on the phone: the answer key, and one line about why

    @Test func withoutAModelOnThePhoneTheKeyIsShownWithOneLine() async throws {
        let grader = PretendGrader()
        grader.languages = [] // no Apple Intelligence, or it is turned off
        let http = FakeHTTP([.init(status: 503, body: Self.down)])
        let graded = try #require(await client(http, grader: grader).grade(task: Self.task, answer: "Det fångar ljuset.", practice: true))
        #expect(graded.isKeyOnly && graded.points == .zero)
        #expect(graded.feedback == "Facit visas – rättningen är tillbaka när EarMind kan svara igen. Facit: Det fångar ljusets energi.")
        #expect(grader.asked.isEmpty && http.requests.count == 1)
        // The same without a grader at all, and in English.
        let english = try #require(await client(FakeHTTP([.init(status: 503, body: Self.down)]), grader: nil)
            .grade(task: Self.task, answer: "x", practice: true, language: .english))
        #expect(english.isKeyOnly)
        #expect(english.feedback == "Showing the answer – grading is back when EarMind can answer again. Answer: Det fångar ljusets energi.")
    }

    @Test func aModelThatDoesNotKnowTheLanguageOrFailsAlsoGivesTheKey() async throws {
        let swedishOnly = PretendGrader()
        swedishOnly.languages = [.swedish]
        let english = try #require(await client(FakeHTTP([.init(status: 503, body: Self.down)]), grader: swedishOnly)
            .grade(task: Self.task, answer: "x", language: .english))
        #expect(english.isKeyOnly && swedishOnly.asked.isEmpty)
        let failing = PretendGrader()
        failing.result = nil // the phone's model gave nothing
        let graded = try #require(await client(FakeHTTP([.init(status: 503, body: Self.down)]), grader: failing)
            .grade(task: Self.task, answer: "x"))
        #expect(graded.isKeyOnly && failing.asked.count == 1)
        // A task without a key says so.
        var bare = Self.task
        bare.answer = ""
        let none = try #require(await client(FakeHTTP([.init(status: 503, body: Self.down)]), grader: nil).grade(task: bare, answer: "x"))
        #expect(none.feedback == "Facit visas – rättningen är tillbaka när EarMind kan svara igen. Den här frågan har inget facit.")
    }

    // MARK: What must not change

    @Test func theServersGradeIsUsedWhenItAnswers() async throws {
        let http = FakeHTTP([.init(status: 200, body: #"{"points":{"E":2,"C":0,"A":0},"max":{"E":2,"C":0,"A":0},"feedback":"Rätt."}"#)])
        let grader = PretendGrader()
        let graded = try #require(await client(http, grader: grader).grade(task: Self.task, answer: "Det fångar ljuset."))
        #expect(graded.by == nil && !graded.isKeyOnly && graded.feedback == "Rätt." && grader.asked.isEmpty)
    }

    @Test func anotherFaultIsStillNoGrade() async {
        let grader = PretendGrader()
        let internalFault = FakeHTTP([.init(status: 500, body: #"{"error":{"code":"internal","message":"boom"}}"#)])
        #expect(await client(internalFault, grader: grader).grade(task: Self.task, answer: "x") == nil)
        let limit = FakeHTTP([.init(status: 429, body: #"{"error":{"code":"rate_limited","message":"Vänta."}}"#)])
        #expect(await client(limit, grader: grader).grade(task: Self.task, answer: "x") == nil)
        #expect(grader.asked.isEmpty, "the phone grades only when the server says its model is down")
    }

    // MARK: A new quiz cannot be made, and the button says so

    /// The server's no to a new quiz, as the model sees it.
    @MainActor final class DownMaker: DrillMaking {
        var isDown = true
        let mock = MockDrillMaker()

        func make(_ material: DrillMaterial, subject: String?, grade: String?, correction: String?,
                  questions: Int, longWords: Int) async throws(DrillMakingError) -> DrillDraft {
            if isDown { throw DrillClient.refusal(status: 503, data: Data(A160ModelDownTests.down.utf8)) }
            return try await mock.make(material, subject: subject, grade: grade, correction: correction, questions: questions, longWords: longWords)
        }
        func answers(for items: [DrillItem], summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> [DrillItem] {
            try await mock.answers(for: items, summary: summary, notes: notes, longWords: longWords)
        }
        func answer(_ question: String, summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> DrillItem {
            try await mock.answer(question, summary: summary, notes: notes, longWords: longWords)
        }
        func documentText(docx: Data) async throws(DrillMakingError) -> String { try await mock.documentText(docx: docx) }
        func readText(_ material: DrillMaterial, subject: String?, grade: String?, title: String?) async throws(DrillMakingError) -> DrillTextDraft {
            if isDown { throw DrillClient.refusal(status: 503, data: Data(A160ModelDownTests.down.utf8)) }
            return try await mock.readText(material, subject: subject, grade: grade, title: title)
        }
        func fetchPage(_ address: String) async throws(DrillMakingError) -> FetchedPage { try await mock.fetchPage(address) }
    }

    private func model(_ name: String, maker: DownMaker) throws -> RepetitionModel {
        let folder = try A79A81RepetitionTests.folder(name)
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let defaults = try #require(UserDefaults(suiteName: "\(name)-\(UUID())"))
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() }, makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: defaults, activatesAudioSession: false)
        return RepetitionModel(store: store, session: session, maker: maker, audio: audio,
                               sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud, defaults: defaults)
    }

    @Test func theServersNoIsKnownAsTheModelBeingDown() {
        for code in ["provider_quota", "provider_busy", "provider_unconfigured", "provider_unavailable"] {
            let body = Data(Self.down.replacingOccurrences(of: "provider_quota", with: code).utf8)
            let error = DrillClient.refusal(status: 503, data: body)
            #expect(error == .modelDown, "\(code)")
            #expect(error.userMessage == "EarMind kan inte svara just nu. Försök igen om en stund.") // O97's line stays
        }
        let limit = Data(#"{"error":{"code":"rate_limited","message":"Vänta."}}"#.utf8)
        #expect(DrillClient.refusal(status: 429, data: limit) == .refused("Vänta."))
    }

    @Test func theButtonSaysThatNewQuizzesCannotBeMadeAndSavedOnesStillStart() async throws {
        let maker = DownMaker()
        let model = try model("a160-down", maker: maker)
        // A saved quiz from before.
        let saved = model.save(Drill(title: "Biologiprovet", summary: DrillSummary(subject: "Biologi", grade: "åk 8", covers: ""),
                                     items: [DrillItem(question: "Vad gör klorofyllet?", short: "Det fångar ljuset.", long: "Det fångar ljuset.")],
                                     questionCount: 1))
        #expect(!model.modelIsDown() && NewQuizText.title(down: false, base: "Skapa frågor") == "Skapa frågor")
        let before = model.canStart(saved)
        // The model is down: nothing is made.
        let started = Date(timeIntervalSince1970: 1_800_000_000)
        await #expect(throws: DrillMakingError.modelDown) {
            _ = try await model.make(DrillMaterial(text: "Fotosyntes."), settings: model.newDrillSettings, now: started)
        }
        #expect(model.modelIsDown(now: started.addingTimeInterval(5)))
        #expect(NewQuizText.title(down: true, base: "Skapa frågor") == "Kan inte skapa prov just nu")
        #expect(NewQuizText.downNote == "Sparade prov går att öva. Försök igen om en stund.")
        // The saved quiz is where it was and starts as before: practising does not need the model.
        #expect(model.drills.contains { $0.id == saved.id } && model.canStart(saved) == before)
        // A while later the button is itself again, and a quiz that is made clears it at once.
        #expect(!model.modelIsDown(now: started.addingTimeInterval(RepetitionModel.modelDownWindow + 1)))
        _ = try? await model.make(DrillMaterial(text: "Fotosyntes."), settings: model.newDrillSettings, now: started.addingTimeInterval(10))
        #expect(model.modelIsDown(now: started.addingTimeInterval(20)))
        maker.isDown = false
        _ = try await model.make(DrillMaterial(text: "Fotosyntes."), settings: model.newDrillSettings, now: started.addingTimeInterval(30))
        #expect(!model.modelIsDown(now: started.addingTimeInterval(31)))
    }

    @Test func aReadAloudTextAlsoKnowsTheModelIsDown() async throws {
        let model = try model("a160-read", maker: DownMaker())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        await #expect(throws: DrillMakingError.modelDown) {
            _ = try await model.readText(DrillMaterial(text: "Fotosyntes."), now: now)
        }
        #expect(model.modelIsDown(now: now.addingTimeInterval(1)))
    }

    // MARK: The words, in both languages

    @Test func theNewWordsAreInBothLanguages() {
        func text(_ key: String, _ language: AppLanguage) -> String {
            language.bundle.localizedString(forKey: key, value: "(missing)", table: nil)
        }
        #expect(text("Kan inte skapa prov just nu", .en) == "Can't create quizzes right now")
        #expect(text("Sparade prov går att öva. Försök igen om en stund.", .en) == "Saved quizzes still work. Try again in a moment.")
        #expect(text("Kan inte skapa prov just nu", .sv) == "Kan inte skapa prov just nu")
    }
}
