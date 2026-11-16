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
