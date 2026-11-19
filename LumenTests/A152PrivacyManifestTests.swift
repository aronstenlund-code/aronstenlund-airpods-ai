import Foundation
import Testing
@testable import Lumen

/// A152 (D238): the app carries a privacy manifest (PrivacyInfo.xcprivacy). App Store Connect refuses an app whose
/// code uses a "required reason API" without one. That the manifest matches the code is checked over the sources by
/// `scripts/privacy_manifest_check.py` in the build; here: the file is in the built app and says what was decided.
@MainActor
@Suite struct A152PrivacyManifestTests {
    private func manifest() throws -> [String: Any] {
        let bundle = Bundle(for: SearchToneController.self) // the app the tests run in
        let url = try #require(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
                               "PrivacyInfo.xcprivacy is not in the app bundle")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test func theAppDoesNotTrack() throws {
        let manifest = try manifest()
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String] ?? ["?"]).isEmpty)
        let collected = manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        #expect(!collected.isEmpty)
        for entry in collected {
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false, "nothing is used for tracking")
            let purposes = entry["NSPrivacyCollectedDataTypePurposes"] as? [String] ?? []
            #expect(!purposes.isEmpty && !purposes.contains { $0.contains("Advertising") }, "no advertising")
        }
    }

    /// The reasons, as Apple's codes: the app's own settings and the widget's shared ones, the sound cache's file
    /// dates (inside the app's container), time between events in the app (the playback latency), and free disk space
    /// before a file is written. The last one is FluidAudio's code (it has no manifest of its own and is linked into
    /// the app): it checks the space before a model download, which EarMind never asks it for.
    @Test func everyRequiredReasonAPITheCodeUsesHasItsReason() throws {
        let entries = try manifest()["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        var reasons: [String: Set<String>] = [:]
        for entry in entries {
            guard let kind = entry["NSPrivacyAccessedAPIType"] as? String else { continue }
            reasons[kind] = Set(entry["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? [])
        }
        #expect(reasons == [
            "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1", "1C8F.1"],
            "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1"],
            "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1"],
            "NSPrivacyAccessedAPICategoryDiskSpace": ["E174.1"],
        ])
    }

    /// What leaves the phone and is kept (docs/appstore/granskning.md §2), and whether it is tied to the account.
    @Test func theCollectedDataIsWhatTheReviewTableSays() throws {
        let collected = try manifest()["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        var linked: [String: Bool] = [:]
        for entry in collected {
            guard let kind = entry["NSPrivacyCollectedDataType"] as? String else { continue }
            linked[kind.replacingOccurrences(of: "NSPrivacyCollectedDataType", with: "")] = entry["NSPrivacyCollectedDataTypeLinked"] as? Bool
        }
        #expect(linked == [
            "UserID": true, "OtherUserContent": true, "CustomerSupport": true, "PurchaseHistory": true,
            "ProductInteraction": true, "PhotosorVideos": false, "AudioData": false, "Contacts": false,
        ])
    }
}
