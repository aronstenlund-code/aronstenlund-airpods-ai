import Foundation
import Testing
@testable import Lumen

/// Toby 2's T24 findings L2, L5 and L6 (`reports/apptest/2026-11-15-0250-toby2-t24-hela-flodet.md`). L3 is in
/// `A93ChatGPTImportTests`. Skenmoln, 0 ElevenLabs (D180).
@MainActor
@Suite struct T24FindingsTests {
    typealias MockCloud = A79A81RepetitionTests.MockCloud

    // MARK: L2

    @Test func anImportWithoutANameIsNamedAfterItsFirstQuestion() {
        let q = { (text: String) in DrillItem(question: text, short: "K.", long: "K.") }
        #expect(RepetitionModel.importTitle([q("Vad är magma?")]) == "Vad är magma")
        #expect(RepetitionModel.importTitle([]) == "Prov")
        let long = RepetitionModel.importTitle([q("Varför får vissa vulkaner explosiva utbrott när andra inte får det?")])
        #expect(long == "Varför får vissa vulkaner explosiva …")
        #expect(long.count <= 42)
    }

    // MARK: L5, L6

    static func file(_ status: String, error: String? = nil) -> DrillCloudView.File {
        DrillCloudView.File(status: status, url: nil, duration_ms: nil, short_end_ms: nil, error: error)
    }

    static func view(_ files: [(DrillCloudView.File, DrillCloudView.File)], failed: Int, id: String = "srv") -> DrillCloudView {
        DrillCloudView(drill: .init(id: id, title: "Bio", subject: "Biologi", grade: "åk 8", covers: "", long_words: 90,
                                    shared_from: nil),
                       items: files.enumerated().map { i, pair in
                           DrillCloudView.Item(id: "item-\(i)", position: i, question: "Varför \(i)?", short: "Kort \(i).",
                                               long: "Kort \(i). Mer.", audio: .init(question: pair.0, long: pair.1))
                       },
                       audio: .init(done: 0, total: files.count * 2, failed: failed))
    }

    func prepared(_ view: DrillCloudView, slowAfter: Duration = .seconds(20), maxPolls: Int = 5) async throws -> (CloudDrillAudio, Drill) {
        let folder = try A79A81RepetitionTests.folder("t24")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = MockCloud()
        cloud.views["srv"] = view
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1),
                                    maxPolls: maxPolls)
        audio.slowAfter = slowAfter
        var drill = A79A81RepetitionTests.bio(2)
        drill.serverID = "srv"
        store.save(drill)
        await audio.prepare(drill)
        drill = try #require(store.drill(drill.id))
        return (audio, drill)
    }

    @Test func theVoiceServiceBeingOutIsSaidAtTheFirstFailedFile() async throws {
        // One question's files failed with audio_unavailable, the other's are still waiting: said at once (L5).
        let view = Self.view([(Self.file("failed", error: "audio_unavailable"), Self.file("failed", error: "audio_unavailable")),
                              (Self.file("pending"), Self.file("pending"))], failed: 2)
        let (audio, drill) = try await prepared(view)
        #expect(audio.problem(for: drill) == CloudDrillAudio.unavailableLine)
    }

    @Test func soundThatDoesNotComeIsSaidAfterAWhile() async throws {
        let view = Self.view([(Self.file("pending"), Self.file("pending"))], failed: 0)
        let (audio, drill) = try await prepared(view, slowAfter: .milliseconds(3), maxPolls: 10)
        #expect(audio.problem(for: drill) == CloudDrillAudio.slowLine, "L6: \"Ljud: 0 av 2 klara\" says why")

        let (quick, other) = try await prepared(view, slowAfter: .seconds(20), maxPolls: 3)
        #expect(quick.problem(for: other) == nil, "not before the time")
    }
}

@MainActor
@Suite struct T24QuotaKnownTests {
    @Test func theQuotaIsUnknownUntilTheServerSaidIt() throws {
        let folder = try A79A81RepetitionTests.folder("t24q")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A79A81RepetitionTests.MockCloud()
        let model = RepetitionModel(store: store,
                                    session: RepetitionSession(inputs: [], activatesAudioSession: false),
                                    maker: MockDrillMaker(), audio: DeviceVoiceDrillAudio(folder: folder, makesSound: false),
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        #expect(!model.quotaIsKnown, "L4: no 20 before the quota has come")
        model.quota = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"used":3,"limit":15,"per":"month"}"#.utf8))
        #expect(model.quotaIsKnown)
    }
}

/// Toby (moln) T24 L5, 2026-11-15: after a relaunch the Simulator is a new anonymous account (D183), so `status` of an
/// exam uploaded before answers 404. The card on Start (A100) then said "Provet finns inte" until the next open, never
/// "Ljudet kan inte göras just nu", though the exam is on the phone.
@MainActor
@Suite struct T24RelaunchTests {
    @MainActor final class NewAccountCloud: DrillCloudSyncing {
        var saves: [Drill] = []
        func save(_ drill: Drill) async throws(DrillCloudError) -> DrillCloudView {
            saves.append(drill)
            return T24FindingsTests.view(drill.items.map { _ in
                (T24FindingsTests.file("failed", error: "audio_unavailable"), T24FindingsTests.file("failed", error: "audio_unavailable"))
            }, failed: drill.items.count * 2, id: "new-srv")
        }
        func status(id: String) async throws(DrillCloudError) -> DrillCloudView {
            throw .refused(status: 404, code: "not_found", message: "Provet finns inte")
        }
        func list() async throws(DrillCloudError) -> [DrillCloudListEntry] { [] }
        func delete(id: String) async throws(DrillCloudError) {}
        func share(id: String) async throws(DrillCloudError) -> DrillShareLink { throw .offline("test") }
        func importShared(code: String) async throws(DrillCloudError) -> DrillCloudView { throw .offline("test") }
        func download(_ url: URL) async throws(DrillCloudError) -> Data { Data([1, 2, 3]) }
    }

    @Test func afterARelaunchAsANewAccountTheCardSaysTheSoundProblemNotNotFound() async throws {
        let folder = try A79A81RepetitionTests.folder("t24r")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = NewAccountCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 5)
        var drill = A79A81RepetitionTests.bio(2)
        drill.serverID = "old-srv" // uploaded by the account before the relaunch
        store.save(drill)

        await audio.prepare(drill)

        #expect(audio.problem(for: drill) == CloudDrillAudio.unavailableLine, "A100: the card on Start says the sound's problem")
        #expect(cloud.saves.count == 1, "saved again under the new account at once, not at the next open")
        #expect(store.drill(drill.id)?.serverID == "new-srv")
    }
}

/// Toby (moln) T24-M1 (D189): Provläge said "Lägg till prov" after an exam was made in the repetition flow, and Mina
/// svar came only with an exam added there. The two lists are one now: every repetition exam is a plan.
@MainActor
@Suite struct T24OneExamListTests {
    func store() throws -> ExamPlanStore {
        ExamPlanStore(directory: try A79A81RepetitionTests.folder("t24m1"))
    }

    @Test func aRepetitionExamIsAnExamInProvlage() throws {
        let plans = try store()
        #expect(plans.upcoming().isEmpty, "before: 'Har du prov snart? Lägg till prov'")
        var drill = A79A81RepetitionTests.bio(2)
        drill.title = "Fotosyntes"
        plans.sync(with: [drill])
        let plan = try #require(plans.upcoming().first)
        #expect(plan.id == drill.id && plan.drillID == drill.id, "Mina svar are kept under the exam's own id")
        #expect(plan.name == "Fotosyntes")
        #expect(!plan.hasDate && plan.whenLine() == ExamPlan.noDateLine)
        #expect(plans.upcomingDated().isEmpty, "no countdown, study plan or widget without a real date")
    }

    @Test func theListFollowsTheRepetitionExams() throws {
        let plans = try store()
        let said = ExamPlan(grade: nil, area: .no, subject: "Kemi", date: Date().addingTimeInterval(3 * 86_400))
        plans.save(said) // an exam said aloud in Provläge
        var drill = A79A81RepetitionTests.bio(1)
        plans.sync(with: [drill])
        #expect(plans.upcoming().map(\.id) == [said.id, drill.id], "dated first, then the repetition exams")
        drill.title = "Bio åk 8"
        plans.sync(with: [drill])
        #expect(plans.plans.first { $0.drillID == drill.id }?.name == "Bio åk 8")
        plans.sync(with: [])
        #expect(plans.plans.map(\.id) == [said.id], "a deleted exam leaves; the one said aloud stays")
        let reloaded = ExamPlanStore(directory: try A79A81RepetitionTests.folder("t24m1b"))
        #expect(reloaded.plans.isEmpty)
    }

    @Test func plansSavedBeforeD189StillLoad() throws {
        let json = #"[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","area":"no","subject":"Biologi","date":800000000,"course":"","topics":""}]"#
        let plans = try JSONDecoder().decode([ExamPlan].self, from: Data(json.utf8))
        #expect(plans.first?.hasDate == true && plans.first?.drillID == nil && plans.first?.name == "Biologiprovet")
    }
}

/// Toby (moln) T27/T28: the Debug hook for AirPods presses from a UI test.
@MainActor
@Suite struct TestPressesHookTests {
    @Test func onlyWithTheLaunchEnvironment() {
        let session = RepetitionSession(inputs: [], activatesAudioSession: false)
        #expect(TestPresses(session: session, environment: [:], listen: false) == nil)
        #expect(TestPresses(session: session, environment: ["LUMEN_TEST_PRESSES": "0"], listen: false) == nil)
        #expect(TestPresses(session: session, environment: ["LUMEN_TEST_PRESSES": "1"], listen: false) != nil)
    }

    @Test func aNotificationIsAPressInTheReadingMode() throws {
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() },
                                        makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "presses-\(UUID())")),
                                        activatesAudioSession: false)
        let drill = Drill.from(try A105TextDrillTests.view())
        session.startReading(drill, at: 1) { part in
            ReadingAudio(url: URL(fileURLWithPath: "/tmp/p\(part).mp3"), times: part == 0 ? [0...1] : [0...1.8, 1.9...4])
        }
        let hook = try #require(TestPresses(session: session, environment: ["LUMEN_TEST_PRESSES": "1"], listen: false))
        hook.press(named: "earmind.test.press.2")
        #expect(session.reader?.sentenceIndex == 2, "2 = next sentence")
        hook.press(named: "earmind.test.press.3")
        #expect(session.reader?.sentenceIndex == 1, "3 = previous sentence")
        hook.press(named: "earmind.test.press.1")
        #expect(session.reader?.isPaused == true, "1 = pause")
        hook.press(named: "earmind.test.press.9")
        #expect(hook.received == [.short, .pauseToggle, .long])
        #expect(TestPresses.event(for: "earmind.test.press.1") == .long)
    }
}

/// Toby (moln) T28: the Debug hook for material in Nytt prov.
@MainActor
@Suite struct TestMaterialHookTests {
    @Test func onlyWithTheLaunchEnvironment() {
        #expect(TestMaterial.text(environment: [:]) == nil)
        #expect(TestMaterial.text(environment: ["LUMEN_TEST_MATERIAL": "  "]) == nil)
        #expect(TestMaterial.text(environment: ["LUMEN_TEST_MATERIAL": "Fotosyntes\\nVäxter gör socker."])
                == "Fotosyntes\nVäxter gör socker.")
        #expect(TestMaterial.text(environment: ["LUMEN_TEST_MATERIAL": String(repeating: "a", count: 50_000)])?.count == 40_000)
    }
}

/// Toby (moln) T27/T31, 2026-11-16: Start showed two exams after a ChatGPT import left ~3 s after Spara frågorna. The
/// server had stored the exam, but its reply (the server id) had not reached the phone yet, so `refresh` took the
/// server's exam for another phone's and added it a second time.
@MainActor
@Suite struct DuplicateAfterImportTests {
    @Test func anExamWhoseSaveIsOnItsWayIsNotAddedTwice() async throws {
        let folder = try A79A81RepetitionTests.folder("dup")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A79A81RepetitionTests.MockCloud()
        var local = A79A81RepetitionTests.bio(3)
        local.needsUpload = true // saved on the phone; the server's reply has not come back yet
        store.save(local)
        // The server already has it (the save request arrived) and lists it.
        _ = try await cloud.save(local)
        cloud.listed = [DrillCloudListEntry(id: "server-1", title: local.title, items: 3, updated_at: nil)]
        cloud.views["server-1"] = cloud.view(id: "server-1")
        let model = RepetitionModel(store: store,
                                    session: RepetitionSession(inputs: [], activatesAudioSession: false),
                                    maker: MockDrillMaker(),
                                    audio: CloudDrillAudio(cloud: cloud, store: store, folder: folder,
                                                           pollInterval: .milliseconds(1), maxPolls: 1),
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        await model.refresh()
        #expect(store.drills.count == 1, "one exam on Start, not two")
        #expect(store.drills.first?.id == local.id && store.drills.first?.serverID == "server-1",
                "the phone's own exam is the server's (its edits and place are kept)")
    }

    @Test func anotherPhonesExamIsStillAdded() async throws {
        let folder = try A79A81RepetitionTests.folder("dup2")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A79A81RepetitionTests.MockCloud()
        var other = A79A81RepetitionTests.bio(2)
        other.items[0].question = "En helt annan fråga?"
        _ = try await cloud.save(other)
        cloud.listed = [DrillCloudListEntry(id: "server-2", title: "Bio", items: 2, updated_at: nil)]
        cloud.views["server-2"] = cloud.view(id: "server-2")
        var mine = A79A81RepetitionTests.bio(2)
        mine.needsUpload = true
        store.save(mine)
        let model = RepetitionModel(store: store,
                                    session: RepetitionSession(inputs: [], activatesAudioSession: false),
                                    maker: MockDrillMaker(),
                                    audio: CloudDrillAudio(cloud: cloud, store: store, folder: folder,
                                                           pollInterval: .milliseconds(1), maxPolls: 1),
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        await model.refresh()
        #expect(store.drills.count == 2, "different questions: a different exam")
    }
}
