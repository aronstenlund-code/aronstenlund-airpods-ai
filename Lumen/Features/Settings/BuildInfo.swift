import Foundation

/// A123: which build this is, so the owner can see that the app on the phone is the one he just downloaded. The
/// installable build (ios-build.yml, the unsigned .ipa) sets the build number to the GitHub run and puts the short
/// commit in Info.plist (`LumenGitSHA`). A build made any other way has neither and says only its version.
enum BuildInfo {
    /// "Version 1.0.0 (körning 44019359349 · bb9a74b)", or "Version 1.0.0 (1)" for a build without a run.
    static func line(version: String?, build: String?, sha: String?) -> String {
        let version = version ?? "–"
        let build = build ?? "–"
        let sha = (sha ?? "").trimmingCharacters(in: .whitespaces)
        guard !sha.isEmpty, !sha.hasPrefix("$(") else { return String(localized: "Version \(version) (\(build))") }
        return String(localized: "Version \(version) (körning \(build) · \(sha))")
    }

    static var line: String {
        let info = Bundle.main
        return line(version: info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                    build: info.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                    sha: info.object(forInfoDictionaryKey: "LumenGitSHA") as? String)
    }
}
