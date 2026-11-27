import Testing
@testable import Lumen

/// K124: red first against main – 503 `tts_quota` is the voice service being out (existing API only).
@MainActor
@Suite struct K124RedTests {
    @Test func tts_quotaIsTheVoiceServiceBeingOut() {
        #expect(CloudDrillAudio.isUnavailable("tts_quota"))
        #expect(!CloudDrillAudio.isUnavailable("provider_quota"))
    }
}
