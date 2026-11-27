import Foundation
import Testing
@testable import Lumen

/// Deangelo 2026-11-27 04:10: the app starts fast. What can wait runs after the first screen
/// (`AppContainer.startAfterFirstFrame`): the clean-up of unused exam sound, the removal of old nights; the history's
/// clean-up is cheaper and done once; the time to the first screen is measured at every launch.
@MainActor
@Suite struct StartupTests {
    @Test func theExamSoundIsNotCleanedBeforeTheFirstScreen() throws {
        let folder = try A79A81RepetitionTests.folder("start")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let unused = folder.appendingPathComponent("unused.mp3")
        try Data([1, 2, 3]).write(to: unused)
        _ = CloudDrillAudio(cloud: A79A81RepetitionTests.MockCloud(), store: store, folder: folder)
        #expect(FileManager.default.fileExists(atPath: unused.path), "not in init: that is before the first screen")
    }

    @Test func afterTheFirstScreenOnlyFilesFromBeforeTheLaunchAreRemoved() throws {
        let folder = try A79A81RepetitionTests.folder("start")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let audio = CloudDrillAudio(cloud: A79A81RepetitionTests.MockCloud(), store: store, folder: folder)
        let launch = Date()
        let old = folder.appendingPathComponent("old.mp3")
        let fresh = folder.appendingPathComponent("fresh.mp3")
        try Data([1]).write(to: old)
        try Data([2]).write(to: fresh)
        try FileManager.default.setAttributes([.modificationDate: launch.addingTimeInterval(-3_600)], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: launch.addingTimeInterval(5)], ofItemAtPath: fresh.path)
        #expect(audio.removeUnused(olderThan: launch) == 1)
        #expect(!FileManager.default.fileExists(atPath: old.path), "unused since before the launch: removed")
        #expect(FileManager.default.fileExists(atPath: fresh.path), "a download that has just been written stays")
        #expect(audio.removeUnused() == 1, "without a limit, as before (A103)")
    }

    @Test func oldNightsWaitUntilAfterTheFirstScreen() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sleep-\(UUID().uuidString)")
        let store = SleepStore(directory: directory)
        let old = SleepNight(start: Date().addingTimeInterval(-90 * 86_400), end: Date().addingTimeInterval(-90 * 86_400 + 3_600))
        store.save(old)
        _ = SleepController(store: store)
        #expect(store.nights.map(\.id) == [old.id], "not in init")
        store.removeOld()
        #expect(store.nights.isEmpty, "after the first screen")
    }

    @Test func theHistoryIsGoneThroughOnceAnHour() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let folder = temporaryDirectory()
        let seed = HistoryStore(directory: folder, now: t0)
        // An entry that expires half an hour after the launch.
        let createdAt = Calendar(identifier: .gregorian).date(byAdding: .year, value: -2, to: t0.addingTimeInterval(1_800)) ?? t0
        seed.record(HistoryEntry(createdAt: createdAt, question: nil, answer: "snart gammal", summary: nil), now: t0)
        let store = HistoryStore(directory: folder, now: t0) // the launch: gone through now
        #expect(store.entries.count == 1)
        store.purgeExpired(now: t0.addingTimeInterval(2_400)) // prepareBackend right after: skipped
        #expect(store.entries.count == 1, "within the hour it is not gone through again")
        store.purgeExpired(now: t0.addingTimeInterval(4_000))
        #expect(store.entries.isEmpty, "after the hour it is")
    }

    @Test func theCalendarIsTheSameForEveryEntry() throws {
        let calendar = Calendar(identifier: .gregorian)
        let leap = try #require(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 12)))
        #expect(Retention.expiry(from: leap) == calendar.date(byAdding: .year, value: 2, to: leap))
        #expect(Retention.isExpired(leap, at: leap.addingTimeInterval(800 * 86_400)))
        #expect(!Retention.isExpired(leap, at: leap.addingTimeInterval(700 * 86_400)))
    }

    @Test func theTimeToTheFirstScreenIsMeasured() async {
        #expect(LaunchTiming.milliseconds(from: Date(timeIntervalSince1970: 0), to: Date(timeIntervalSince1970: 1.2345)) == 1_235)
        #expect(LaunchTiming.milliseconds(from: Date(timeIntervalSince1970: 5), to: Date(timeIntervalSince1970: 1)) == 0)
        #expect(LaunchTiming.line(812) == "Launch: first screen after 812 ms")
        // The test host is the app itself: its first screen has been shown, and the time is known.
        #expect(await waitUntil(timeout: .seconds(20)) { LaunchTiming.firstScreenMs != nil })
        let ms = LaunchTiming.firstScreenMs ?? -1
        // The number is printed for the build's summary. It is the test host's launch on CI's Simulator – a cold first
        // launch after the install, with the test bundle injected (37 s on 2026-11-27) – not a user's launch; the phone's
        // own number is in Diagnostik. So no limit here, only that it was measured.
        print("LAUNCH_FIRST_SCREEN_MS \(ms) (Simulator, test host)")
        #expect(ms > 0, "measured: \(ms) ms")
        #expect(!LaunchTiming.firstScreenShown(), "logged once per launch")
    }
}
