import Foundation
import Testing
@testable import Lumen

/// A168 (Deangelo 2026-11-27): the repetition easier to come back to. After Avsluta a short summary says what was
/// heard and offers the questions whose answer was asked for; Start shows the quiz played last at the top; a said
/// text plays again with one tap (in the view). Pretend player and pretend files only: nothing is sent, 0 ElevenLabs.
@MainActor
@Suite struct A168ComingBackTests {
    private func session(_ name: String, source: A78RepetitionTests.MockSource, timer: A78RepetitionTests.MockTimer)
        throws -> (RepetitionSession, UserDefaults) {
        let defaults = try #require(UserDefaults(suiteName: "\(name)-\(UUID())"))
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { timer },
                                        defaults: defaults, activatesAudioSession: false)
        return (session, defaults)
    }

    private func model(_ name: String, session: RepetitionSession, defaults: UserDefaults) throws -> (RepetitionModel, DrillStore) {
        let folder = try A79A81RepetitionTests.folder(name)
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud, defaults: defaults)
        return (model, store)
    }

    /// Plays five questions: the answer is asked for at the first (1 press) and the third (2 presses).
    private func playFive(_ session: RepetitionSession, _ drill: Drill, source: A78RepetitionTests.MockSource,
                          timer: A78RepetitionTests.MockTimer) {
        session.start(drill, tracks: A78RepetitionTests.tracks(5))
        source.last.finish()          // question 1 heard
        session.press(.long)          // its answer asked for
        source.last.finish()          // the answer ends: question 2
        source.last.finish()          // question 2 heard
        timer.fire()                  // no press: question 3
        source.last.finish()          // question 3 heard
        session.press(.short)         // its short answer asked for
        source.last.finish()          // question 4
        source.last.finish()          // question 4 heard
        timer.fire()
    }

    // MARK: The summary after Avsluta

    @Test func theRunRemembersWhatWasHeardAndWhichAnswersWereAskedFor() throws {
        let source = A78RepetitionTests.MockSource(), timer = A78RepetitionTests.MockTimer()
        let (session, _) = try session("a168-run", source: source, timer: timer)
        let drill = A79A81RepetitionTests.bio(5)
        playFive(session, drill, source: source, timer: timer)
        session.stop()
        let run = try #require(session.lastRun)
        #expect(run.drill.id == drill.id)
        #expect(run.heard == 4)
        #expect(run.asked == [0, 2])
    }

    @Test func avslutaGivesASummaryWithTheMissedQuestions() throws {
        let source = A78RepetitionTests.MockSource(), timer = A78RepetitionTests.MockTimer()
        let (session, defaults) = try session("a168-end", source: source, timer: timer)
        let (model, _) = try model("a168-end", session: session, defaults: defaults)
        let drill = model.save(A79A81RepetitionTests.bio(5))
        playFive(session, drill, source: source, timer: timer)
        model.end()
        let summary = try #require(model.practiceSummary)
        #expect(summary.heard == 4 && summary.originID == drill.id && summary.places == [0, 2])
        #expect(summary.missed == ["Varför 0?", "Varför 2?"])
    }

    @Test func noSummaryForTooLittleATextOrSomethingNotInTheStore() {
        var drill = A79A81RepetitionTests.bio(5)
        let run = RepetitionSession.RunSummary(drill: drill, heard: 2, laps: 0, asked: [0])
        #expect(PracticeSummary(run, origin: nil, inStore: { _ in true }) == nil, "fewer than three questions heard")
        let heard = RepetitionSession.RunSummary(drill: drill, heard: 3, laps: 0, asked: [1])
        #expect(PracticeSummary(heard, origin: nil, inStore: { _ in false }) == nil, "an own deck is not in the store")
        #expect(PracticeSummary(heard, origin: nil, inStore: { _ in true })?.places == [1])
        drill.said = true
        #expect(PracticeSummary(.init(drill: drill, heard: 9, laps: 1, asked: []), origin: nil, inStore: { _ in true }) == nil,
                "a text from Säg i AirPods")
        #expect(PracticeSummary(nil, origin: nil, inStore: { _ in true }) == nil)
    }

    @Test func theMissedQuestionsPlayAloneAndTheQuizKeepsItsPlace() async throws {
        let source = A78RepetitionTests.MockSource(), timer = A78RepetitionTests.MockTimer()
        let (session, defaults) = try session("a168-missed", source: source, timer: timer)
        let (model, _) = try model("a168-missed", session: session, defaults: defaults)
        let drill = model.save(A79A81RepetitionTests.bio(5))
        RepetitionProgress(drillID: drill.id, index: 3, savedAt: Date()).save(defaults)
        let summary = try #require(PracticeSummary(.init(drill: drill, heard: 5, laps: 1, asked: [1, 4]), origin: nil,
                                                   inStore: { _ in true }))
        await model.practiseMissed(summary)
        #expect(model.showsPlayer)
        #expect(session.drill?.items.map(\.question) == ["Varför 1?", "Varför 4?"])
        #expect(session.drill?.id != drill.id, "a run of its own, not the quiz")
        #expect(RepetitionProgress.load(defaults)?.drillID == drill.id && RepetitionProgress.load(defaults)?.index == 3,
                "Fortsätt where the quiz was left")
        // Asked again in that run: the summary points at the quiz's own places.
        let again = try #require(session.drill)
        let rerun = RepetitionSession.RunSummary(drill: again, heard: 3, laps: 1, asked: [1])
        let missedAgain = try #require(PracticeSummary(rerun, origin: (again.id, drill.id, [1, 4]), inStore: { _ in false }))
        #expect(missedAgain.originID == drill.id && missedAgain.places == [4] && missedAgain.missed == ["Varför 4?"])
    }

    // MARK: Start: the quiz played last at the top

    @Test func theQuizPlayedLastComesFirstUnlessANewerOneWasMadeAfter() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        var newest = A79A81RepetitionTests.bio(3); newest.title = "Ny"; newest.createdAt = t0.addingTimeInterval(100)
        var older = A79A81RepetitionTests.bio(3); older.title = "Gammal"; older.createdAt = t0
        let exams = [newest, older] // the store's order: newest first
        #expect(RepetitionModel.lastPlayedFirst(exams, progress: nil).map(\.title) == ["Ny", "Gammal"])
        let playedOlder = RepetitionProgress(drillID: older.id, index: 2, savedAt: t0.addingTimeInterval(200))
        #expect(RepetitionModel.lastPlayedFirst(exams, progress: playedOlder).map(\.title) == ["Gammal", "Ny"],
                "played after the new one was made: it is what one was doing")
        let playedBefore = RepetitionProgress(drillID: older.id, index: 2, savedAt: t0.addingTimeInterval(50))
        #expect(RepetitionModel.lastPlayedFirst(exams, progress: playedBefore).map(\.title) == ["Ny", "Gammal"],
                "a quiz made after it was played is first")
        let gone = RepetitionProgress(drillID: UUID(), index: 1, savedAt: t0.addingTimeInterval(300))
        #expect(RepetitionModel.lastPlayedFirst(exams, progress: gone).map(\.title) == ["Ny", "Gammal"])
    }

    // MARK: The words

    @Test func theSummarySaysWhatItKnowsInBothLanguages() {
        #expect(PracticeSummaryText.title == "Bra jobbat")
        #expect(PracticeSummaryText.heard(12, title: "Biologiprovet") == "Biologiprovet · du hörde 12 frågor")
        #expect(PracticeSummaryText.asked(1) == "Du bad om svaret på 1 fråga" && PracticeSummaryText.asked(3) == "Du bad om svaret på 3 frågor")
        #expect(PracticeSummaryText.practise(1) == "Öva den igen" && PracticeSummaryText.practise(3) == "Öva de 3 igen")
        func en(_ key: String) -> String { AppLanguage.en.bundle.localizedString(forKey: key, value: "(missing)", table: nil) }
        #expect(en("Bra jobbat") == "Nice work")
        #expect(en("Öva den igen") == "Practice it again")
        #expect(String(format: en("Öva de %lld igen"), 3) == "Practice those 3 again")
        #expect(en("Spelar texten igen i dina AirPods") == "Plays the text again in your AirPods")
        #expect(en("Lägg i fältet") == "Put in the field")
    }
}
