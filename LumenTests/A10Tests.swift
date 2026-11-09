import Foundation
import Testing
@testable import Lumen

/// A10: others talking in the room reach the AirPods 10–20 dB below the wearer and are muted for Scribe.
@Suite struct WearerFocusTests {
    private let t0 = Date(timeIntervalSince1970: 3_000_000)

    /// 4 windows of room noise, then the wearer at -20 dBFS, then chatter at `chatter` dBFS.
    private func run(chatter: Double, focus: inout WearerFocus) -> [WearerFocus.Verdict] {
        var verdicts: [WearerFocus.Verdict] = []
        var time = t0
        func window(_ level: Double, speech: Bool) {
            verdicts.append(focus.judge(rmsDBFS: level, probability: speech ? 0.9 : 0.05, at: time))
            time = time.addingTimeInterval(SpeechGate.windowSeconds)
        }
        for _ in 0..<4 { window(-60, speech: false) }
        for _ in 0..<8 { window(-20, speech: true) }
        for _ in 0..<8 { window(chatter, speech: true) }
        return verdicts
    }

    @Test func chatterTenDecibelsBelowIsMuted() {
        var focus = WearerFocus()
        let verdicts = run(chatter: -31, focus: &focus)
        #expect(verdicts.prefix(4).allSatisfy { $0 == .quiet })
        #expect(verdicts.dropFirst(4).prefix(8).allSatisfy { $0 == .wearer })
        #expect(verdicts.suffix(8).allSatisfy { $0 == .other })
        #expect(focus.mutedWindows == 8)
    }

    @Test func theWearersQuieterSyllablesPass() {
        var focus = WearerFocus()
        let verdicts = run(chatter: -25, focus: &focus) // 5 dB below: still the wearer's range
        #expect(verdicts.suffix(8).allSatisfy { $0 == .wearer })
    }

    @Test func beforeTheWearerIsKnownEverythingPasses() {
        var focus = WearerFocus()
        #expect(focus.judge(rmsDBFS: -60, probability: 0.1, at: t0) == .quiet)
        #expect(focus.judge(rmsDBFS: -52, probability: 0.9, at: t0) == .wearer, "below the learning level: nothing known yet")
        #expect(focus.wearerDBFS == nil)
    }

    @Test func oneShoutDoesNotSilenceTheWearer() {
        var focus = WearerFocus()
        _ = run(chatter: -40, focus: &focus)
        _ = focus.judge(rmsDBFS: -5, probability: 0.9, at: t0)
        #expect(focus.judge(rmsDBFS: -20, probability: 0.9, at: t0) == .wearer)
    }

    @Test func levelOfAWindow() {
        #expect(WearerFocus.rmsDBFS([]) == -120)
        #expect(WearerFocus.rmsDBFS([Int16](repeating: 0, count: 10)) == -120)
        let full = WearerFocus.rmsDBFS([Int16](repeating: 16_384, count: 100))
        #expect(abs(full - (-6.02)) < 0.1)
    }
}
