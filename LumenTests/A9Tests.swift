import Foundation
import Testing
@testable import Lumen

/// A9.1: tips about commands: once per session and per day, never while busy, never a command already used.
@MainActor
@Suite struct CommandTipTests {
    private func makeStore() -> (CommandTipStore, UserDefaults) {
        let suite = "lumen.tests.tips.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (CommandTipStore(defaults: defaults), defaults)
    }

    private let t0 = Date(timeIntervalSince1970: 4_000_000)

    @Test func oneTipPerSessionAndPerDay() {
        let (store, defaults) = makeStore()
        store.sessionStarted()
        let first = store.next(for: .prov, busy: false, now: t0)
        #expect(first == .shorter)
        store.tipped(first!, at: t0)
        #expect(store.next(for: .prov, busy: false, now: t0.addingTimeInterval(60)) == nil, "one per session")
        store.sessionStarted()
        #expect(store.next(for: .prov, busy: false, now: t0.addingTimeInterval(3_600)) == nil, "one per day")
        #expect(store.next(for: .prov, busy: false, now: t0.addingTimeInterval(25 * 3_600)) == .repeatAnswer)
        let reloaded = CommandTipStore(defaults: defaults)
        #expect(reloaded.lastTipAt == t0, "the day survives a restart")
    }

    @Test func neverWhileBusyOrSwitchedOff() {
        let (store, _) = makeStore()
        #expect(store.next(for: .prov, busy: true, now: t0) == nil, "never during an exam, a mini test or speech")
        store.enabled = false
        #expect(store.next(for: .prov, busy: false, now: t0) == nil)
    }

    @Test func aUsedCommandIsNeverTipped() {
        let (store, _) = makeStore()
        store.markUsed(.shorter)
        store.markUsed(.repeatAnswer)
        #expect(store.next(for: .prov, busy: false, now: t0) == .moreDetail)
        for action in CommandTips.candidates(for: .interview) { store.markUsed(action) }
        #expect(store.next(for: .interview, busy: false, now: t0) == nil)
    }

    @Test func theScreenLineAndTheTipUseTheTable() {
        var added: [CommandAction: [String]] = [:]
        let standard = CommandTable(added: added, removed: [:])
        #expect(CommandTips.line(for: .prov, table: standard) == "Säg ”Lumen, förhör mig”, ”Lumen, svara kortare” eller ”Lumen, pausa”.")
        #expect(CommandTips.tip(.shorter, table: standard) == "Tips: säg ”Lumen, svara kortare” om svaren är för långa.")
        added[.shorter] = ["korta ner"]
        let removed: [CommandAction: Set<String>] = [.shorter: Set(CommandAction.shorter.defaultPhrases)]
        let own = CommandTable(added: added, removed: removed)
        #expect(CommandTips.tip(.shorter, table: own) == "Tips: säg ”Lumen, korta ner” om svaren är för långa.")
        #expect(CommandTips.top(for: .standard).count == 3)
    }
}
