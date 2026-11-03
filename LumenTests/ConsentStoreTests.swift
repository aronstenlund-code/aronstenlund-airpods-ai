import Foundation
import Testing
@testable import Lumen

@MainActor
@Suite struct ConsentStoreTests {
    /// A throw-away defaults domain per test so tests never see each other's (or the app's) consent.
    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.consent.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func freshInstallHasNoConsent() {
        let store = ConsentStore(defaults: freshDefaults())
        #expect(store.record == nil)
        #expect(!store.isGranted)
    }

    @Test func grantPersistsAcrossInstances() {
        let defaults = freshDefaults()
        let grantedAt = Date(timeIntervalSince1970: 1_762_200_000)
        let store = ConsentStore(defaults: defaults, now: { grantedAt })

        store.grant()
        #expect(store.isGranted)
        #expect(store.record == ConsentRecord(version: ConsentPolicy.currentVersion, grantedAt: grantedAt))

        let reloaded = ConsentStore(defaults: defaults)
        #expect(reloaded.isGranted)
        #expect(reloaded.record?.grantedAt == grantedAt)
    }

    @Test func newerPolicyVersionAsksAgain() {
        let defaults = freshDefaults()
        ConsentStore(defaults: defaults, requiredVersion: 1).grant()

        let store = ConsentStore(defaults: defaults, requiredVersion: 2)
        #expect(store.record?.version == 1, "the old record is kept for the audit trail")
        #expect(!store.isGranted)

        store.grant()
        #expect(store.isGranted)
        #expect(store.record?.version == 2)
    }

    @Test func revokeRemovesTheRecord() {
        let defaults = freshDefaults()
        let store = ConsentStore(defaults: defaults)
        store.grant()

        store.revoke()

        #expect(store.record == nil)
        #expect(!store.isGranted)
        #expect(defaults.data(forKey: ConsentStore.defaultsKey) == nil)
        #expect(!ConsentStore(defaults: defaults).isGranted)
    }

    @Test func corruptStoredDataMeansNoConsent() {
        let defaults = freshDefaults()
        defaults.set("not json".data(using: .utf8), forKey: ConsentStore.defaultsKey)

        let store = ConsentStore(defaults: defaults)
        #expect(store.record == nil)
        #expect(!store.isGranted)
    }
}
