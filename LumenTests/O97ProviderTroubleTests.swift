import Foundation
import Testing
@testable import Lumen

/// O97 (Kevin, deploy 370; Deangelo 2026-11-22): when the model behind EarMind is out of credits, busy or down, the
/// server answers 503 (or 502) with a `provider_*` code from /answer, /exam and /drill. The app then says one short
/// line of its own in the chosen language, never the server's message: that message has been technical before
/// ("LLM credits exhausted"). Nothing is made after such a no, so no credits are counted.
/// Fake replies only: no model call, no sound, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct O97ProviderTroubleTests {
    static let line = "EarMind kan inte svara just nu. Försök igen om en stund."
    static let codes: [(status: Int, code: String)] = [
        (503, "provider_quota"), (503, "provider_busy"), (503, "provider_unconfigured"),
        (503, "provider_misconfigured"), (502, "provider_unavailable"),
    ]

    /// The server's body, with a message nobody should have to read.
    static func body(_ code: String) -> Data {
        Data(#"{"error":{"code":"\#(code)","message":"LLM credits exhausted","fallback":true}}"#.utf8)
    }

    // MARK: A saved or started exam (/drill)

    @Test func aRefusedSaveOrStartSaysTheAppsOwnWords() {
        for (status, code) in Self.codes {
            let error = DrillCloudClient.refusal(status: status, data: Self.body(code))
            #expect(error.userMessage == Self.line, "\(code)")
            #expect(error.errorCode == code, "the code stays, for the log and for what the app does next")
        }
    }

    // MARK: A new exam (/exam)

    @Test func aRefusedNewExamSaysTheAppsOwnWords() {
        for (status, code) in Self.codes {
            #expect(DrillClient.refusal(status: status, data: Self.body(code)).userMessage == Self.line, "\(code)")
        }
    }

    // MARK: What must not change

    @Test func otherRefusalsKeepTheServersWords() {
        let limit = Data(#"{"error":{"code":"rate_limited","message":"Spara provet igen i morgon.","fallback":false}}"#.utf8)
        #expect(DrillCloudClient.refusal(status: 429, data: limit).userMessage == "Spara provet igen i morgon.")
        #expect(DrillClient.refusal(status: 429, data: limit).userMessage == "Spara provet igen i morgon.")
        // A server fault that is not the model's stays what it was.
        #expect(DrillClient.refusal(status: 500, data: Data(#"{"error":{"code":"internal","message":"boom"}}"#.utf8)).userMessage
            == "Det gick inte att skapa frågorna. Försök igen.")
    }
}
