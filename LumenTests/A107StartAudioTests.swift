import Foundation
import Testing
@testable import Lumen

/// A107 (D190, D191, K71 in backend/README "Ljud vid Starta prov"): saving makes no sound, Starta prov does. A mock
/// server with K71's behaviour; 0 ElevenLabs (D180).
@MainActor
@Suite struct A107StartAudioTests {
    /// K71: `save` with `defer_audio` makes nothing until `start`; after it every file is done at once.
    @MainActor final class DeferredCloud: DrillCloudSyncing {
        var saves: [[String: Any]] = []
        var startCalls = 0
        var statusCalls = 0
        var started = false
        var quotaLeft = true
        private var items: [DrillItem] = []

        func view() -> DrillCloudView {
            let file = { (name: String) -> DrillCloudView.File in
                self.started
                    ? .init(status: "done", url: "https://x.supabase.co/storage/v1/object/sign/drill_audio/ab/\(name).mp3?t=1",
                            duration_ms: 3000, short_end_ms: nil)
                    : .init(status: "pending", url: nil, duration_ms: nil, short_end_ms: nil)
            }
            var info = DrillCloudView.Info(id: "srv-1", title: "Bio", subject: "Biologi", grade: "åk 8", covers: "",
                                           long_words: 90, shared_from: nil)
            info.audio_started = started
            return DrillCloudView(drill: info, items: items.enumerated().map { i, item in
                DrillCloudView.Item(id: "i\(i)", position: i, question: item.question, short: item.short, long: item.long,
                                    audio: .init(question: file("q\(i)"), long: file("l\(i)")))
            }, audio: .init(done: started ? items.count * 2 : 0, total: items.count * 2, failed: 0))
        }

        /// As a real server: the answer takes a moment, so other tasks run meanwhile.
        var yieldsInSave = false

        /// What `save` answers instead of saving (K90: 402 when the credits do not cover a new exam).
        var saveError: DrillCloudError?

        func save(_ drill: Drill) async throws(DrillCloudError) -> DrillCloudView {
            if yieldsInSave { await Task.yield(); await Task.yield() }
            if let saveError { throw saveError }
            saves.append(DrillCloudClient.saveBody(drill))
            items = drill.items
            return view()
        }
        /// Run when `status` is asked (a test removes the exam here, as the user does while the question is on its way).
        var onStatus: (() -> Void)?
        /// What `status` answers instead of the view (404 once the exam is gone on the server).
        var statusError: DrillCloudError?

        func status(id: String) async throws(DrillCloudError) -> DrillCloudView {
            statusCalls += 1
            onStatus?()
            if let statusError { throw statusError }
            return view()
        }
        func start(id: String) async throws(DrillCloudError) -> DrillCloudView {
            startCalls += 1
            guard quotaLeft else {
                throw .refused(status: 402, code: "quota_exceeded", message: "Du har inga frågor kvar den här månaden.")
            }
            started = true
            return view()
        }
        func list() async throws(DrillCloudError) -> [DrillCloudListEntry] { [] }
        func delete(id: String) async throws(DrillCloudError) {}
        func share(id: String) async throws(DrillCloudError) -> DrillShareLink { throw .offline("test") }
        func importShared(code: String) async throws(DrillCloudError) -> DrillCloudView { throw .offline("test") }
        func download(_ url: URL) async throws(DrillCloudError) -> Data { Data([1, 2, 3]) }
    }

    func setup() throws -> (DeferredCloud, DrillStore, CloudDrillAudio, Drill) {
        let folder = try A79A81RepetitionTests.folder("a107")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        var drill = A79A81RepetitionTests.bio(2)
        drill.needsUpload = true
        store.save(drill)
        return (cloud, store, audio, drill)
    }

    @Test func savingAsksForNoSound() async throws {
        let (cloud, store, audio, drill) = try setup()
        await audio.prepare(drill)
        #expect(cloud.saves.first?["defer_audio"] as? Bool == true, "K71: every save defers the sound")
        let saved = try #require(store.drill(drill.id))
        #expect(saved.awaitsAudioStart && saved.serverID == "srv-1")
        #expect(cloud.statusCalls == 0, "nothing to wait for before Starta prov")
        #expect(audio.problem(for: saved) == nil, "no 'Ljudet dröjer' for sound nobody asked for")
        #expect(audio.progress(for: saved).ready == 0)
        let text = DrillCloudClient.saveBody(Drill.text(title: "T", summary: A79A81RepetitionTests.summary,
                                                        parts: [.textPart("Hej.", part: .para)]))
        #expect(text["defer_audio"] as? Bool == true)
    }

    @Test func startaProvAsksForTheSoundAndDownloadsIt() async throws {
        let (cloud, store, audio, drill) = try setup()
        await audio.prepare(drill)
        #expect(await audio.startAudio(drill))
        #expect(cloud.startCalls == 1)
        var started = try #require(store.drill(drill.id))
        #expect(!started.awaitsAudioStart)
        for _ in 0..<200 where audio.progress(for: started).ready < 4 {
            try await Task.sleep(for: .milliseconds(5))
            started = try #require(store.drill(drill.id))
        }
        #expect(audio.progress(for: started).ready == 4 && audio.progress(for: started).total == 4,
                "followed and downloaded after the start")
        #expect(await audio.startAudio(started), "again: nothing to do, no second start")
        #expect(cloud.startCalls == 1)
    }

    @Test func anUnsavedExamIsSavedThenStarted() async throws {
        let (cloud, store, audio, drill) = try setup()
        var fresh = drill
        fresh.audioStarted = false // as a new exam saved offline would be marked by an earlier save
        store.save(fresh)
        #expect(await audio.startAudio(fresh))
        #expect(cloud.saves.count == 1 && cloud.startCalls == 1)
        #expect(store.drill(drill.id)?.serverID == "srv-1")
    }

    @Test func theMonthUsedUpIsSaidAndNothingStarts() async throws {
        let (cloud, store, audio, drill) = try setup()
        await audio.prepare(drill)
        cloud.quotaLeft = false
        #expect(await audio.startAudio(drill) == false)
        #expect(audio.problem(for: drill) == "Du har inga frågor kvar den här månaden.")
        #expect(audio.quotaExceeded.contains(drill.id))
        #expect(store.drill(drill.id)?.awaitsAudioStart == true)
    }

    @Test func startaProvOnTheModelStartsTheSoundAndThePlayer() async throws {
        let (cloud, store, audio, drill) = try setup()
        await audio.prepare(drill)
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() },
                                        makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a107-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        let saved = try #require(store.drill(drill.id))
        #expect(model.awaitsAudioStart(saved) && model.canStart(saved), "Starta prov is on before any sound")
        await model.start(saved)
        #expect(cloud.startCalls == 1)
        #expect(session.player != nil && model.showsPlayer, "the player waits for each question's sound")
        #expect(!model.awaitsAudioStart(saved))
    }

    /// Toby (moln) T24, 2026-11-15 (small): the card of a new exam said "Ljud: 0 av 6 klara" for a moment, until the
    /// server's first answer made it "Ljudet görs när du startar". A new exam has asked for no sound from the start.
    @Test func aNewExamAwaitsStartaProvBeforeTheServerAnswers() async throws {
        let (cloud, store, audio, _) = try setup()
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() },
                                        makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "a107-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        let made = model.save(A79A81RepetitionTests.bio(3))
        #expect(made.serverID == nil, "the server has not answered yet")
        #expect(made.awaitsAudioStart && model.awaitsAudioStart(made), "no 'Ljud: 0 av 6 klara' before Starta prov")

        // An exam that is on the server and started stays started when it is changed.
        var started = A79A81RepetitionTests.bio(2)
        started.serverID = "srv-9"
        store.save(started)
        started.title = "Bio 2"
        #expect(!model.save(started).awaitsAudioStart)
    }

    @Test func anOlderServerCountsAsStarted() throws {
        var info = DrillCloudView.Info(id: "x")
        #expect(Drill.from(DrillCloudView(drill: info, items: [], audio: .init(done: 0, total: 0))).audioStarted == nil)
        info.audio_started = true
        #expect(Drill.from(DrillCloudView(drill: info, items: [], audio: .init(done: 0, total: 0))).awaitsAudioStart == false)
    }
}
