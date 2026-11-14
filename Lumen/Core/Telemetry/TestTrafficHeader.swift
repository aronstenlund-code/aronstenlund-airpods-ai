import Foundation

/// Toby 2 T24 (K64, D180): in Debug builds only, a UI test can mark every request to our backend as test traffic
/// with the launch environment `LUMEN_TEST_HEADER` (`1`, `slow`, `unavailable`). The server then sends fake audio
/// (`slow`: drill files stay pending; `unavailable`: files fail with `audio_unavailable`, /tts 503). Release builds
/// never send the header.
enum TestTrafficHeader {
    static let name = "x-earmind-test"
    static let environmentKey = "LUMEN_TEST_HEADER"

    /// The header's value, or nil outside a Debug build or without the launch environment.
    static var value: String? {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty, raw.count <= 20,
              raw.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
        else { return nil }
        return raw
        #else
        return nil
        #endif
    }
}

extension URLRequest {
    /// Adds `x-earmind-test` when a Debug UI test asked for it (`TestTrafficHeader`). Called next to the `apikey`
    /// header on every request to our backend.
    mutating func markTestTraffic() {
        if let value = TestTrafficHeader.value { setValue(value, forHTTPHeaderField: TestTrafficHeader.name) }
    }
}
