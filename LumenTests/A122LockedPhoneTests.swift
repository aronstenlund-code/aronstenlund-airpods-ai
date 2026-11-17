import Foundation
import Testing
@testable import Lumen

/// A122 (D209): "Säg i AirPods" says that the phone can be locked and put away, and that has to be true. What the
/// Simulator can show: the repetition lives in the session (no view is needed for it to go round), the presses that
/// the Lock Screen and the AirPods send pause and go on, and the Lock Screen is given its words. That the sound
/// really goes on with the screen locked is for the phone. Mock sound, 0 ElevenLabs (D180).
@MainActor
@Suite struct A122LockedPhoneTests {
    typealias MockSource = A78RepetitionTests.MockSource
    typealias MockTimer = A78RepetitionTests.MockTimer
    typealias Clock = A115SayInAirPodsTests.Clock

    func session(_ source: MockSource, _ clock: Clock) -> RepetitionSession {
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { MockTimer() },
                                        defaults: UserDefaults(suiteName: "a122-\(UUID().uuidString)")!,
                                        activatesAudioSession: false)
        session.now = { clock.date }
        return session
    }

    @Test func theLineUnderTheFieldIsAronsWords() {
        #expect(SayText.lockLine == "Du kan låsa telefonen och lägga undan den. Det hörs i AirPods ändå.")
    }

    @Test func theLockScreenSaysSagIAirPods() {
        let once = RepetitionSession.sayingNowPlaying(title: "Fotosyntes: koldioxid + vatten …", lap: 1, repeats: false)
        #expect(once.title == "EarMind · Säg i AirPods" && once.artist == "Fotosyntes: koldioxid + vatten …")
        let round = RepetitionSession.sayingNowPlaying(title: "Fotosyntes", lap: 3, repeats: true)
        #expect(round.title == "EarMind · Säg i AirPods" && round.artist == "Fotosyntes · varv 3")
    }

    /// No view and no screen: the session alone takes the text round, and a press from the Lock Screen or the AirPods
    /// (1 press = play/pause) pauses it and goes on, with the lap and the time kept.
    @Test func itGoesRoundAndIsPausedByAPressWithoutAnyView() throws {
        let source = MockSource()
        let clock = Clock()
        let session = session(source, clock)
        session.startReading(A115SayInAirPodsTests.text, saying: .init(repeatMinutes: 5)) { _ in A115SayInAirPodsTests.audio }
        let reader = try #require(session.reader)
        #expect(session.isActive && session.readingLap == 1)

        session.press(.long) // the Lock Screen's pause, or 1 press on the AirPods
        #expect(reader.isPaused)
        clock.date += 30
        session.press(.long)
        #expect(!reader.isPaused && session.isActive)
        #expect(session.readingLap == 1 && session.repeatSecondsLeft == 270, "the time runs by the clock, not by the screen")

        source.last.finish()
        #expect(session.readingLap == 2, "the text starts over while time is left")
        #expect(session.isActive)
    }

    // MARK: A124 (D210): 10 min to 1 hour

    @Test func howLongIsTenMinutesToOneHourInStepsOfFive() {
        #expect(SayText.repeats == [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60])
        #expect(SayText.repeats.map(SayText.howLong).first == "10 min" && SayText.repeats.map(SayText.howLong).last == "1 timme")
        #expect(SayText.defaultRepeat == 10)
        #expect(SayText.repeatMinutes(0) == 10, "the old En gång becomes 10 min")
        #expect(SayText.repeatMinutes(5) == 10 && SayText.repeatMinutes(20) == 20 && SayText.repeatMinutes(60) == 60)
    }

    /// One hour: it starts at once (nothing is scheduled), goes round the whole hour and stops after the lap that is
    /// being read when the hour is out.
    @Test func oneHourStartsAtOnceAndGoesRoundTheWholeHour() throws {
        let source = MockSource()
        let clock = Clock()
        let session = session(source, clock)
        session.startReading(A115SayInAirPodsTests.text, saying: .init(repeatMinutes: 60)) { _ in A115SayInAirPodsTests.audio }
        #expect(session.isActive && source.made.count == 1, "it plays at once")
        #expect(session.repeatSecondsLeft == 3600)
        clock.date += 3599
        source.last.finish()
        #expect(session.readingLap == 2 && session.reader?.isAtEnd == false, "a second is left: one more lap")
        clock.date += 2
        source.last.finish()
        #expect(session.reader?.isAtEnd == true && session.readingLap == 2, "the hour is out: it stops after this lap")
    }

    // MARK: A123: which build

    @Test func theBuildLineNamesTheRunAndTheCommit() {
        #expect(BuildInfo.line(version: "0.1.0", build: "44019359349", sha: "bb9a74b") == "Version 0.1.0 (körning 44019359349 · bb9a74b)")
        #expect(BuildInfo.line(version: "0.1.0", build: "1", sha: "") == "Version 0.1.0 (1)")
        #expect(BuildInfo.line(version: "0.1.0", build: "1", sha: nil) == "Version 0.1.0 (1)")
        #expect(BuildInfo.line(version: "0.1.0", build: "1", sha: "$(LUMEN_GIT_SHA)") == "Version 0.1.0 (1)")
    }

    // MARK: Aron's phone 2026-11-17 08:55: "Ingen kontakt" with a pause button

    @Test func aPlayerThatWaitsForSoundThatIsNotComingIsSteppedByHand() {
        #expect(RepetitionModel.soundIsNotComing(problem: CloudDrillAudio.unavailableLine))
        #expect(RepetitionModel.soundIsNotComing(problem: "Ingen kontakt med EarMind just nu. Försök igen om en stund."))
        #expect(!RepetitionModel.soundIsNotComing(problem: nil), "Gör ljudet …: it is on its way, so pause stays")
        #expect(!RepetitionModel.soundIsNotComing(problem: ""))
    }

    /// Kevin K87 (3): the text from "Säg i AirPods" was saved twice (one copy started, one not). A new exam's save
    /// spawns `prepare`, and Spela starts the sound before that task has run: only one of them may save it.
    @Test func aNewTextThatIsStartedAtOnceIsSavedOnce() async throws {
        let folder = try A79A81RepetitionTests.folder("a122-once")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        cloud.yieldsInSave = true
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        var drill = A79A81RepetitionTests.bio(2)
        drill.needsUpload = true
        drill.audioStarted = false
        store.save(drill)

        let saving = Task { await audio.prepare(drill) } // what saving a new exam spawns
        let started = await audio.startAudio(drill)      // Spela, before that task has run
        await saving.value
        for _ in 0..<50 where audio.preparing.contains(drill.id) { try? await Task.sleep(for: .milliseconds(2)) }

        #expect(started)
        #expect(cloud.saves.count == 1, "one copy on the server, not one started and one not")
        #expect(cloud.startCalls == 1)
        let saved = try #require(store.drill(drill.id))
        #expect(!saved.awaitsAudioStart && saved.serverID == "srv-1")
        #expect(audio.problem(for: saved) == nil)
    }

    // MARK: A129 (D211, K88): the exam's own id on the first save

    @Test func theFirstSaveCarriesTheExamsOwnIdAndLaterSavesTheServers() throws {
        var questions = A79A81RepetitionTests.bio(2)
        let first = try #require(DrillCloudClient.saveBody(questions)["drill"] as? [String: Any])
        #expect(first["client_id"] as? String == questions.id.uuidString.lowercased())
        #expect(first["id"] == nil)
        let again = try #require(DrillCloudClient.saveBody(questions)["drill"] as? [String: Any])
        #expect(again["client_id"] as? String == first["client_id"] as? String, "the same exam says the same id every time")

        let text = Drill.text(title: "T", summary: A79A81RepetitionTests.summary, parts: [DrillItem.textPart("En mening.", part: .para)])
        let said = try #require(DrillCloudClient.saveBody(text)["drill"] as? [String: Any])
        #expect(said["client_id"] as? String == text.id.uuidString.lowercased(), "also a text from Säg i AirPods")

        questions.serverID = "srv-1"
        let later = try #require(DrillCloudClient.saveBody(questions)["drill"] as? [String: Any])
        #expect(later["id"] as? String == "srv-1" && later["client_id"] == nil, "K88: not used once the server's id is known")
    }

    /// Toby T36 (2026-11-17): a text that was removed while its sound was followed came back as a new, unstarted exam.
    /// The question on its way got 404 and the phone's (removed) copy was saved again. Removed stays removed.
    @Test func anExamRemovedWhileItsSoundIsFollowedDoesNotComeBack() async throws {
        let folder = try A79A81RepetitionTests.folder("a122-removed")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        var drill = A79A81RepetitionTests.bio(2)
        drill.serverID = "srv-1"
        drill.audioStarted = nil // started: its sound is followed with `status`
        store.save(drill)
        cloud.onStatus = { store.delete(drill.id) } // the user removes it while the question is on its way
        cloud.statusError = .refused(status: 404, code: "not_found", message: "Provet finns inte.")

        await audio.prepare(drill)

        #expect(cloud.statusCalls == 1)
        #expect(store.drill(drill.id) == nil, "it is not put back on the phone")
        #expect(cloud.saves.isEmpty, "and not saved as a new exam on the server")
        #expect(audio.problem(for: drill) == nil)
    }

    // MARK: A130 (D212): Aron's phone 13:48, Spela did nothing when the server said 402

    @Test func aRefusedSpelaSaysTheServersWordsAndWhenItIsFilledUp() {
        let k64 = "Du har gjort 14 av 15 frågor med ljud den här månaden."
        #expect(SaidText.refusalLine(problem: k64, quotaExceeded: true, refill: "Fylls på den 1 december.")
                == "Du har gjort 14 av 15 frågor med ljud den här månaden. Fylls på den 1 december.")
        #expect(SaidText.refusalLine(problem: k64 + " Fylls på den 1 december.", quotaExceeded: true, refill: "Fylls på den 1 december.")
                == k64 + " Fylls på den 1 december.", "not said twice")
        #expect(SaidText.refusalLine(problem: nil, quotaExceeded: true, refill: nil) == "Du har inga frågor kvar den här månaden.")
        #expect(SaidText.refusalLine(problem: nil, quotaExceeded: false, refill: "Fylls på den 1 december.")
                == "Det gick inte att spela just nu. Försök igen om en stund.", "never silent")
        #expect(RepetitionModel.refillLine("2026-12-01") == "Fylls på den 1 december.")
        #expect(RepetitionModel.refillLine(nil) == nil)
    }

    @Test func theTextIsCountedWithTheServersNumber() {
        let text = String(repeating: "a", count: 764)
        #expect(SaidText.countsAs(text, perQuestion: 800) == 1)
        #expect(SaidText.countsAs(text, perQuestion: 400) == 2, "the server's number decides, not the app's 800")
        #expect(SaidText.countsAs(text, perQuestion: nil) == 1)
    }

    /// The server refuses the start (402). The player does not open, the line is the server's, and pressing Spela again
    /// on the same text saves nothing more: one exam, however many presses.
    @Test func pressingSpelaAgainOnARefusedTextMakesNoNewExam() async throws {
        let folder = try A79A81RepetitionTests.folder("a130")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        cloud.quotaLeft = false
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let session = RepetitionSession(inputs: [], makeSource: { MockSource() }, makeTimer: { MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a130-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)

        let first = try #require(await model.say("1918: Vapenstillestånd den 11 november.", repeatMinutes: 10))
        #expect(!model.showsPlayer, "nothing plays")
        #expect(model.sayRefusal(first)?.hasPrefix("Du har inga frågor kvar den här månaden.") == true, "the server's words (K64)")
        let second = try #require(await model.say("1918: Vapenstillestånd den 11 november.", repeatMinutes: 10))
        _ = await model.say("1918: Vapenstillestånd den 11 november.", repeatMinutes: 10)
        for _ in 0..<50 where audio.preparing.contains(first.id) { try? await Task.sleep(for: .milliseconds(2)) }

        #expect(second.id == first.id)
        #expect(store.drills.count == 1, "one exam on the phone")
        #expect(cloud.saves.count == 1, "and one on the server, however many presses")
        #expect(cloud.startCalls == 3, "each press asks again: the month may have been filled up")
        #expect(model.sayRefusal(second) != nil)
    }

    // MARK: A131 (D213, K90, Ke71): the month in credits

    static let creditsJSON = """
    {"unit":"chars","limit":1500,"used":264,"remaining":1236,"left":1236,"suggest":1236,"per":"month",
     "resets":"2026-12-01","resets_day":"1 december",
     "prices":{"unit":"chars","classes":[],"read":{"chars_per_question":1},"free":["shared","published"]}}
    """

    @Test func theMonthInCreditsIsReadFromTheServer() throws {
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(Self.creditsJSON.utf8))
        #expect(quota.isCredits && quota.left == 1236 && quota.limit == 1500 && quota.resets_day == "1 december")
        #expect(quota.line == "1\u{00A0}236 av 1\u{00A0}500 krediter kvar den här månaden")
        // K90: the list's quota has no `resets_day`; the day is read from `resets` then.
        let listed = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"unit":"chars","limit":1500,"used":264,"remaining":1236,"resets":"2026-12-01"}"#.utf8))
        #expect(listed.resetsDay == "1 december" && quota.resetsDay == "1 december")
        // While a text is written: the server's rule (runs of blanks are one space, lines trimmed, no line breaks).
        #expect(SaidText.creditChars("  HISTORIA   –  1880  \n\n  Två   ord. ") == "HISTORIA – 1880".count + "Två ord.".count)
        let odd = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"unit":"chars","limit":1500,"used":0,"remaining":1500,"prices":{"unit":"chars"}}"#.utf8))
        #expect(odd.left == 1500 && odd.prices == nil, "a price table this app cannot read does not take the number with it")
        let old = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"used":3,"limit":15,"left":12}"#.utf8))
        #expect(!old.isCredits && old.left == 12 && old.line == "12 av 15 frågor kvar den här månaden", "a server that counts questions")
    }

    @Test func theWordsAreKellysAndTheNumbersTheServers() {
        #expect(CreditText.number(764) == "764" && CreditText.number(1236) == "1\u{00A0}236" && CreditText.number(1_234_567) == "1\u{00A0}234\u{00A0}567")
        #expect(CreditText.capsule(1236) == "1\u{00A0}236 krediter kvar" && CreditText.capsule(1) == "1 kredit kvar")
        #expect(CreditText.sayLine(cost: 764) == "Kostar 764 krediter. Upprepningar kostar inget.")
        #expect(CreditText.sayLine(cost: 0) == "Kostar inget. Ljudet finns redan.")
        #expect(CreditText.cardLine(cost: 2340) == "Kostar 2\u{00A0}340 krediter")
        #expect(CreditText.notEnough(cost: 764, left: 312, resetsDay: "1 december")
                == "Det här kostar 764 krediter. Du har 312 kvar. Nya krediter den 1 december.")
        #expect(CreditText.footnote(limit: 1500, resetsDay: "1 december")
                == "En text på 764 tecken kostar 764 krediter. Du får 1\u{00A0}500 krediter varje månad. Nya krediter den 1 december. Oanvända krediter sparas inte.")
        // The server's own line at 402 is said as it is; nothing is added to it.
        let server = "Det här kostar 764 krediter. Du har 312 kvar. Nya krediter 1 december."
        #expect(SaidText.refusalLine(problem: server, quotaExceeded: true, refill: "Fylls på den 1 december.") == server)
    }

    @Test func theExamKeepsWhatTheServerSaysStartingCosts() throws {
        let json = """
        {"drill":{"id":"srv-1","title":"T","kind":"text","audio_started":false},"items":[],
         "audio":{"done":0,"total":1,"cost":764},"cost":764,"unit":"chars"}
        """
        let view = try JSONDecoder().decode(DrillCloudView.self, from: Data(json.utf8))
        #expect(view.startCost == 764)
        #expect(Drill.from(view).startCost == 764)
        let old = try JSONDecoder().decode(DrillCloudView.self, from: Data(#"{"drill":{"id":"srv-1"},"items":[],"audio":{"done":0,"total":0}}"#.utf8))
        #expect(old.startCost == nil && Drill.from(old).startCost == nil, "a server without credits says nothing")
    }

    /// K90: a new text that the credits do not cover is refused at the save, and nothing is saved. The phone keeps
    /// nothing either (no card on Start), and the server's line is what is said.
    @Test func aNewTextTheCreditsDoNotCoverLeavesNothingBehind() async throws {
        let folder = try A79A81RepetitionTests.folder("a131")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let line = "Det här kostar 764 krediter. Du har 312 kvar. Nya krediter 1 december."
        cloud.saveError = .refused(status: 402, code: "quota_exceeded", message: line)
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let session = RepetitionSession(inputs: [], makeSource: { MockSource() }, makeTimer: { MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a131-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)

        let refused = try #require(await model.say("1918: Vapenstillestånd den 11 november.", repeatMinutes: 10))
        #expect(!model.showsPlayer)
        #expect(model.sayRefusal(refused) == line, "the server's own words")
        #expect(store.drills.isEmpty, "no card on Start for a text that was refused")
        #expect(cloud.startCalls == 0)
    }
}
