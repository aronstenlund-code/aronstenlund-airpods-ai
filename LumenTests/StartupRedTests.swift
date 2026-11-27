import Foundation
import Testing
@testable import Lumen

/// Red first against main (existing API only): nothing that can wait is done before the first screen.
@MainActor
@Suite struct StartupRedTests {
    @Test func theExamSoundIsNotCleanedBeforeTheFirstScreen() throws {
        let folder = try A79A81RepetitionTests.folder("start")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let unused = folder.appendingPathComponent("unused.mp3")
        try Data([1, 2, 3]).write(to: unused)
        _ = CloudDrillAudio(cloud: A79A81RepetitionTests.MockCloud(), store: store, folder: folder)
        #expect(FileManager.default.fileExists(atPath: unused.path))
    }

    @Test func oldNightsWaitUntilAfterTheFirstScreen() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sleep-\(UUID().uuidString)")
        let store = SleepStore(directory: directory)
        let old = SleepNight(start: Date().addingTimeInterval(-90 * 86_400), end: Date().addingTimeInterval(-90 * 86_400 + 3_600))
        store.save(old)
        _ = SleepController(store: store)
        #expect(store.nights.map(\.id) == [old.id])
    }
}
