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

    static func view(_ files: [(DrillCloudView.File, DrillCloudView.File)], failed: Int) -> DrillCloudView {
        DrillCloudView(drill: .init(id: "srv", title: "Bio", subject: "Biologi", grade: "åk 8", covers: "", long_words: 90,
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
