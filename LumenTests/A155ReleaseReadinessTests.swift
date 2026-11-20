import Foundation
import Testing
@testable import Lumen

/// A155 (D243): what App Store Connect reads from the app before anyone looks at it. The archive itself is checked in
/// the build (`ios-build.yml`, "Release archive is ready to submit"); here the two answers that live in Info.plist.
@MainActor
@Suite struct A155ReleaseReadinessTests {
    private var info: [String: Any] { Bundle(for: SearchToneController.self).infoDictionary ?? [:] }

    /// The export compliance answer. The app has no encryption of its own: HTTPS through the system, SHA-256 as a
    /// hash (the sound's cache key, the App Attest challenge) and Apple's own App Attest. With the key in place App
    /// Store Connect does not ask at every upload.
    @Test func theAppUsesNoEncryptionOfItsOwn() {
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }

    /// The first App Store version. The build number is the run's id in CI and "1" in a build made by hand.
    @Test func theVersionIsTheFirstOne() {
        #expect(info["CFBundleShortVersionString"] as? String == "1.0.0")
        let build = info["CFBundleVersion"] as? String ?? ""
        #expect(!build.isEmpty && build.allSatisfy { $0.isNumber || $0 == "." }, "App Store Connect takes only numbers and dots")
    }
}
