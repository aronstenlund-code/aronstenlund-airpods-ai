import Foundation
import Testing
@testable import Lumen

/// A154 (D239, D241; Oscar O90, Kevin K109/K110): Nytt prov never proposes an exam that the credits do not cover.
/// The standard is 12 questions; the server says no before it makes anything, with how many questions fit
/// (`fits`, an upper bound) and the fewest an exam has (`min_questions`); fewer than that, and Nytt prov says so with
/// "Fyll på". And a welcome the server is not set up for (503) is not one of the three tries.
/// Fake replies only: no model call, no sound, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A154ExamRoomTests {
    // MARK: The standard

    @Test func theStandardIsTwelveQuestions() {
        #expect(Drill.defaultQuestionCount == 12)
        #expect(DrillSettings().questions == 12)
        #expect(DrillQuota(used: 0, limit: 40).suggestedQuestions == 12, "never more than the standard")
        #expect(DrillSettings.questionRange.contains(12))
    }

    // MARK: The server's no before it makes anything

    /// Kevin's live reply (K110, run 44591156654): a new account with 1 500 credits asks for 12 questions.
    static let noToTwelve = #"""
    {"error":{"code":"quota_exceeded","message":"Ett prov med 12 frågor kostar cirka 7 704 krediter. Du har 1 500 kvar, det räcker inte till ett prov (minst 3 frågor). Nya krediter den 1 december.","fallback":false},
     "unit":"chars","used":0,"limit":1500,"left":1500,"remaining":1500,"per":"month","resets":"2026-12-01",
     "cost":7704,"needed":7704,"estimated":true,"fits":2,"per_question":642,"questions":12,"min_questions":3}
    """#

    @Test func theNoSaysHowManyQuestionsFit() {
        let error = DrillClient.refusal(status: 402, data: Data(Self.noToTwelve.utf8))
        guard case .tooFewCredits(let no) = error else {
            Issue.record("a 402 with `fits` is the credits' no, got \(error)")
            return
        }
        #expect(no.fits == 2 && no.minQuestions == 3 && no.perQuestion == 642 && no.cost == 7704 && no.left == 1500)
        #expect(no.message.hasPrefix("Ett prov med 12 frågor kostar cirka 7 704 krediter."))
        #expect(!no.canMakeAnExam, "fewer than three fit: no exam")
        #expect(error.userMessage == no.message, "the server's own words")
    }

    @Test func aNoWithoutFitsIsAsBefore() {
        // A month that is used up (K61), and a rate limit: the server's message, nothing about how many fit.
        let usedUp = #"{"error":{"code":"quota_exceeded","message":"Du har inga krediter kvar den här månaden."},"left":0}"#
        #expect(DrillClient.refusal(status: 402, data: Data(usedUp.utf8)) == .refused("Du har inga krediter kvar den här månaden."))
        let limit = #"{"error":{"code":"rate_limited","message":"För många prov. Vänta en minut."}}"#
        #expect(DrillClient.refusal(status: 429, data: Data(limit.utf8)) == .refused("För många prov. Vänta en minut."))
        #expect(DrillClient.refusal(status: 500, data: Data()) == .server("HTTP 500"))
    }

    @Test func aNoWithoutMinQuestionsCountsThree() {
        // K109 before K110: `fits` without `min_questions`.
        let json = #"{"error":{"code":"quota_exceeded","message":"Det räcker till 5 frågor."},"remaining":3000,"fits":5,"per_question":492}"#
        guard case .tooFewCredits(let no) = DrillClient.refusal(status: 402, data: Data(json.utf8)) else {
            Issue.record("a 402 with `fits`")
            return
        }
        #expect(no.fits == 5 && no.minQuestions == 3 && no.canMakeAnExam && no.left == 3000)
    }

    // MARK: What the credits cover

    @Test func theRoomCountsWhatFits() {
        let room = ExamRoom(perQuestion: 642, minQuestions: 3, longWords: 90)
        #expect(room.fits(left: 1500) == 2 && !room.canMakeAnExam(left: 1500))
        #expect(room.fits(left: 6500) == 10 && room.canMakeAnExam(left: 6500), "1 500 + the welcome's 5 000")
        #expect(room.fits(left: 1926) == 3 && room.canMakeAnExam(left: 1926))
        #expect(room.fits(left: 0) == 0 && room.fits(left: -5) == 0)
        // The room of a no: the server's own number per question, or counted from what fits.
        let no = ExamRefusal(message: "", fits: 2, minQuestions: 3, perQuestion: nil, cost: nil, left: 1500)
        #expect(ExamRoom(no, longWords: 90)?.fits(left: 1500) == 2, "750 a question when the server gave no number")
        let none = ExamRefusal(message: "", fits: 0, minQuestions: 3, perQuestion: nil, cost: nil, left: 400)
        #expect(ExamRoom(none, longWords: 90)?.fits(left: 400) == 0)
        #expect(ExamRoom(ExamRefusal(message: "", fits: 2, minQuestions: 3, perQuestion: nil, cost: nil, left: nil), longWords: 90) == nil)
    }

    @Test func theQuotaCanSayWhatAQuestionCosts() throws {
        // Asked of Kevin (not live yet): `/drill quota` with `long_words` answers with `exam`.
        let json = #"{"unit":"chars","used":0,"limit":1500,"remaining":1500,"exam":{"per_question":642,"min_questions":3,"long_words":90}}"#
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(json.utf8))
        #expect(quota.exam?.per_question == 642 && quota.exam?.min_questions == 3 && quota.exam?.long_words == 90)
        let old = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"unit":"chars","used":0,"limit":1500,"remaining":1500}"#.utf8))
        #expect(old.exam == nil, "today's server: known first at Skapa frågor")
    }

    // MARK: Nytt prov

    /// A maker that says the credits' no, as the server does before it makes anything.
    @MainActor final class RefusingMaker: DrillMaking {
        var no: ExamRefusal?
        var asked: [Int] = []
        let mock = MockDrillMaker()

        func make(_ material: DrillMaterial, subject: String?, grade: String?, correction: String?,
                  questions: Int, longWords: Int) async throws(DrillMakingError) -> DrillDraft {
            asked.append(questions)
            if let no, questions > no.fits { throw .tooFewCredits(no) }
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
            try await mock.readText(material, subject: subject, grade: grade, title: title)
        }
        func fetchPage(_ address: String) async throws(DrillMakingError) -> FetchedPage { try await mock.fetchPage(address) }
    }

    func model(_ name: String, maker: RefusingMaker) throws -> RepetitionModel {
        let folder = try A79A81RepetitionTests.folder(name)
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let defaults = try #require(UserDefaults(suiteName: "\(name)-\(UUID())")) // its own, so the length set in one test stays there
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() }, makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: defaults, activatesAudioSession: false)
        return RepetitionModel(store: store, session: session, maker: maker, audio: audio,
                               sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud, defaults: defaults)
    }

    static func credits(_ left: Int) -> DrillQuota {
        var quota = DrillQuota(used: 0, limit: 1500, per: "month", resets: "2026-12-01")
        quota.unit = "chars"
        quota.remaining = left
        quota.resets_day = "1 december"
        return quota
    }

    @Test func nyttProvProposesTwelveUntilTheServerSaysWhatFits() throws {
        let model = try model("a154-standard", maker: RefusingMaker())
        #expect(model.newDrillSettings.questions == 12, "no quota known: the standard")
        model.quota = Self.credits(1500)
        #expect(model.newDrillSettings.questions == 12 && model.newDrillFits == nil, "the server has not said what a question costs")
        #expect(model.newDrillQuestionRange == DrillSettings.questionRange && !model.newDrillHasNoRoom)
        #expect(model.newDrillRoomLine == nil)
    }

    @Test func afterTheNoNyttProvProposesWhatFits() async throws {
        let maker = RefusingMaker()
        maker.no = ExamRefusal(message: "Ett prov med 12 frågor kostar cirka 7 704 krediter. Du har 3 300 kvar, det räcker till 5 frågor.",
                               fits: 5, minQuestions: 3, perQuestion: 642, cost: 7704, left: 3300)
        let model = try model("a154-fits", maker: maker)
        model.quota = Self.credits(3300)
        let material = DrillMaterial(text: "Fotosyntes. Växter gör socker av koldioxid och vatten.")
        let no = try #require(maker.no)
        await #expect(throws: DrillMakingError.tooFewCredits(no)) {
            _ = try await model.make(material, settings: model.newDrillSettings)
        }
        #expect(maker.asked == [12])
        // The model has kept what the server said: five fit, so five are proposed and no more can be chosen.
        #expect(model.newDrillFits == 5 && !model.newDrillHasNoRoom)
        #expect(model.newDrillSettings.questions == 5)
        #expect(model.newDrillQuestionRange == 3...5)
        #expect(model.newDrillRoomLine == "Krediterna räcker till 5 frågor.")
        // With what fits, the exam is made.
        let draft = try await model.make(material, settings: model.newDrillSettings)
        #expect(draft.items.count == 5 && maker.asked == [12, 5])
        // More credits (Fyll på): what fits is counted again from the same price per question.
        model.quota = Self.credits(8300)
        #expect(model.newDrillFits == 12 && model.newDrillSettings.questions == 12, "the standard again, not more")
        #expect(model.newDrillQuestionRange == 3...12 && model.newDrillRoomLine == nil)
    }

    @Test func fewerThanThreeIsSaidWithFyllPa() async throws {
        let maker = RefusingMaker()
        maker.no = ExamRefusal(message: "Ett prov med 12 frågor kostar cirka 7 704 krediter. Du har 1 500 kvar, det räcker inte till ett prov (minst 3 frågor).",
                               fits: 2, minQuestions: 3, perQuestion: 642, cost: 7704, left: 1500)
        let model = try model("a154-none", maker: maker)
        model.quota = Self.credits(1500)
        await #expect(throws: DrillMakingError.self) {
            _ = try await model.make(DrillMaterial(text: "Fotosyntes."), settings: model.newDrillSettings)
        }
        #expect(model.newDrillHasNoRoom, "said in Nytt prov, with Fyll på, instead of proposing an exam")
        #expect(model.newDrillRoomLine == "Du har 1,5k krediter. Det räcker inte till ett prov (minst 3 frågor).")
        #expect(model.newDrillQuestionRange == DrillSettings.questionRange, "nothing to choose between")
        // The welcome's 5 000 come: ten fit, and the standard is not above that.
        model.quota = Self.credits(6500)
        #expect(!model.newDrillHasNoRoom && model.newDrillFits == 10 && model.newDrillSettings.questions == 10)
        // An account without a limit is never told no.
        var owner = Self.credits(0)
        owner.unlimited = true
        model.quota = owner
        #expect(!model.newDrillHasNoRoom && model.newDrillFits == nil && model.newDrillSettings.questions == 12)
    }

    @Test func anotherLengthOfTheAnswersIsAnotherPrice() async throws {
        let maker = RefusingMaker()
        maker.no = ExamRefusal(message: "", fits: 2, minQuestions: 3, perQuestion: 642, cost: 7704, left: 1500)
        let model = try model("a154-length", maker: maker)
        model.quota = Self.credits(1500)
        _ = try? await model.make(DrillMaterial(text: "Fotosyntes."), settings: model.newDrillSettings)
        #expect(model.newDrillHasNoRoom)
        model.longAnswerLength = .shorter // Inställningar › Avancerat: shorter answers cost less per question
        #expect(!model.newDrillHasNoRoom && model.newDrillFits == nil, "not known for this length until the server says it")
    }

    @Test func theCostIsAskedBeforeTheExamIsSaved() {
        // "Annars kostnaden före sparandet": the server's exact number against what is left.
        #expect(ExamRoom.covers(cost: DrillCost(cost: 1594, remaining: 1500), left: 1500) == false)
        #expect(ExamRoom.covers(cost: DrillCost(cost: 1594, remaining: 6500), left: 1500) == true, "the server's own number of what is left")
        #expect(ExamRoom.covers(cost: DrillCost(cost: 1500), left: 1500) == true)
        #expect(ExamRoom.covers(cost: DrillCost(cost: 1594, enough: true), left: 0) == true, "the server says it is enough (the weekly card)")
        #expect(ExamRoom.covers(cost: nil, left: 0) == true, "no answer: the server decides at the save, as before")
    }

    // MARK: The welcome (K109: 503 `attest_unconfigured`)

    @Test func aWelcomeTheServerIsNotSetUpForIsNotATry() async throws {
        let defaults = try #require(UserDefaults(suiteName: "a154-welcome-\(UUID())"))
        let server = A134ShopTests.FakeServer()
        let attest = A134ShopTests.FakeAttest()
        // Before the Team ID is on the server, the welcome itself answers 503. Five starts of the app:
        server.welcomeError = .refused(status: 503, code: "attest_unconfigured", message: "Inte tillgängligt än.")
        for _ in 0..<5 { await CreditShop(front: A134ShopTests.FakeFront(), server: server, attest: attest, defaults: defaults).claimWelcome() }
        #expect(defaults.integer(forKey: CreditShop.welcomeTriesKey) == 0, "none of the three tries is used")
        #expect(server.challenges == 5 && !defaults.bool(forKey: CreditShop.welcomeDoneKey))
        #expect(defaults.string(forKey: CreditShop.attestKeyKey) == nil, "the key was attested once, so the next start makes a new one")
        // Without a network it is not a try either.
        server.welcomeError = .offline("timed out")
        await CreditShop(front: A134ShopTests.FakeFront(), server: server, attest: attest, defaults: defaults).claimWelcome()
        #expect(defaults.integer(forKey: CreditShop.welcomeTriesKey) == 0)
        // The server is set up: the welcome comes at the next start.
        server.welcomeError = nil
        await CreditShop(front: A134ShopTests.FakeFront(), server: server, attest: attest, defaults: defaults).claimWelcome()
        #expect(server.welcomes.count == 1 && defaults.bool(forKey: CreditShop.welcomeDoneKey))
    }

    @Test func aRealNoIsStillATry() async throws {
        let defaults = try #require(UserDefaults(suiteName: "a154-welcome-no-\(UUID())"))
        let server = A134ShopTests.FakeServer()
        let attest = A134ShopTests.FakeAttest()
        server.welcomeError = .refused(status: 403, code: "attest_invalid", message: "Det gick inte.")
        for _ in 0..<5 { await CreditShop(front: A134ShopTests.FakeFront(), server: server, attest: attest, defaults: defaults).claimWelcome() }
        #expect(defaults.integer(forKey: CreditShop.welcomeTriesKey) == CreditShop.maxWelcomeTries && server.challenges == 3)
        #expect(CreditShop.isNotATry(.refused(status: 503, code: "attest_unconfigured", message: "")))
        #expect(CreditShop.isNotATry(.refused(status: 429, code: "rate_limited", message: "")) && CreditShop.isNotATry(.offline("")))
        #expect(!CreditShop.isNotATry(.refused(status: 403, code: "attest_invalid", message: "")))
        #expect(!CreditShop.isNotATry(.refused(status: 409, code: "welcome_given", message: "")))
    }

    @Test func triesUsedBeforeTheServerWasSetUpAreForgotten() async throws {
        // An installation from before the Team ID: its three tries went to 503s (counted then). They are counted
        // anew, so it gets the welcome later.
        let defaults = try #require(UserDefaults(suiteName: "a154-welcome-old-\(UUID())"))
        defaults.set(3, forKey: "credits.welcomeTries")
        let server = A134ShopTests.FakeServer()
        let attest = A134ShopTests.FakeAttest()
        await CreditShop(front: A134ShopTests.FakeFront(), server: server, attest: attest, defaults: defaults).claimWelcome()
        #expect(server.welcomes.count == 1 && defaults.bool(forKey: CreditShop.welcomeDoneKey))
    }
}
