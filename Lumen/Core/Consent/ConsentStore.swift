import Foundation
import Observation

/// Consent policy (ARCHITECTURE §12). Bump `currentVersion` whenever the consent text changes in substance;
/// the app then shows the consent screen again before the next session.
enum ConsentPolicy {
    /// A73 (D138): 6, the text about sound is true now (the sleep mode keeps clips on the phone).
    static let currentVersion = 6 // A41: D116 (questions and answers sent for analysis), other people's words
    /// A48 (D116, K30): the first version whose text says questions and answers are sent to us.
    static let qaLogVersion = 5

    /// Only a record that accepted D116's text lets the backend log questions and answers.
    static func allowsQALog(_ record: ConsentRecord?) -> Bool { (record?.version ?? 0) >= qaLogVersion }
}

struct ConsentRecord: Codable, Equatable, Sendable {
    var version: Int
    var grantedAt: Date
}

@MainActor
protocol ConsentStoring: AnyObject {
    var record: ConsentRecord? { get }
    /// True only for a record of the current policy version (D21).
    var isGranted: Bool { get }
    func grant()
    func revoke()
}

/// Persists the user's consent locally (UserDefaults, JSON). Nothing leaves the device.
@MainActor
@Observable
final class ConsentStore: ConsentStoring {
    static let defaultsKey = "consent.record"

    private(set) var record: ConsentRecord?
    private let defaults: UserDefaults
    private let requiredVersion: Int
    private let now: @Sendable () -> Date

    init(defaults: UserDefaults = .standard,
         requiredVersion: Int = ConsentPolicy.currentVersion,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.defaults = defaults
        self.requiredVersion = requiredVersion
        self.now = now
        self.record = Self.load(from: defaults)
    }

    var isGranted: Bool { (record?.version ?? 0) >= requiredVersion }

    func grant() {
        let newRecord = ConsentRecord(version: requiredVersion, grantedAt: now())
        record = newRecord
        if let data = try? JSONEncoder().encode(newRecord) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    func revoke() {
        record = nil
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> ConsentRecord? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(ConsentRecord.self, from: data)
    }
}
