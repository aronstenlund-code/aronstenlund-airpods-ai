import Foundation
import Testing
@testable import Lumen

/// A79–A81 (D142, D143, D145, D146): making, storing, sound, the AirPods check and sharing, without a server and
/// without ElevenLabs (K45–K47 replaced by mocks; silent files).
@MainActor
@Suite struct A79A81RepetitionTests {
    static func defaults() -> UserDefaults { UserDefaults(suiteName: "A79-\(UUID().uuidString)") ?? .standard }

    static func folder(_ name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static let summary = DrillSummary(subject: "Biologi", grade: "åk 8", covers: "Fotosyntes")

    // MARK: A79

    @Test func theMockMakesTheAskedNumberWithTheShortAnswerFirst() async throws {
        let draft = try await MockDrillMaker().make(DrillMaterial(text: "Fotosyntes. Växter gör socker."), subject: nil,
                                                    grade: nil, correction: nil, questions: 7, longWords: 90)
        #expect(draft.items.count == 7)
        for item in draft.items { #expect(item.long.hasPrefix(item.short), "D145: \(item.question)") }
        #expect(draft.summary.covers.contains("Fotosyntes"))
    }

    @Test func theMockFillsMissingAnswersAndKeepsTheOrder() async throws {
        let items = [DrillItem(question: "Varför A?", short: "", long: ""),
                     DrillItem(question: "Hur B?", short: "Redan.", long: "Redan. Klart.")]
        let filled = try await MockDrillMaker().answers(for: items, summary: Self.summary, notes: "", longWords: 90)
        #expect(filled.map(\.id) == items.map(\.id))
        #expect(!filled[0].short.isEmpty && filled[0].long.hasPrefix(filled[0].short))
        #expect(filled[1].short == "Redan.")
    }

    @Test func noMaterialIsAnError() async {
        await #expect(throws: DrillMakingError.noMaterial) {
            _ = try await MockDrillMaker().make(DrillMaterial(), subject: nil, grade: nil, correction: nil,
                                                questions: 20, longWords: 90)
        }
    }

    @Test func settingsFollowD146() {
        let settings = DrillSettings()
        #expect(settings.questions == 20)
        #expect(settings.length.words == 90)
        #expect(DrillSettings.Length.shorter.words < 90 && DrillSettings.Length.longer.words > 90)
    }

    @Test func theFirstSentenceIsTheShortAnswer() {
        #expect(DrillItem.firstSentence("Klorofyll fångar ljus. Det ger energi.") == "Klorofyll fångar ljus.")
        #expect(DrillItem.firstSentence("Varför? För att.") == "Varför?")
        #expect(DrillItem.firstSentence("En mening utan punkt") == "En mening utan punkt")
        #expect(DrillItem.firstSentence("  Ett tal 3.5 är inte ett slut. Nästa.") == "Ett tal 3.5 är inte ett slut.")
    }

    @Test func theStoreKeepsEditsOrderAndDeletes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("drills-\(UUID().uuidString).json")
        let store = DrillStore(url: url)
        var drill = Drill(title: "Bio", summary: Self.summary,
                          items: (0..<3).map { DrillItem(question: "F\($0)", short: "K\($0).", long: "K\($0). L.") })
        store.save(drill)
        drill.items.move(fromOffsets: [2], toOffset: 0)
        drill.items[1].question = "Ändrad"
        store.save(drill)
        let other = Drill(title: "Hist", summary: DrillSummary(subject: "", grade: "", covers: ""), items: [])
        store.save(other)
        store.delete(other.id)

        let reopened = DrillStore(url: url) // R5: after a restart
        #expect(reopened.drills.count == 1)
        #expect(reopened.drills.first?.items.map(\.question) == ["F2", "Ändrad", "F1"])
    }

    @Test func anOldStoreFileStillOpens() throws {
        // drills.json written by A79's first draft (no server fields) must still load after the K46 fields came.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("drills-\(UUID().uuidString).json")
        let json = """
        [{"id":"\(UUID().uuidString)","title":"Bio","summary":{"subject":"B","grade":"8","covers":"x"},
          "items":[{"id":"\(UUID().uuidString)","question":"F?","short":"K.","long":"K. L."}],
          "createdAt":700000000,"questionCount":1,"longWords":90}]
        """
        try Data(json.utf8).write(to: url)
        let store = DrillStore(url: url)
        #expect(store.drills.first?.items.first?.questionAudio == nil)
        #expect(store.drills.first?.serverID == nil)
    }

    // MARK: Sound: the iPhone's voice (mock mode)

    @Test func theSameTextGetsTheSameFileAndAnEditOnlyItsOwn() {
        let a = DrillAudioKey.name(text: "Varför behövs klorofyll?", voice: "sv-SE")
        #expect(a == DrillAudioKey.name(text: "varför  behövs   klorofyll?", voice: "sv-SE"), "normalised (D144)")
        #expect(a != DrillAudioKey.name(text: "Varför behövs klorofyll?", voice: "en-US"), "per voice")
        #expect(a != DrillAudioKey.name(text: "Varför behövs ljus?", voice: "sv-SE"))
    }

    @Test func tracksWaitForEveryFile() throws {
        let audio = DeviceVoiceDrillAudio(folder: try Self.folder("drill-audio"), makesSound: false)
        let drill = Drill(title: "T", summary: Self.summary, items: [DrillItem(question: "F?", short: "K.", long: "K. L.")])
        #expect(audio.tracks(for: drill) == nil)
        #expect(audio.progress(for: drill).ready == 0 && audio.progress(for: drill).total == 3)
        for text in ["F?", "K.", "K. L."] {
            try WAVWriter.write(samples: [0, 0, 0], sampleRate: 16_000, to: audio.url(text: text))
        }
        #expect(audio.progress(for: drill).ready == 3)
        let track = try #require(audio.tracks(for: drill)?.first)
        #expect(track.question == audio.url(text: "F?"))
        #expect(track.short == .file(audio.url(text: "K.")))
    }

    // MARK: Sound and storage: K46 (mocked server, silent files)

    @MainActor final class MockCloud: DrillCloudSyncing {
        var saves: [Drill] = []
        var statusCalls = 0
        var downloads: [URL] = []
        /// Files done per status call: the server makes them in play order.
        var donePerCall = 2
        var refuseSave: DrillCloudError?
        var listed: [DrillCloudListEntry] = []
        var views: [String: DrillCloudView] = [:]
        var deleted: [String] = []
        var shareRefusal: DrillCloudError?
        private var done = 0
        private var items: [DrillItem] = []

        func view(id: String) -> DrillCloudView {
            let files = items.enumerated().map { i, item in
                DrillCloudView.Item(
                    id: "item-\(i)", position: i, question: item.question, short: item.short, long: item.long,
                    audio: .init(question: file(2 * i, "q\(i)", long: false), long: file(2 * i + 1, "l\(i)", long: true)))
            }
            return DrillCloudView(drill: .init(id: id, title: "Bio", subject: "Biologi", grade: "åk 8", covers: "Fotosyntes",
                                               long_words: 90, shared_from: nil),
                                  items: files, audio: .init(done: min(done, items.count * 2), total: items.count * 2, failed: 0))
        }

        private func file(_ seq: Int, _ name: String, long: Bool) -> DrillCloudView.File {
            seq < done ? .init(status: "done", url: "https://x.supabase.co/storage/v1/object/sign/drill_audio/ab/\(name).mp3?token=t",
                               duration_ms: 4000, short_end_ms: long ? 1500 : nil)
                : .init(status: "pending", url: nil, duration_ms: nil, short_end_ms: nil)
        }

        func save(_ drill: Drill) async throws(DrillCloudError) -> DrillCloudView {
            if let refuseSave { throw refuseSave }
            saves.append(drill)
            items = drill.items
            done = min(done + donePerCall, items.count * 2)
            return view(id: drill.serverID ?? "server-1")
        }

        func status(id: String) async throws(DrillCloudError) -> DrillCloudView {
            if let v = views[id] { return v }
            statusCalls += 1
            done = min(done + donePerCall, items.count * 2)
            return view(id: id)
        }

        func list() async throws(DrillCloudError) -> [DrillCloudListEntry] { listed }
        func delete(id: String) async throws(DrillCloudError) { deleted.append(id) }

        func share(id: String) async throws(DrillCloudError) -> DrillShareLink {
            if let shareRefusal { throw shareRefusal }
            return DrillShareLink(code: "abcd2345", url: "https://earmind.ai/p/abcd2345", app_url: "earmind://prov/abcd2345")
        }

        func importShared(code: String) async throws(DrillCloudError) -> DrillCloudView {
            guard let v = views["shared"] else { throw .refused(status: 404, code: "share_not_found", message: "Länken fungerar inte längre.") }
            return v
        }

        func download(_ url: URL) async throws(DrillCloudError) -> Data {
            downloads.append(url)
            return Data([1, 2, 3])
        }
    }

    static func bio(_ n: Int = 2) -> Drill {
        Drill(title: "Bio", summary: summary,
              items: (0..<n).map { DrillItem(question: "Varför \($0)?", short: "Kort \($0).", long: "Kort \($0). Mer.") })
    }

    @Test func theServerMakesTheSoundAndThePhoneDownloadsIt() async throws {
        let folder = try Self.folder("k46")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = MockCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1))
        var drill = Self.bio(2)
        drill.needsUpload = true
        store.save(drill)
        #expect(audio.progress(for: drill).ready == 0 && audio.progress(for: drill).total == 4, "Kelly Ke49 §4.7: 2 files per question")

        await audio.prepare(drill)

        let saved = try #require(store.drill(drill.id))
        #expect(cloud.saves.count == 1, "saved once, then only status")
        #expect(cloud.statusCalls >= 1)
        #expect(saved.serverID == "server-1" && saved.needsUpload == nil)
        #expect(saved.items.map(\.serverID) == ["item-0", "item-1"])
        #expect(audio.progress(for: saved).ready == 4 && audio.progress(for: saved).total == 4)
        #expect(cloud.downloads.count == 4)
        let track = try #require(audio.track(for: saved, at: 1))
        #expect(track.question.lastPathComponent == "q1.mp3")
        #expect(track.short == .prefix(ofLongUntil: 1.5), "D145: the short answer is the long file up to short_end_ms")
    }

    @Test func aRateLimitIsToldAndNothingBreaks() async throws {
        let folder = try Self.folder("k46")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = MockCloud()
        cloud.refuseSave = .refused(status: 429, code: "rate_limited", message: "Du har gjort mycket ljud i dag.")
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1))
        var drill = Self.bio(1)
        drill.needsUpload = true
        store.save(drill)
        await audio.prepare(drill)
        #expect(audio.problem(for: drill)?.hasPrefix("Dagens gräns för nytt ljud är nådd.") == true, "Ke50 §13")
        #expect(store.drill(drill.id)?.needsUpload == true, "sent again on the next open")
    }

    @Test func anEditKeepsTheOtherQuestionsSound() throws {
        let folder = try Self.folder("a79")
        let cloud = MockCloud()
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let model = RepetitionModel(store: store,
                                    session: RepetitionSession(inputs: [], defaults: Self.defaults(), activatesAudioSession: false),
                                    maker: MockDrillMaker(), audio: CloudDrillAudio(cloud: cloud, store: store, folder: folder,
                                                                          pollInterval: .milliseconds(1), maxPolls: 5),
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        var drill = Self.bio(2)
        for i in 0..<2 {
            drill.items[i].questionAudio = "q\(i).mp3"
            drill.items[i].longAudio = "l\(i).mp3"
            drill.items[i].shortEndMs = 1500
        }
        store.save(drill)
        drill.items[1].long = "Kort 1. Ändrat."
        let saved = model.save(drill)
        #expect(saved.items[0].longAudio == "l0.mp3", "unchanged: same sound")
        #expect(saved.items[1].questionAudio == "q1.mp3", "the question did not change")
        #expect(saved.items[1].longAudio == nil && saved.items[1].shortEndMs == nil, "only this answer gets new sound")
        #expect(saved.needsUpload == true)
    }

    @Test func theSaveBodyKeepsOrderAndIds() throws {
        var drill = Self.bio(2)
        drill.serverID = "d1"
        drill.items[0].serverID = "i0"
        let body = DrillCloudClient.saveBody(drill)
        #expect(body["action"] as? String == "save")
        let info = try #require(body["drill"] as? [String: Any])
        #expect(info["id"] as? String == "d1" && info["long_words"] as? Int == 90)
        let items = try #require(body["items"] as? [[String: Any]])
        #expect(items.map { $0["question"] as? String } == ["Varför 0?", "Varför 1?"])
        #expect(items[0]["id"] as? String == "i0")
        #expect((items[1]["id"] as? String) == nil)
    }

    @Test func theServersMessageIsShown() {
        let data = Data(#"{"error":{"code":"rate_limited","message":"Spara provet igen i morgon.","fallback":false}}"#.utf8)
        #expect(DrillCloudClient.refusal(status: 429, data: data)
            == .refused(status: 429, code: "rate_limited", message: "Spara provet igen i morgon."))
        #expect(DrillCloudClient.refusal(status: 502, data: Data()).userMessage.contains("Försök igen"))
    }

    @Test func anExamFromAnotherPhoneIsAdded() async throws {
        // R5: logged in on another phone, the list on the server brings the exam.
        let folder = try Self.folder("r5")
        let cloud = MockCloud()
        _ = try await cloud.save(Self.bio(2))
        cloud.listed = [DrillCloudListEntry(id: "server-1", title: "Bio", items: 2, updated_at: nil)]
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let model = RepetitionModel(store: store,
                                    session: RepetitionSession(inputs: [], defaults: Self.defaults(), activatesAudioSession: false),
                                    maker: MockDrillMaker(), audio: DeviceVoiceDrillAudio(folder: folder, makesSound: false),
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        await model.refresh()
        #expect(store.drills.count == 1)
        #expect(store.drills.first?.serverID == "server-1")
        #expect(store.drills.first?.items.map(\.question) == ["Varför 0?", "Varför 1?"])
        // Deleted on the other phone: gone here too.
        cloud.listed = []
        await model.refresh()
        #expect(store.drills.isEmpty)
    }

    // MARK: The AirPods check (R11)

    @Test func theCheckSeesWhatArrives() {
        let hub = RemoteCommandHub()
        let defaults = Self.defaults()
        let check = ControlCheck(hub: hub, waitSeconds: 600, activatesAudio: false, defaults: defaults)
        check.begin(sound: nil)
        #expect(hub.isTakenOver)
        check.received(.toggle)
        check.received(.next)
        check.received(.previous)
        #expect(check.isDone && check.allWork)
        #expect(!check.needsEarbudSettings)
        #expect(!ControlCheck.usesEarbudLayout(defaults))
        check.end()
        #expect(!hub.isTakenOver)
    }

    @Test func airPodsOneAndTwoGetTheEarbudSettings() {
        // AirPods 2: double-tap per earbud. Two presses arrive as play/pause on that earbud, three never arrive.
        let defaults = Self.defaults()
        let check = ControlCheck(hub: RemoteCommandHub(), waitSeconds: 600, activatesAudio: false, defaults: defaults)
        check.begin(sound: nil)
        check.received(.toggle)
        check.received(.toggle)
        check.timedOut()
        #expect(check.isDone && !check.allWork)
        #expect(check.passed == [.one])
        #expect(check.needsEarbudSettings)
        #expect(ControlCheck.usesEarbudLayout(defaults), "spec §3: 1 press pauses during an answer")
        check.restart()
        #expect(check.step == .one && check.passed.isEmpty)
        check.end()
    }

    @Test func skippingIsNotTheSameAsNotArriving() {
        // Kelly B4: "Hoppa över" is shown as skipped, a press that never came as "Kom inte fram".
        let check = ControlCheck(hub: RemoteCommandHub(), waitSeconds: 600, activatesAudio: false, defaults: Self.defaults())
        check.begin(sound: nil)
        check.received(.toggle)
        check.skip()
        check.timedOut()
        #expect(check.isDone)
        #expect(check.skipped == [.two] && check.missed == [.two, .three])
        check.end()
    }

    // MARK: A81 sharing (K47 mocked)

    @MainActor final class MockSharing: DrillSharing {
        var shared: [UUID] = []
        func link(for drill: Drill) async throws(DrillShareError) -> DrillShareResult {
            shared.append(drill.id)
            return DrillShareResult(url: DrillShareClient.url(code: "abcd2345")!, code: "abcd2345")
        }
        func importDrill(code: String) async throws(DrillShareError) -> Drill {
            Drill(title: "Delat prov", summary: Self.summary,
                  items: [DrillItem(question: "F?", short: "K.", long: "K. L.")], sharedFrom: code)
        }
        static let summary = DrillSummary(subject: "Bio", grade: "åk 8", covers: "")
    }

    func model(folder: URL, sharing: MockSharing = MockSharing()) -> RepetitionModel {
        RepetitionModel(store: DrillStore(url: folder.appendingPathComponent("drills.json")),
                        session: RepetitionSession(inputs: [], defaults: Self.defaults(), activatesAudioSession: false),
                        maker: MockDrillMaker(), audio: DeviceVoiceDrillAudio(folder: folder, makesSound: false),
                        sharing: sharing, remote: RemoteCommandHub())
    }

    @Test func shareWaitsForAllTheSound() async throws {
        let folder = try Self.folder("a81")
        let sharing = MockSharing()
        let model = model(folder: folder, sharing: sharing)
        let drill = Drill(title: "T", summary: Self.summary, items: [DrillItem(question: "F?", short: "K.", long: "K. L.")])
        model.store.save(drill)
        await #expect(throws: DrillShareError.audioNotReady(ready: 0, total: 3)) { _ = try await model.shareLink(drill) }
        #expect(sharing.shared.isEmpty, "D143: never asked before the sound is ready")
        let audio = try #require(model.audio as? DeviceVoiceDrillAudio)
        for text in ["F?", "K.", "K. L."] { try WAVWriter.write(samples: [0], sampleRate: 16_000, to: audio.url(text: text)) }
        let result = try await model.shareLink(drill)
        #expect(result.url.absoluteString == "earmind://prov/abcd2345")
    }

    @Test func theCloudShareGivesTheWebLink() async throws {
        let cloud = MockCloud()
        let sharing = DrillShareClient(cloud: cloud)
        var drill = Self.bio(1)
        await #expect(throws: DrillShareError.audioNotReady(ready: 0, total: 2)) { _ = try await sharing.link(for: drill) }
        drill.serverID = "server-1"
        let result = try await sharing.link(for: drill)
        #expect(result.url.absoluteString == "https://earmind.ai/p/abcd2345" && result.code == "abcd2345")
        cloud.shareRefusal = .refused(status: 409, code: "audio_not_ready", message: "Delas när ljudet är klart (3 av 4)")
        await #expect(throws: DrillShareError.server("Delas när ljudet är klart (3 av 4)")) { _ = try await sharing.link(for: drill) }
        await #expect(throws: DrillShareError.notAvailable) { _ = try await DrillShareClient(cloud: nil).link(for: drill) }
    }

    @Test func aShareLinkAddsTheExam() async throws {
        let model = model(folder: try Self.folder("a81"))
        #expect(!model.handle(URL(string: "lumen-spotify://callback")!))
        #expect(model.handle(URL(string: "earmind://prov/abcd2345")!))
        for _ in 0..<50 where model.drills.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(model.drills.first?.sharedFrom == "abcd2345")
        #expect(model.importMessage == "Delat prov är tillagt.")
        #expect(model.openDrill == model.drills.first?.id)
    }

    @Test func shareCodes() {
        #expect(DrillShareClient.code(in: URL(string: "earmind://prov/XY12AB34")!) == "xy12ab34")
        #expect(DrillShareClient.code(in: URL(string: "https://earmind.ai/p/xy12ab34")!) == "xy12ab34")
        #expect(DrillShareClient.code(in: URL(string: "earmind://annat/xy12ab34")!) == nil)
        #expect(DrillShareClient.code(in: URL(string: "earmind://prov")!) == nil)
        #expect(DrillShareClient.code(in: URL(string: "https://example.com/p/xy12ab34")!) == nil)
        #expect(DrillShareClient.code(inText: "Plugga Bio med Earmind: https://earmind.ai/p/xy12ab34 ") == "xy12ab34")
        #expect(DrillShareClient.code(inText: " XY12AB34 ") == "xy12ab34")
        #expect(DrillShareClient.code(inText: "hej") == nil)
    }

    @Test func savingPutsTheShortAnswerFirst() throws {
        let model = model(folder: try Self.folder("a79"))
        let saved = model.save(Drill(title: "T", summary: Self.summary,
                                     items: [DrillItem(question: "F?", short: "Kort.", long: "Resten.")]))
        #expect(saved.items[0].long == "Kort. Resten.")
        #expect(saved.needsUpload == nil, "no server in the mock mode")
    }
}
