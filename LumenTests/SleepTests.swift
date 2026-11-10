import Foundation
import Testing
@testable import Lumen

/// A49 (D123): a night's summary, its timeline, and the 30 days the nights are kept.
@MainActor
@Suite struct SleepTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000) // whole seconds

    private static func night() -> SleepNight {
        var night = SleepNight(start: start, end: start.addingTimeInterval(3600))
        night.talks = [SleepTalk(at: start.addingTimeInterval(65), seconds: 4, text: "nej inte nu", clip: "a.caf"),
                       SleepTalk(at: start.addingTimeInterval(2500), seconds: 3, text: nil, clip: "b.caf")]
        night.snores = (0..<15).map { start.addingTimeInterval(1300 + Double($0) * 5) } // 20–30 min
        night.snoreSeconds = 400
        night.noises = (0..<6).map { start.addingTimeInterval(1900 + Double($0) * 20) } // 30–40 min
        return night
    }

    @Test func theSummaryAndTheTimeline() {
        let night = Self.night()
        #expect(night.talkLine == "Du pratade 2 gånger i sömnen")
        #expect(night.snoreMinutes == 7)
        let kinds = night.timeline().map(\.kind)
        #expect(kinds == [.talk, .calm, .snoring, .restless, .talk, .calm])
        #expect(night.restlessPeriods == 1)
        var quiet = SleepNight(start: Self.start, end: Self.start.addingTimeInterval(1200))
        #expect(quiet.talkLine == "Du pratade inte i sömnen")
        quiet.talks = [SleepTalk(at: Self.start, seconds: 2, text: "hej", clip: "c.caf")]
        #expect(quiet.talkLine == "Du pratade 1 gång i sömnen")
        #expect(SleepNight(start: Self.start).timeline().isEmpty, "a night still running has no timeline yet")
    }

    @Test func nightsAreKeptThirtyDaysWithTheirClips() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sleep-\(UUID().uuidString)")
        let store = SleepStore(directory: directory)
        let old = SleepNight(start: Self.start, end: Self.start.addingTimeInterval(3600))
        let recent = SleepNight(start: Self.start.addingTimeInterval(40 * 86_400), end: Self.start.addingTimeInterval(40 * 86_400 + 3600))
        store.save(old)
        store.save(recent)
        try FileManager.default.createDirectory(at: store.folder(for: old), withIntermediateDirectories: true)
        #expect(store.latest?.id == recent.id)
        store.removeOld(now: Self.start.addingTimeInterval(45 * 86_400))
        #expect(store.nights.map(\.id) == [recent.id])
        #expect(!FileManager.default.fileExists(atPath: store.folder(for: old).path), "the clips go with the night")
        let again = SleepStore(directory: directory)
        #expect(again.nights == [recent], "saved and read back")
    }
}
