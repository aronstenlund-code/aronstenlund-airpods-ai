import Foundation
import Testing
@testable import Lumen

/// A170 (Deangelo 2026-11-27): the widget "Fortsätt öva". What it shows is what one was doing last (A168), it opens
/// the right place, and it says nothing about a said text but that there is one. No network, no credits, 0 ElevenLabs.
@MainActor
@Suite struct A170PracticeWidgetTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func quiz(_ title: String, made: TimeInterval) -> Drill {
        var drill = A79A81RepetitionTests.bio(12)
        drill.title = title
        drill.createdAt = t0.addingTimeInterval(made)
        return drill
    }

    private func text(_ title: String) -> Drill {
        Drill.text(title: title, summary: DrillSummary(subject: "", grade: "", covers: ""),
                   parts: [DrillItem.textPart("Fotosyntes. Växter gör socker. Syre blir kvar.", part: .para)])
    }

    @Test func theQuizPlayedLastWithWhereOneWas() throws {
        let bio = quiz("Biologiprovet", made: 0), history = quiz("Historiaprovet", made: 10)
        let progress = RepetitionProgress(drillID: bio.id, index: 2, savedAt: t0.addingTimeInterval(100))
        let snapshot = try #require(RepetitionModel.practiceSnapshot(exams: [history, bio], said: nil, progress: progress,
                                                                      reading: { _ in nil }, now: t0))
        #expect(snapshot.what == .quiz && snapshot.title == "Biologiprovet" && snapshot.place == 3 && snapshot.total == 12)
        #expect(snapshot.drillID == bio.id && snapshot.link == URL(string: "earmind://continue/\(bio.id.uuidString)"))
        #expect(PracticeWidgetText.line(snapshot) == "Fråga 3 av 12" && PracticeWidgetText.button(snapshot) == "Fortsätt")
    }

    @Test func aTextOrASaidTextWhenThatIsNewer() throws {
        let bio = quiz("Biologiprovet", made: 0)
        let reading = text("Fotosyntesen")
        let progress = RepetitionProgress(drillID: bio.id, index: 0, savedAt: t0.addingTimeInterval(100))
        let read = ReadingProgress(sentence: 0, savedAt: t0.addingTimeInterval(200))
        let textFirst = try #require(RepetitionModel.practiceSnapshot(exams: [bio, reading], said: nil, progress: progress,
                                                                       reading: { $0 == reading.id ? read : nil }, now: t0))
        #expect(textFirst.what == .text && textFirst.place == 1 && textFirst.total == reading.sentenceCount)
        #expect(PracticeWidgetText.line(textFirst) == "Mening 1 av \(reading.sentenceCount)")

        var said = Drill.text(title: "Min privata text", summary: DrillSummary(subject: "", grade: "", covers: ""),
                              parts: [DrillItem.textPart("Något personligt.", part: .para)])
        said.said = true
        said.createdAt = t0.addingTimeInterval(300)
        let saidFirst = try #require(RepetitionModel.practiceSnapshot(exams: [bio, reading], said: said, progress: progress,
                                                                       reading: { $0 == reading.id ? read : nil }, now: t0))
        #expect(saidFirst.what == .said && saidFirst.title.isEmpty && saidFirst.drillID == nil, "the said text itself is never written")
        #expect(saidFirst.link == PracticeWidgetSnapshot.sayLink)
        #expect(PracticeWidgetText.title(saidFirst) == "Säg i AirPods" && PracticeWidgetText.line(saidFirst) == "Spela din senaste text igen")
    }

    @Test func theNewestQuizNotStartedAndNothingAtAll() throws {
        let newest = quiz("Nytt prov", made: 50)
        let snapshot = try #require(RepetitionModel.practiceSnapshot(exams: [newest], said: nil, progress: nil,
                                                                      reading: { _ in nil }, now: t0))
        #expect(snapshot.place == nil && PracticeWidgetText.line(snapshot) == "Inte startat än" && PracticeWidgetText.button(snapshot) == "Starta")
        #expect(RepetitionModel.practiceSnapshot(exams: [], said: nil, progress: nil, reading: { _ in nil }, now: t0) == nil)
        #expect(PracticeWidgetText.emptyTitle == "Inget att öva på än")
    }

    @Test func theLinksAreReadBack() {
        let id = UUID()
        #expect(PracticeWidgetSnapshot.drillID(in: PracticeWidgetSnapshot.link(drill: id)) == id)
        #expect(PracticeWidgetSnapshot.drillID(in: URL(string: "earmind://prov/abc123")!) == nil)
        #expect(PracticeWidgetSnapshot.isSayLink(PracticeWidgetSnapshot.sayLink))
        #expect(!PracticeWidgetSnapshot.isSayLink(URL(string: "https://earmind.ai/say")!))
    }

    @Test func theLinkOpensTheQuizAndTheSnapshotIsWrittenOnlyWhenItChanges() throws {
        let folder = try A79A81RepetitionTests.folder("a170")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let defaults = try #require(UserDefaults(suiteName: "a170-\(UUID())"))
        let shared = try #require(UserDefaults(suiteName: "a170-shared-\(UUID())"))
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() }, makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: defaults, activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud, defaults: defaults)
        let drill = model.save(quiz("Biologiprovet", made: 0))

        #expect(model.handle(PracticeWidgetSnapshot.link(drill: drill.id)))
        #expect(model.openDrill == drill.id)
        model.openDrill = nil
        #expect(model.handle(PracticeWidgetSnapshot.link(drill: UUID())), "a quiz that is gone: the app opens on Start")
        #expect(model.openDrill == nil)
        #expect(model.handle(PracticeWidgetSnapshot.sayLink))

        model.updatePracticeWidget(now: t0, into: shared)
        let first = try #require(PracticeWidgetSnapshot.load(shared))
        #expect(first.title == "Biologiprovet" && first.place == nil)
        model.updatePracticeWidget(now: t0.addingTimeInterval(60), into: shared)
        #expect(PracticeWidgetSnapshot.load(shared)?.updatedAt == t0, "the same content is not written again")
        model.delete(drill)
        model.updatePracticeWidget(now: t0.addingTimeInterval(120), into: shared)
        #expect(PracticeWidgetSnapshot.load(shared) == nil, "nothing left: the widget says what one can do")
    }

    @Test func theWordsAreInBothLanguages() {
        func en(_ key: String) -> String { AppLanguage.en.bundle.localizedString(forKey: key, value: "(missing)", table: nil) }
        #expect(en("Fortsätt öva") == "Keep practicing")
        #expect(en("Inget att öva på än") == "Nothing to practice yet")
        #expect(en("Spela din senaste text igen") == "Play your latest text again")
        #expect(String(format: en("Fråga %lld av %lld"), 3, 12) == "Question 3 of 12")
    }
}
