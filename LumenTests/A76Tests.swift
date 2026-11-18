import Foundation
import Testing
@testable import Lumen

/// A76 (D140): the test mode is off by default, a test account is switched on once, and the pieces on the phone never
/// pile up (at most `keepLimit`, at most `keepAge`).
@MainActor
@Suite struct A76Tests {
    @Test func offByDefaultAndOnOnceForATestAccount() {
        let defaults = UserDefaults(suiteName: "a76-\(UUID().uuidString)")!
        let settings = TestModeSettings(defaults: defaults)
        #expect(!settings.isEnabled, "no audio kept by default (CLAUDE.md)")
        settings.applyServerFlag(true)
        #expect(settings.isEnabled)
        #expect(settings.needsServerNotice, "Ke46 T2: switched on by the server, the sheet is shown once")
        settings.isEnabled = false
        settings.applyServerFlag(true)
        #expect(!settings.isEnabled, "turned off by the tester, it stays off")
    }

    @Test func oldPiecesAreDeleted() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a76-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = DebugPieceStore(folder: folder)
        let now = Date()
        store.save(DebugPiece(id: "old", startedAt: now.addingTimeInterval(-50 * 3600), endedAt: now.addingTimeInterval(-49 * 3600),
                              audioFile: "old.m4a", mode: "standard"))
        store.save(DebugPiece(id: "new", startedAt: now.addingTimeInterval(-60), endedAt: now, audioFile: "new.m4a", mode: "standard"))
        #expect(store.pending().map(\.id) == ["new"], "older than 48 h is gone")
        store.delete(try #require(store.pending().first))
        #expect(store.pending().isEmpty, "uploaded pieces leave the phone")
    }

    @Test func aMinuteBecomesK43sTurn() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var piece = DebugPiece(id: "piece-1", startedAt: start, endedAt: start.addingTimeInterval(60), audioFile: "piece-1.m4a", mode: "auto")
        piece.heard = [.init(at: start.addingTimeInterval(12), text: "Lumen, vad är huvudstaden i Norge?")]
        piece.answers = [.init(at: start.addingTimeInterval(14), text: "vad är huvudstaden i Norge → Oslo.")]
        piece.turns = [.init(at: start.addingTimeInterval(13), heard: "vad är huvudstaden i Norge", outcome: "answered", reason: nil, status: "ok"),
                       .init(at: start.addingTimeInterval(40), heard: "ja", outcome: "dropped", reason: "echo", status: nil),
                       .init(at: start.addingTimeInterval(50), heard: "hm", outcome: "dropped", reason: "short", status: nil)]
        piece.log = (0..<500).map { "line \($0) with some words to make it long" }
        let body = DebugTurnBody(piece: piece, audio: Data([1, 2, 3]))
        #expect(body.turn_id == "piece-1")
        #expect(body.audio_mime == "audio/mp4")
        #expect(body.audio_b64 == "AQID")
        #expect(body.transcript == "[12 s] Lumen, vad är huvudstaden i Norge?")
        #expect(body.decision == "answered 1, dropped 2")
        let meta = try #require(body.meta)
        #expect(try JSONEncoder().encode(meta).count <= 4000, "K43 drops a longer meta")
        #expect(meta.turns.count == 3, "the log is cut before the turns")
        #expect(meta.log.last == "line 499 with some words to make it long", "the newest lines are kept")
        #expect(DebugTurnBody(piece: DebugPiece(id: "x", startedAt: start, endedAt: start, audioFile: "", mode: "auto"), audio: nil).decision == "no turn")
    }

    @Test func aRefusedAccountKeepsNothing() {
        let settings = TestModeSettings(defaults: UserDefaults(suiteName: "a76-\(UUID().uuidString)")!)
        settings.isEnabled = true
        settings.applyServerFlag(false)
        #expect(settings.serverRefused, "switched on but the server says no: Settings tells, nothing is kept")
    }

    @Test func theSoundSentenceIsReplacedNotAdded() {
        // Ke46 T4: D138's "sparas inte av EarMind" is not true in the test mode; the note replaces it.
        #expect(!TestModeSettings.soundNote.contains("sparas inte"))
        #expect(TestModeSettings.soundNote.contains("14 dagar"))
        #expect(TestModeSettings.soundNote.hasSuffix("Sömnläget sparar klippen bara på din telefon."))
    }

    /// A142 (D218 point 4): the tests run on the Debug build, which has the test mode. That the App Store build has
    /// none is checked in CI, on the Release build itself (ios-build.yml).
    @Test func theTestModeIsInTheTestersBuild() {
        #expect(TestModeBuild.isAvailable)
    }

    /// A142: the App Store build installed over a tester's build keeps none of the waiting audio and no switch.
    @Test func theAppStoreBuildRemovesWhatATestersBuildLeft() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a142-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = DebugPieceStore(folder: folder)
        let now = Date()
        store.save(DebugPiece(id: "waiting", startedAt: now.addingTimeInterval(-60), endedAt: now, audioFile: "waiting.m4a", mode: "standard"))
        try Data([1, 2, 3]).write(to: folder.appendingPathComponent("waiting.m4a"))
        let defaults = UserDefaults(suiteName: "a142-\(UUID().uuidString)")!
        defaults.set(true, forKey: TestModeSettings.enabledKey)

        TestModeBuild.removeLeftovers(folder: folder, defaults: defaults)

        #expect(!FileManager.default.fileExists(atPath: folder.path), "no audio is left on the phone")
        #expect(!TestModeSettings(defaults: defaults).isEnabled, "nothing is on by itself in a later tester's build")
    }
}
