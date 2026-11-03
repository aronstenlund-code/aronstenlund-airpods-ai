import Foundation
import Testing
@testable import Lumen

/// Records every `speak` call; can fail or take time.
@MainActor
final class FakeTTSProvider: TTSProvider {
    struct Call: Equatable {
        var text: String
        var language: TranscriptionLanguage
        var voice: VoiceChoice
    }

    let name: String
    var error: TTSError?
    var delay: Duration = .zero
    private(set) var calls: [Call] = []

    init(name: String) {
        self.name = name
    }

    func speak(_ text: String, language: TranscriptionLanguage, voice: VoiceChoice) async throws(TTSError) {
        calls.append(Call(text: text, language: language, voice: voice))
        if delay > .zero {
            do { try await Task.sleep(for: delay) } catch { throw TTSError.cancelled }
        }
        if let error { throw error }
    }
}

@MainActor
func freshVoiceSettings() -> VoiceSettings {
    let suite = "lumen.tests.voice.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return VoiceSettings(defaults: defaults)
}

@MainActor
func makeTestSpeaker(_ playback: any PlaybackServicing, apple: FakeTTSProvider = FakeTTSProvider(name: "apple"),
                     premium: FakeTTSProvider? = nil) -> Speaker {
    Speaker(settings: freshVoiceSettings(), apple: apple, premium: premium, playback: playback)
}

@MainActor
func makeTestVoiceCatalog() -> VoiceCatalog {
    let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "sb_publishable_test")
    let http = FakeHTTP()
    return VoiceCatalog(config: config, auth: SupabaseAuth(config: config, store: InMemorySessionStore(), http: http), http: http)
}

@MainActor
@Suite struct SpeakerTests {
    private let premiumVoice = VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Astrid")

    @Test func speaksSentencesInOrderWithTheChosenVoice() async {
        let playback = FakePlaybackService()
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        let speaker = makeTestSpeaker(playback, apple: apple, premium: premium)
        speaker.settings.voice = premiumVoice

        speaker.enqueue("Roten ur hundra är tio.", language: .swedish)
        speaker.enqueue("Det är enkelt.", language: .swedish)
        #expect(await waitUntil { speaker.spokenCount == 2 })

        #expect(premium.calls.map(\.text) == ["Roten ur hundra är tio.", "Det är enkelt."])
        #expect(premium.calls.first?.voice == premiumVoice)
        #expect(premium.calls.first?.language == .swedish)
        #expect(apple.calls.isEmpty)
        #expect(await waitUntil { speaker.status == .idle })
    }

    @Test func appleVoiceGoesStraightToApple() async {
        let playback = FakePlaybackService()
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        let speaker = makeTestSpeaker(playback, apple: apple, premium: premium)
        let appleVoice = VoiceChoice(kind: .apple, voiceID: "com.apple.voice.enhanced.sv-SE.Alva", name: "Apple · Alva")
        speaker.settings.voice = appleVoice

        speaker.enqueue("Hej.", language: .swedish)
        #expect(await waitUntil { speaker.spokenCount == 1 })
        #expect(apple.calls.first?.voice == appleVoice)
        #expect(premium.calls.isEmpty)
    }

    @Test func fallsBackToAppleWhenThePremiumVoiceFails() async {
        let playback = FakePlaybackService()
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.error = .network(.backend(status: 503, failure: AnswerFailure(code: "provider_quota", message: "credits", fallback: true)))
        let speaker = makeTestSpeaker(playback, apple: apple, premium: premium)
        speaker.settings.voice = premiumVoice

        speaker.enqueue("Roten ur hundra är tio.", language: .swedish)
        #expect(await waitUntil { speaker.spokenCount == 1 })

        #expect(premium.calls.count == 1)
        #expect(apple.calls.map(\.text) == ["Roten ur hundra är tio."])
        #expect(apple.calls.first?.voice == .appleDefault)
        #expect(speaker.fallbackCount == 1)
        #expect(speaker.notice?.contains("Apple") == true)
        #expect(speaker.notice?.contains("provider_quota") == true)
    }

    @Test func nonNetworkFailureIsReportedWithoutFallback() async {
        let playback = FakePlaybackService()
        let apple = FakeTTSProvider(name: "apple")
        apple.error = .noVoice(language: "sv-SE")
        let speaker = makeTestSpeaker(playback, apple: apple)

        speaker.enqueue("Hej.", language: .swedish)
        #expect(await waitUntil { speaker.notice != nil })
        #expect(speaker.spokenCount == 0)
        #expect(speaker.fallbackCount == 0)
        #expect(speaker.notice == TTSError.noVoice(language: "sv-SE").localizedDescription)
    }

    @Test func interruptClearsTheQueueAndStopsPlayback() async {
        let playback = FakePlaybackService()
        let apple = FakeTTSProvider(name: "apple")
        apple.delay = .milliseconds(300)
        let speaker = makeTestSpeaker(playback, apple: apple)

        speaker.enqueue("Ett.", language: .swedish)
        speaker.enqueue("Två.", language: .swedish)
        speaker.enqueue("Tre.", language: .swedish)
        #expect(await waitUntil { apple.calls.count == 1 })
        speaker.interrupt()

        #expect(playback.stopCalls >= 1)
        #expect(speaker.status == .idle)
        try? await Task.sleep(for: .milliseconds(500))
        #expect(apple.calls.count == 1, "queued sentences were dropped")
        #expect(speaker.spokenCount == 0, "the interrupted sentence does not count")

        apple.delay = .zero
        speaker.enqueue("Fyra.", language: .swedish)
        #expect(await waitUntil { speaker.spokenCount == 1 })
        #expect(apple.calls.last?.text == "Fyra.")
    }

    @Test func silentModeSpeaksNothing() async {
        let playback = FakePlaybackService()
        let apple = FakeTTSProvider(name: "apple")
        let speaker = makeTestSpeaker(playback, apple: apple)
        speaker.settings.speakAnswers = false

        speaker.enqueue("Hej.", language: .swedish)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(apple.calls.isEmpty)
        #expect(speaker.status == .idle)
    }

    @Test func previewUsesTheGivenVoiceEvenInSilentMode() async {
        let playback = FakePlaybackService()
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        let speaker = makeTestSpeaker(playback, apple: apple, premium: premium)
        speaker.settings.speakAnswers = false

        speaker.preview(premiumVoice, language: .english)
        #expect(await waitUntil { premium.calls.count == 1 })
        #expect(premium.calls.first?.language == .english)
        #expect(premium.calls.first?.text.hasPrefix("Hello") == true)
    }

    @Test func rateIsAppliedToPlayback() {
        let playback = FakePlaybackService()
        let speaker = makeTestSpeaker(playback)
        speaker.settings.rate = 1.5
        speaker.applyRate()
        #expect(playback.rate == 1.5)
    }
}

@MainActor
@Suite struct VoiceSettingsTests {
    @Test func defaultsAndPersistence() {
        let suite = "lumen.tests.voicesettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let fresh = VoiceSettings(defaults: defaults)
        #expect(fresh.voice == .appleDefault)
        #expect(fresh.rate == 1.0)
        #expect(fresh.speakAnswers)

        fresh.voice = VoiceChoice(kind: .elevenLabs, voiceID: "v2", name: "Erik")
        fresh.rate = 2.5
        fresh.speakAnswers = false
        #expect(fresh.rate == 2.0, "clamped")

        let reloaded = VoiceSettings(defaults: defaults)
        #expect(reloaded.voice == VoiceChoice(kind: .elevenLabs, voiceID: "v2", name: "Erik"))
        #expect(reloaded.rate == 2.0)
        #expect(!reloaded.speakAnswers)
    }
}

@Suite struct PCM16AssemblerTests {
    @Test func reassemblesSamplesAcrossChunkBoundaries() {
        // Samples 1, -2, 300 as little-endian bytes: 01 00 | FE FF | 2C 01
        let bytes: [UInt8] = [0x01, 0x00, 0xFE, 0xFF, 0x2C, 0x01]
        var assembler = PCM16Assembler()
        var out: [[Int16]] = []
        out += assembler.feed(Data(bytes[0..<3]), minimumBytes: 2)   // 01 00 FE → one sample, FE pending
        out += assembler.feed(Data(bytes[3..<6]), minimumBytes: 2)   // FF 2C 01 → FE FF, 2C 01
        if let rest = assembler.flush() { out.append(rest) }
        #expect(out.flatMap { $0 } == [1, -2, 300])
    }

    @Test func minimumBytesBatchesAndFlushDropsAnOddByte() {
        var assembler = PCM16Assembler()
        let data = Data([UInt8](repeating: 0, count: 9)) // 4.5 samples
        #expect(assembler.feed(data, minimumBytes: 100).isEmpty, "below the minimum: nothing yet")
        #expect(assembler.flush() == [Int16](repeating: 0, count: 4))
        #expect(assembler.flush() == nil)
    }
}

@MainActor
@Suite struct ElevenLabsTTSProviderTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "sb_publishable_test")
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private var session: SupabaseSession { SupabaseSession(accessToken: "jwt", refreshToken: "r", expiresAt: t0.addingTimeInterval(3600)) }

    private func makeProvider(_ http: FakeHTTP, playback: FakePlaybackService) -> ElevenLabsTTSProvider {
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(session), http: http, now: { t0 })
        return ElevenLabsTTSProvider(config: config, auth: auth, http: http, playback: playback)
    }

    @Test func postsTextAndStreamsPCMIntoPlayback() async throws {
        // 7 samples (14 bytes) delivered in 5-byte chunks.
        var pcm = Data()
        for value in [Int16]([100, -100, 2000, -2000, 32767, -32768, 7]) {
            let bits = UInt16(bitPattern: value)
            pcm.append(UInt8(bits & 0xFF))
            pcm.append(UInt8(bits >> 8))
        }
        let http = FakeHTTP([.init(status: 200, body: "", bodyData: pcm, chunkSize: 5)])
        let playback = FakePlaybackService()
        let provider = makeProvider(http, playback: playback)
        let voice = VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Astrid")

        try await provider.speak("Roten ur hundra är tio.", language: .swedish, voice: voice)

        let request = http.requests[0]
        #expect(request.url == config.ttsURL)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        let body = http.json(0)
        #expect(body["text"] as? String == "Roten ur hundra är tio.")
        #expect(body["language"] as? String == "sv")
        #expect(body["output_format"] as? String == "pcm_24000")
        #expect(body["voice_id"] as? String == "v1")
        #expect(playback.played.flatMap { $0 } == [100, -100, 2000, -2000, 32767, -32768, 7])
        #expect(playback.playedSampleRates.allSatisfy { $0 == 24_000 })
    }

    @Test func quotaErrorWantsFallback() async {
        let http = FakeHTTP([.init(status: 503, body: "{\"error\":{\"code\":\"provider_quota\",\"message\":\"out of characters\",\"fallback\":true}}")])
        let playback = FakePlaybackService()
        let provider = makeProvider(http, playback: playback)
        do {
            try await provider.speak("Hej.", language: .swedish, voice: VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Astrid"))
            Issue.record("expected an error")
        } catch {
            #expect(error == .network(.backend(status: 503, failure: AnswerFailure(code: "provider_quota", message: "out of characters", fallback: true))))
            #expect(error.wantsFallback)
        }
        #expect(playback.played.isEmpty)
    }

    @Test func unauthorizedInvalidatesTheSession() async {
        let http = FakeHTTP([.init(status: 401, body: "{\"error\":{\"code\":\"unauthorized\"}}")])
        let playback = FakePlaybackService()
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(session), http: http, now: { t0 })
        let provider = ElevenLabsTTSProvider(config: config, auth: auth, http: http, playback: playback)
        do {
            try await provider.speak("Hej.", language: .swedish, voice: .appleDefault)
            Issue.record("expected an error")
        } catch {
            guard case .network(.unauthorized) = error else { Issue.record("wrong error \(error)"); return }
        }
        #expect(!auth.hasSession)
    }

    @Test func longTextIsSplitAtWordBoundaries() {
        let words = (0..<120).map { "ord\($0)" }
        let text = words.joined(separator: " ")
        let pieces = ElevenLabsTTSProvider.pieces(text)
        #expect(pieces.count >= 2)
        #expect(pieces.allSatisfy { $0.count <= ElevenLabsTTSProvider.textLimit })
        #expect(pieces.joined(separator: " ") == text)
        #expect(ElevenLabsTTSProvider.pieces("  kort  ") == ["kort"])
        #expect(ElevenLabsTTSProvider.pieces("   ").isEmpty)
    }

    @Test func bodyOmitsVoiceIDForTheDefaultVoice() {
        let data = ElevenLabsTTSProvider.encodeBody(text: "Hi", language: .english, voiceID: nil)
        #expect(String(decoding: data, as: UTF8.self) == "{\"language\":\"en\",\"output_format\":\"pcm_24000\",\"text\":\"Hi\"}")
    }
}

@MainActor
@Suite struct VoiceCatalogTests {
    @Test func decodesBothLikelyShapes() throws {
        let wrapped = try VoiceCatalog.decode(Data("{\"voices\":[{\"name\":\"Astrid\",\"id\":\"a1\"},{\"name\":\"Erik\",\"voice_id\":\"e1\"}],\"default\":\"a1\"}".utf8))
        #expect(wrapped == [VoiceChoice(kind: .elevenLabs, voiceID: "a1", name: "Astrid"), VoiceChoice(kind: .elevenLabs, voiceID: "e1", name: "Erik")])
        let list = try VoiceCatalog.decode(Data("[{\"name\":\"Maja\",\"voiceId\":\"m1\"},{\"name\":\"NoID\"}]".utf8))
        #expect(list == [VoiceChoice(kind: .elevenLabs, voiceID: "m1", name: "Maja")])
        #expect(throws: AnswerError.self) { try VoiceCatalog.decode(Data("nope".utf8)) }
    }

    @Test func refreshLoadsVoicesWithAuthAndReportsFailures() async {
        let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt")),
                             .init(status: 200, body: "{\"voices\":[{\"name\":\"Astrid\",\"id\":\"a1\"}]}")])
        let catalog = VoiceCatalog(config: config, auth: SupabaseAuth(config: config, store: InMemorySessionStore(), http: http), http: http)

        await catalog.refreshIfNeeded()
        #expect(catalog.status == .loaded)
        #expect(catalog.voices.map(\.name) == ["Astrid"])
        #expect(http.requests[1].url == config.voicesURL)
        #expect(http.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
        await catalog.refreshIfNeeded()
        #expect(http.requests.count == 2, "loaded once per run")

        let failing = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt")),
                                .init(status: 404, body: "{\"error\":{\"code\":\"not_found\",\"message\":\"no voices function yet\"}}")])
        let failed = VoiceCatalog(config: config, auth: SupabaseAuth(config: config, store: InMemorySessionStore(), http: failing), http: failing)
        await failed.refresh()
        guard case .failed(let message) = failed.status else { Issue.record("expected failure"); return }
        #expect(message.contains("not_found"))
        #expect(failed.voices.isEmpty)
    }
}
