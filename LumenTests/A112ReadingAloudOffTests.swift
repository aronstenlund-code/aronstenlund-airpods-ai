import Foundation
import Testing
@testable import Lumen

/// A112 (D200, Kevin's K78): when the voice service's credits are out the server answers 200 with the questions and
/// answers as text and `audio_unavailable: true`. The app shows the text and one calm line, counts nothing and shows no
/// error. The server's answer is faked here (skenmoln); 0 ElevenLabs (D180).
@MainActor
@Suite struct A112ReadingAloudOffTests {
    typealias MockCloud = A79A81RepetitionTests.MockCloud

    static let line = "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt."

    /// K78's answer: every file still pending, `audio_unavailable`, started or not.
    static func view(started: Bool, refunded: Int? = nil) -> DrillCloudView {
        var view = T24FindingsTests.view([(T24FindingsTests.file("pending"), T24FindingsTests.file("pending")),
                                          (T24FindingsTests.file("pending"), T24FindingsTests.file("pending"))], failed: 0)
        view.drill.audio_started = started
        view.audio_unavailable = true
        view.refunded_questions = refunded
        return view
    }

    func rig(_ view: DrillCloudView, started: Bool) throws -> (CloudDrillAudio, DrillStore, Drill, MockCloud) {
        let folder = try A79A81RepetitionTests.folder("a112")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = MockCloud()
        cloud.views["srv"] = view
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 3)
        var drill = A79A81RepetitionTests.bio(2)
        drill.serverID = "srv"
        drill.audioStarted = started ? nil : false
        store.save(drill)
        return (audio, store, drill, cloud)
    }

    @Test func theLineIsDeangelosWording() {
        #expect(CloudDrillAudio.unavailableLine == Self.line)
    }

    @Test func theAnswerIsDecodedFromKevinsJSON() throws {
        let json = """
        {"drill": {"id": "srv", "title": "Bio", "audio_started": false},
         "items": [{"id": "i0", "position": 0, "question": "Varför?", "short": "Kort.", "long": "Kort. Mer.",
                    "audio": {"question": {"status": "pending"}, "long": {"status": "pending"}}}],
         "audio": {"done": 0, "total": 2, "failed": 0},
         "audio_unavailable": true,
         "notice": {"code": "audio_unavailable", "message": "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt."},
         "generated_questions": 0, "refunded_questions": 2}
        """
        let view = try JSONDecoder().decode(DrillCloudView.self, from: Data(json.utf8))
        #expect(view.audio_unavailable == true)
        #expect(view.refunded_questions == 2)
        #expect(view.items.first?.long == "Kort. Mer.") // the text is there
    }

    @Test func startaProvWithTheCreditsOutKeepsTheExamAsTextAndSaysTheCalmLine() async throws {
        let (audio, store, drill, _) = try rig(Self.view(started: false), started: false)
        let started = await audio.startAudio(drill)
        #expect(!started)
        let after = try #require(store.drill(drill.id))
        #expect(after.awaitsAudioStart, "not started: the next Starta prov makes the sound when the credits are back")
        #expect(after.items.map(\.long) == drill.items.map(\.long), "the questions and answers are still there as text")
        #expect(audio.problem(for: after) == Self.line)
        #expect(audio.isReadingAloudOff(after))
        #expect(!audio.quotaExceeded.contains(drill.id), "nothing is counted, so it is not the month running out")
    }

    @Test func aStartedExamWhoseSoundCannotBeMadeSaysTheCalmLineAndGivesTheQuestionsBack() async throws {
        let (audio, store, drill, _) = try rig(Self.view(started: true, refunded: 2), started: true)
        await audio.prepare(drill)
        let after = try #require(store.drill(drill.id))
        #expect(audio.problem(for: after) == Self.line)
        #expect(audio.refunds == 1, "the model reads the month's quota again")
        #expect(after.items.count == 2)
    }

    @Test func aSavedExamThatIsNotStartedSaysItAlreadyBeforeStartaProv() async throws {
        let (audio, store, drill, _) = try rig(Self.view(started: false), started: false)
        await audio.prepare(drill)
        let after = try #require(store.drill(drill.id))
        #expect(after.awaitsAudioStart)
        #expect(audio.isReadingAloudOff(after))
    }

    /// Aron's phone 2026-11-17 (Kevin's K87, point 4): the credits were back and the server had every file, but the
    /// card still said "Ljud: 0 av 30 klara": nothing asked the server again while the app stayed open. Coming back
    /// to the app asks again, and the sound comes without a restart.
    @Test func comingBackToTheAppAsksAgainForTheSoundThatWasNotMade() async throws {
        let (audio, store, drill, cloud) = try rig(Self.view(started: true), started: true)
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() },
                                        makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "k87-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        await audio.prepare(drill)
        #expect(model.isReadingAloudOff(drill) && model.progress(drill).ready == 0, "the credits are out: nothing is followed")

        // The credits are back and the server has made every file. The app was open the whole time.
        let file = { (name: String) in
            DrillCloudView.File(status: "done", url: "https://x.supabase.co/storage/v1/object/sign/drill_audio/ab/\(name).mp3?t=1",
                                duration_ms: 3000, short_end_ms: nil)
        }
        var done = T24FindingsTests.view([(file("q0"), file("l0")), (file("q1"), file("l1"))], failed: 0)
        done.drill.audio_started = true
        done.audio = .init(done: 4, total: 4, failed: 0)
        cloud.views["srv"] = done
        #expect(model.progress(drill).ready == 0, "nothing asks by itself")

        model.appBecameActive()
        let came = await waitUntil { model.progress(store.drill(drill.id) ?? drill).ready == 4 }
        #expect(came, "back in the app: the server is asked again and the files are downloaded")
        #expect(audio.problem(for: drill) == nil && !model.isReadingAloudOff(drill))
        #expect(model.canStart(store.drill(drill.id) ?? drill), "Starta prov is on again")
    }

    @Test func whenTheCreditsAreBackTheLineIsGone() async throws {
        let (audio, store, drill, cloud) = try rig(Self.view(started: false), started: false)
        await audio.prepare(drill)
        #expect(audio.isReadingAloudOff(drill))
        // The server no longer says audio_unavailable.
        var back = Self.view(started: false)
        back.audio_unavailable = nil
        cloud.views["srv"] = back
        await audio.prepare(try #require(store.drill(drill.id)))
        #expect(!audio.isReadingAloudOff(drill))
        #expect(audio.problem(for: drill) == nil)
    }
}

/// A112b (D200, Kelly U4): without sound the questions are stepped by hand, only while the player waits.
@MainActor
@Suite struct A112bStepByHandTests {
    typealias MockSource = A78RepetitionTests.MockSource
    typealias MockTimer = A78RepetitionTests.MockTimer

    @Test func thePlayerWithoutSoundIsSteppedByHandAndGoesRoundTheList() {
        final class Places { var saved: [Int] = [] }
        let places = Places()
        let player = RepetitionPlayer(count: 3, track: { _ in nil }, source: MockSource(), timer: MockTimer(), thinkingSeconds: 6)
        player.onProgress = { places.saved.append($0) }
        player.start()
        #expect(player.phase == .waitingForAudio(0))
        player.stepByHand(1)
        #expect(player.phase == .waitingForAudio(1))
        #expect(player.index == 1)
        player.stepByHand(1)
        player.stepByHand(1)
        #expect(player.index == 0, "after the last question comes the first")
        player.stepByHand(-1)
        #expect(player.index == 2, "before the first question comes the last")
        #expect(places.saved == [1, 2, 0, 2], "the place is saved, so Fortsätt comes back to it")
        #expect(player.lap == 0, "no lap is counted by hand")
    }

    @Test func aQuestionThatPlaysIsNotSkipped() {
        let track = RepetitionTrack(question: A78RepetitionTests.url("q0"), long: A78RepetitionTests.url("l0"),
                                    short: .file(A78RepetitionTests.url("s0")))
        let player = RepetitionPlayer(tracks: [track, track], source: MockSource(), timer: MockTimer(), thinkingSeconds: 6)
        player.start()
        #expect(player.phase == .question(0))
        player.stepByHand(1)
        #expect(player.phase == .question(0), "D142: no skipping while there is sound")
        #expect(player.index == 0)
    }
}
