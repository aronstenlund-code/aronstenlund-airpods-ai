import Foundation
import Testing
@testable import Lumen

/// A79–A81 (D142, D143, D145, D146): making, storing, sound, the AirPods check and sharing, without a server and
/// without ElevenLabs (K45–K47 mocked).
@MainActor
@Suite struct A79A81RepetitionTests {
    // MARK: A79

    @Test func theMockMakesTheAskedNumberWithTheShortAnswerFirst() async throws {
        let draft = try await MockDrillMaker().make(DrillMaterial(text: "Fotosyntes. Växter gör socker."), subject: nil,
                                                    grade: nil, correction: nil, questions: 7, longWords: 90)
        #expect(draft.items.count == 7)
        for item in draft.items { #expect(item.long.hasPrefix(item.short), "D145: \(item.question)") }
        #expect(draft.summary.covers.contains("Fotosyntes"))
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

    @Test func theStoreKeepsEditsOrderAndDeletes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("drills-\(UUID().uuidString).json")
        let store = DrillStore(url: url)
        var drill = Drill(title: "Bio", summary: DrillSummary(subject: "Biologi", grade: "åk 8", covers: "x"),
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

    // MARK: Sound (K46 mocked by the iPhone's voice)

    @Test func theSameTextGetsTheSameFileAndAnEditOnlyItsOwn() {
        let a = DrillAudioKey.name(text: "Varför behövs klorofyll?", voice: "sv-SE")
        #expect(a == DrillAudioKey.name(text: "varför  behövs   klorofyll?", voice: "sv-SE"), "normalised (D144)")
        #expect(a != DrillAudioKey.name(text: "Varför behövs klorofyll?", voice: "en-US"), "per voice")
        #expect(a != DrillAudioKey.name(text: "Varför behövs ljus?", voice: "sv-SE"))
    }

    @Test func tracksWaitForEveryFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("drill-audio-\(UUID().uuidString)")
        let audio = DeviceVoiceDrillAudio(folder: folder)
        let drill = Drill(title: "T", summary: DrillSummary(subject: "", grade: "", covers: ""),
                          items: [DrillItem(question: "F?", short: "K.", long: "K. L.")])
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

    // MARK: The AirPods check (R11)

    @Test func theCheckSeesWhatArrives() {
        let hub = RemoteCommandHub()
        let check = ControlCheck(hub: hub, waitSeconds: 600, activatesAudio: false)
        check.begin(sound: nil)
        #expect(hub.isTakenOver)
        check.received(.toggle)
        check.received(.next)
        check.received(.previous)
        #expect(check.isDone && check.allWork)
        #expect(!check.needsEarbudSettings)
        check.end()
        #expect(!hub.isTakenOver)
    }

    @Test func airPodsOneAndTwoGetTheEarbudSettings() {
        // AirPods 2: double-tap per earbud. Two presses arrive as play/pause on that earbud, three never arrive.
        let check = ControlCheck(hub: RemoteCommandHub(), waitSeconds: 600, activatesAudio: false)
        check.begin(sound: nil)
        check.received(.toggle)
        check.received(.toggle)
        check.timedOut()
        #expect(check.isDone && !check.allWork)
        #expect(check.passed == [.one])
        #expect(check.needsEarbudSettings)
        check.restart()
        #expect(check.step == .one && check.passed.isEmpty)
        check.end()
    }

    // MARK: A81 sharing (K47 mocked)

    @MainActor final class MockSharing: DrillSharing {
        var shared: [UUID] = []
        func link(for drill: Drill) async throws(DrillShareError) -> URL {
            shared.append(drill.id)
            return DrillShareClient.url(code: "ABC123")!
        }
        func importDrill(code: String) async throws(DrillShareError) -> Drill {
            Drill(title: "Delat prov", summary: DrillSummary(subject: "Bio", grade: "åk 8", covers: ""),
                  items: [DrillItem(question: "F?", short: "K.", long: "K. L.")], sharedFrom: code)
        }
    }

    func model(folder: URL, sharing: MockSharing = MockSharing()) -> RepetitionModel {
        let defaults = UserDefaults(suiteName: "A81-\(UUID().uuidString)") ?? .standard
        return RepetitionModel(store: DrillStore(url: folder.appendingPathComponent("drills.json")),
                               session: RepetitionSession(inputs: [], defaults: defaults, activatesAudioSession: false),
                               maker: MockDrillMaker(), audio: DeviceVoiceDrillAudio(folder: folder),
                               sharing: sharing, remote: RemoteCommandHub())
    }

    @Test func shareWaitsForAllTheSound() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a81-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sharing = MockSharing()
        let model = model(folder: folder, sharing: sharing)
        let drill = Drill(title: "T", summary: DrillSummary(subject: "", grade: "", covers: ""),
                          items: [DrillItem(question: "F?", short: "K.", long: "K. L.")])
        model.store.save(drill)
        await #expect(throws: DrillShareError.audioNotReady(ready: 0, total: 3)) { _ = try await model.shareLink(drill) }
        #expect(sharing.shared.isEmpty, "D143: never asked before the sound is ready")
        let audio = try #require(model.audio as? DeviceVoiceDrillAudio)
        for text in ["F?", "K.", "K. L."] { try WAVWriter.write(samples: [0], sampleRate: 16_000, to: audio.url(text: text)) }
        let url = try await model.shareLink(drill)
        #expect(url.absoluteString == "earmind://prov/ABC123")
    }

    @Test func aShareLinkAddsTheExam() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a81-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let model = model(folder: folder)
        #expect(!model.handle(URL(string: "lumen-spotify://callback")!))
        #expect(model.handle(URL(string: "earmind://prov/ABC123")!))
        for _ in 0..<50 where model.drills.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(model.drills.first?.sharedFrom == "ABC123")
        #expect(model.importMessage == "Delat prov är tillagt.")
    }

    @Test func shareCodes() {
        #expect(DrillShareClient.code(in: URL(string: "earmind://prov/XY12")!) == "XY12")
        #expect(DrillShareClient.code(in: URL(string: "earmind://annat/XY12")!) == nil)
        #expect(DrillShareClient.code(in: URL(string: "earmind://prov")!) == nil)
    }

    @Test func savingPutsTheShortAnswerFirst() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a79-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let model = model(folder: folder)
        let saved = model.save(Drill(title: "T", summary: DrillSummary(subject: "", grade: "", covers: ""),
                                     items: [DrillItem(question: "F?", short: "Kort.", long: "Resten.")]))
        #expect(saved.items[0].long == "Kort. Resten.")
    }
}
