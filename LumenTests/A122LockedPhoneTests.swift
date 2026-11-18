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
        // A132 (D215.2, Kelly Ke72): shortened, and shown only until Spela has been pressed once.
        #expect(SayText.lockLine == "Du kan låsa telefonen. Det hörs i AirPods ändå.")
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
        #expect(quota.line == "1,2k av 1,5k krediter kvar den här månaden") // A139: short numbers
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
        #expect(CreditText.capsule(1236) == "1,2k krediter kvar" && CreditText.capsule(1) == "1 kredit kvar") // A139: short
        #expect(CreditText.sayLine(cost: 764) == "Kostar 764 krediter. Upprepningar kostar inget.")
        #expect(CreditText.sayLine(cost: 0) == "Kostar inget. Ljudet finns redan.")
        #expect(CreditText.cardLine(cost: 2340) == "Kostar 2,4k krediter") // A139: a cost is rounded up
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

    // MARK: A132 (D215): a said text is "Senaste" under the field, never an exam on Start

    @Test func aSaidTextIsNotAnExamOnStart() async throws {
        let folder = try A79A81RepetitionTests.folder("a132")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let session = RepetitionSession(inputs: [], makeSource: { MockSource() }, makeTimer: { MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a132-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        store.save(A79A81RepetitionTests.bio(2))

        let text = "HISTORIA – 1880–1918\nNationalism = stark kärlek till den egna nationen."
        let said = try #require(await model.say(text, repeatMinutes: 10))
        // D215.6 (Ke72): it plays on the card on Start; the player with the sentences is not put in front of it.
        #expect(model.isSayingOnCard && !model.showsPlayer && model.sayRefusal(said) == nil)
        model.end()
        #expect(!model.isSayingOnCard)
        #expect(model.examDrills.map(\.title) == ["Bio"], "Nästa prov and Andra prov are exams only")
        #expect(model.saidDrills.map(\.id) == [said.id], "the text is under Senaste")
        #expect(model.saidDrills.first?.saidText == text, "a tap puts exactly this back in the field")
        #expect(model.saidDrill(for: "  HISTORIA – 1880–1918 \n\nNationalism = stark kärlek till den egna nationen.\n")?.id == said.id)

        // Put back from Senaste and played again: the same exam, nothing new on the phone or the server.
        let again = try #require(await model.say(text, repeatMinutes: 10))
        model.end()
        for _ in 0..<50 where audio.preparing.contains(said.id) { try? await Task.sleep(for: .milliseconds(2)) }
        #expect(again.id == said.id && store.drills.count == 2 && cloud.saves.count == 1)
    }

    /// Aron's phone had said texts from before the mark existed: they are known by what the field made of them.
    @Test func aTextSaidBeforeTheMarkExistedIsKnown() {
        let text = "HISTORIA – 1880–1918\nNationalism = stark kärlek till den egna nationen."
        let old = Drill.text(title: SaidText.title(text), summary: DrillSummary(subject: "", grade: "", covers: ""),
                             parts: SaidText.parts(text).map { DrillItem.textPart($0, part: .para) })
        #expect(old.said == nil && old.isSaid)
        let reading = Drill.text(title: "Fotosyntes", summary: A79A81RepetitionTests.summary,
                                 parts: [DrillItem.textPart("Växter gör socker.", part: .para)])
        #expect(!reading.isSaid, "a text made in Nytt prov is an exam")
        #expect(!A79A81RepetitionTests.bio(2).isSaid)
    }

    /// Toby's T51 (2026-11-18, T28): a text made in Nytt prov without a name, subject or grade is named by the server
    /// after its first heading, exactly what the field would have called it. It is an exam all the same.
    @Test func aTextFromNyttProvNamedAfterItsHeadingIsAnExam() {
        let parts = [DrillItem.textPart("Fotosyntes", part: .heading),
                     DrillItem.textPart("Växter tillverkar socker av koldioxid och vatten.", part: .para)]
        let draft = DrillTextDraft(title: "Fotosyntes", summary: DrillSummary(subject: "", grade: "", covers: ""),
                                   parts: parts, chars: 59, countsAs: 1)
        let made = draft.drill
        var unmarked = made
        unmarked.said = nil
        #expect(unmarked.isSaid, "without the mark the rule for old texts takes it for a said text")
        #expect(made.said == false && !made.isSaid, "the text from Nytt prov is marked as an exam")
    }

    @Test func theCardsWordsAreKellys() {
        #expect(SayText.playTitle(10) == "Spela i 10 min" && SayText.playTitle(60) == "Spela i 1 timme")
        #expect(SayText.creditsLine(cost: 120, left: 1236) == "120 krediter")
        #expect(SayText.creditsLine(cost: 0, left: 88) == "0 krediter")
        #expect(SayText.creditsLine(cost: 120, left: 88) == "120 krediter · du har 88")
        #expect(SayText.capsule("Glosor v. 47") == "Glosor v. 47")
        #expect(SayText.capsule("HISTORIA – 1880–1918\nNationalism = stark kärlek") == "HISTORIA – 1880–1918 Na…")
        #expect(SayText.capsule("HISTORIA – 1880–1918\nNationalism = stark kärlek").count <= 24)
    }

    // MARK: A132 (D215.8, K92): the cost before Spela is the server's; A133 (D216): an account without a limit

    @Test func theCostBeforeSpelaIsAskedOfTheServerWithoutSavingAnything() async throws {
        let folder = try A79A81RepetitionTests.folder("k92")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        cloud.costAnswer = try JSONDecoder().decode(DrillCost.self, from: Data(#"{"cost":744,"remaining":1236,"limit":1500,"unit":"chars","enough":true}"#.utf8))
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let session = RepetitionSession(inputs: [], makeSource: { MockSource() }, makeTimer: { MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "k92-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)

        let answer = try #require(await model.sayCost("HISTORIA – 1880–1918\nNationalism = stark kärlek till den egna nationen."))
        #expect(answer.cost == 744 && answer.remaining == 1236, "the server's number, not the app's count of characters")
        #expect(cloud.costAsked.count == 1 && cloud.costAsked[0].isText && cloud.costAsked[0].items.count == 2)
        #expect(store.drills.isEmpty && cloud.saves.isEmpty && cloud.startCalls == 0, "nothing is saved, started or counted")
        #expect(DrillCloudClient.saveBody(cloud.costAsked[0])["items"] != nil, "the same body as save")
        #expect(await model.sayCost("   ") == nil)

        cloud.costAnswer = nil // a server without K92, or no network: nothing is said, and Spela asks the server
        #expect(await model.sayCost("En text.") == nil)
    }

    @Test func anAccountWithoutALimitIsToldObegransat() throws {
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"unit":"chars","limit":1500,"used":9000,"remaining":0,"unlimited":true,"resets":"2026-12-01"}"#.utf8))
        #expect(quota.isUnlimited && quota.left > 1_000_000 && !quota.isUsedUp, "nothing is refused for lack of credits")
        #expect(CreditsText.capsule(quota) == "Obegränsat")
        let usual = try JSONDecoder().decode(DrillQuota.self, from: Data(Self.creditsJSON.utf8))
        #expect(!usual.isUnlimited && CreditsText.capsule(usual) == "1,2k krediter kvar")
    }

    // MARK: A135 (D219): Aron's phone 20:24, Spela loaded for over a minute; sound that is here plays without the network

    /// A text whose every line already has its sound on the phone plays at once: no answer from the server is waited
    /// for (the server here never answers in time), and the server is told afterwards.
    @Test func aTextWhoseSoundIsOnThePhonePlaysAtOnceWithoutTheNetwork() async throws {
        let folder = try A79A81RepetitionTests.folder("a135")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let session = RepetitionSession(inputs: [], makeSource: { MockSource() }, makeTimer: { MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a135-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        // An earlier text on the phone has the sound for the line "Hej".
        var earlier = Drill.text(title: "Hej", summary: DrillSummary(subject: "", grade: "", covers: ""),
                                 parts: [DrillItem.textPart("Hej", part: .para)])
        earlier.said = true
        earlier.items[0].longAudio = "abc.mp3"
        earlier.serverID = "srv-0"
        earlier.audioStarted = nil
        try Data([1, 2, 3]).write(to: audio.fileURL("abc.mp3"))
        store.save(earlier)

        let given = RepetitionModel.withSoundAlreadyHere(
            Drill.text(title: "Hej då", summary: DrillSummary(subject: "", grade: "", covers: ""),
                       parts: [DrillItem.textPart("Hej", part: .para), DrillItem.textPart("Nytt.", part: .para)]),
            from: store.drills)
        #expect(given.items[0].longAudio == "abc.mp3" && given.items[1].longAudio == nil, "only the line that is here")

        cloud.saveError = .offline("no network") // the server cannot be reached at all
        let said = try #require(await model.say("  Hej ", repeatMinutes: 10))
        #expect(said.id == earlier.id && model.isSayingOnCard, "the same text is the exam that is here, and it plays")
        #expect(cloud.saves.isEmpty && cloud.startCalls == 0, "nothing was asked of the server")
        model.end()
    }

    @Test func senasteShowsEveryTextOnce() async throws {
        let folder = try A79A81RepetitionTests.folder("a135-once")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let session = RepetitionSession(inputs: [], makeSource: { MockSource() }, makeTimer: { MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a135b-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        for text in ["HISTORIA – 1880–1918\nNationalism.", "HISTORIA  –  1880–1918\nNationalism.", "Hej"] {
            var made = Drill.text(title: SaidText.title(text), summary: DrillSummary(subject: "", grade: "", covers: ""),
                                  parts: SaidText.parts(text).map { DrillItem.textPart($0, part: .para) })
            made.said = true
            store.save(made)
        }
        #expect(model.saidDrills.count == 3 && model.recentSaid.count == 2, "the two copies of the same text are one capsule")
    }

    @Test func theSoundOnThePhoneHasACeiling() async throws {
        let folder = try A79A81RepetitionTests.folder("a135-space")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let audio = CloudDrillAudio(cloud: A107StartAudioTests.DeferredCloud(), store: store, folder: folder,
                                    pollInterval: .milliseconds(1), maxPolls: 20)
        for (i, name) in ["old.mp3", "mid.mp3", "new.mp3", "playing.mp3"].enumerated() {
            let url = audio.fileURL(name)
            try Data(count: 1000).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_800_000_000 + Double(i * 60))],
                                                  ofItemAtPath: url.path)
        }
        var playing = Drill.text(title: "T", summary: A79A81RepetitionTests.summary, parts: [DrillItem.textPart("En.", part: .para)])
        playing.items[0].longAudio = "playing.mp3"
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)],
                                              ofItemAtPath: audio.fileURL("playing.mp3").path) // the oldest of all
        #expect(audio.trimStorage(limit: 10_000, keeping: playing) == 0, "under the ceiling nothing is removed")
        let removed = audio.trimStorage(limit: 2_500, keeping: playing)
        let left = Set(try FileManager.default.contentsOfDirectory(atPath: audio.fileURL("x").deletingLastPathComponent().path).filter { $0.hasSuffix(".mp3") })
        #expect(removed == 2 && left == ["new.mp3", "playing.mp3"], "the oldest go first, never what is playing")
        #expect(SayText.slowLine == "Ljudet kunde inte hämtas. Kolla nätet.")
        // A144 (D225): told after 8 s, given up after 25 s or without a network.
        #expect(SayText.slowAfter == .seconds(8) && SayText.giveUpAfter == .seconds(25))
        #expect(SayText.wait(after: .seconds(7), online: true) == .quiet && SayText.wait(after: .seconds(8), online: true) == .slow)
        #expect(SayText.wait(after: .seconds(24), online: true) == .slow && SayText.wait(after: .seconds(25), online: true) == .gaveUp)
        #expect(SayText.wait(after: .seconds(1), online: false) == .gaveUp, "the phone knows it has no network: at once")
    }

    // MARK: A139 (D222): short numbers for credits

    @Test func creditsAreShownShort() {
        // What one has is rounded down.
        #expect(CreditText.short(999, .down) == "999")
        #expect(CreditText.short(1000, .down) == "1,0k")
        #expect(CreditText.short(5392, .down) == "5,3k")
        #expect(CreditText.short(9999, .down) == "9,9k")
        #expect(CreditText.short(10_000, .down) == "10k")
        #expect(CreditText.short(12_999, .down) == "12k")
        #expect(CreditText.short(1_000_000, .down) == "1\u{00A0}000k")
        // What something costs is rounded up.
        #expect(CreditText.short(999, .up) == "999")
        #expect(CreditText.short(1000, .up) == "1,0k")
        #expect(CreditText.short(1251, .up) == "1,3k")
        #expect(CreditText.short(5392, .up) == "5,4k")
        #expect(CreditText.short(9999, .up) == "10k", "never 10,0k")
        #expect(CreditText.short(10_001, .up) == "11k")
        #expect(CreditText.short(0, .down) == "0")
        // The same formatter everywhere: the capsule, the cost by the button, the card and "not enough".
        #expect(CreditText.capsule(5392) == "5,3k krediter kvar" && CreditText.capsule(764) == "764 krediter kvar")
        #expect(SayText.creditsLine(cost: 1251, left: 5392) == "1,3k krediter")
        #expect(SayText.creditsLine(cost: 5392, left: 1251) == "5,4k krediter · du har 1,2k")
        #expect(CreditText.notEnough(cost: 5392, left: 1251, resetsDay: "1 december")
                == "Det här kostar 5,4k krediter. Du har 1,2k kvar. Nya krediter den 1 december.")
        // The sheet has the exact number.
        #expect(CreditText.exact(5392) == "5\u{00A0}392 krediter")
        #expect(CreditText.footnote(limit: 1500, resetsDay: nil).contains("1\u{00A0}500 krediter"))
    }

    @Test func theCapsuleSaysVeckokortWithASubscription() throws {
        let json = #"{"unit":"chars","limit":1500,"used":0,"remaining":37700,"resets":"2026-12-01","subscription":{"active":true,"until":"2026-11-24T10:00:00.000Z","week_used":3800,"week_limit":40000},"monthly_free":1500,"purchased":0}"#
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(json.utf8))
        #expect(quota.hasWeeklyCard && quota.subscription?.week_limit == 40000 && CreditsText.capsule(quota) == "Veckokort")
        let ended = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"unit":"chars","limit":1500,"used":0,"remaining":5392,"subscription":{"active":false,"until":null,"week_used":0,"week_limit":40000}}"#.utf8))
        #expect(!ended.hasWeeklyCard && CreditsText.capsule(ended) == "5,3k krediter kvar")
        let admin = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"unit":"chars","limit":1500,"used":0,"remaining":0,"unlimited":true,"subscription":{"active":true}}"#.utf8))
        #expect(CreditsText.capsule(admin) == "Obegränsat", "admin first")
    }

    /// Angela Schrute's finding: over the ceiling, Start removed the oldest files and then fetched them again, at every
    /// visit. An exam that lost sound is marked and left alone until it is started.
    @Test func soundRemovedForSpaceIsNotFetchedAgainUntilTheExamIsStarted() async throws {
        let folder = try A79A81RepetitionTests.folder("a135-trim")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        cloud.started = true
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let session = RepetitionSession(inputs: [], makeSource: { MockSource() }, makeTimer: { MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a135t-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        var drill = Drill.text(title: "T", summary: A79A81RepetitionTests.summary, parts: [DrillItem.textPart("En.", part: .para)])
        drill.serverID = "srv-1"
        drill.audioStarted = nil
        drill.items[0].longAudio = "en.mp3"
        try Data(count: 1000).write(to: audio.fileURL("en.mp3"))
        store.save(drill)

        #expect(audio.trimStorage(limit: 500) == 1)
        #expect(store.drill(drill.id)?.audioTrimmed == true && !audio.hasAllSound(drill))
        model.appBecameActive() // Start is shown again, the app comes back: nothing is fetched
        try? await Task.sleep(for: .milliseconds(30))
        #expect(cloud.statusCalls == 0 && cloud.saves.isEmpty, "not fetched again just because Start is shown")

        await model.start(drill) // someone starts it: now it is fetched
        #expect(store.drill(drill.id)?.audioTrimmed == nil)
        for _ in 0..<100 where cloud.statusCalls == 0 { try? await Task.sleep(for: .milliseconds(2)) }
        #expect(cloud.statusCalls > 0, "the sound is asked for when the exam is started")
        model.end()
    }
}
