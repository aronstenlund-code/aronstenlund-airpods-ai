import Foundation
import Observation

/// Speaks answer sentences in order as they arrive (item 5). The chosen voice is tried first; a network/quota
/// problem falls back to Apple's voice for that sentence (D18). A new question interrupts everything.
@MainActor
@Observable
final class Speaker {
    enum Status: Equatable, Sendable {
        case idle
        case speaking(provider: String)
    }

    struct Request: Equatable, Sendable {
        var text: String
        var language: TranscriptionLanguage
        var voice: VoiceChoice
    }

    let settings: VoiceSettings
    private(set) var status: Status = .idle
    /// Last problem worth showing ("ElevenLabs unavailable — using Apple's voice").
    private(set) var notice: String?
    /// Called when a provider starts speaking a sentence (latency instrumentation, item 7).
    var onSentenceStarted: (@MainActor (_ provider: String) -> Void)?
    private(set) var spokenCount = 0
    private(set) var fallbackCount = 0

    private let apple: any TTSProvider
    private let premium: (any TTSProvider)?
    private let playback: any PlaybackServicing
    private var queue: [Request] = []
    private var drainTask: Task<Void, Never>?
    /// Bumped by `interrupt()` so a cancelled drain cannot reset the state of the drain that replaced it.
    private var drainGeneration = 0

    init(settings: VoiceSettings, apple: any TTSProvider, premium: (any TTSProvider)?, playback: any PlaybackServicing) {
        self.settings = settings
        self.apple = apple
        self.premium = premium
        self.playback = playback
        playback.rate = settings.rate
    }

    var isSpeaking: Bool { status != .idle || playback.isSpeaking }

    /// Queues a sentence of an answer. Ignored in silent mode.
    func enqueue(_ text: String, language: TranscriptionLanguage) {
        guard settings.speakAnswers else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queue.append(Request(text: trimmed, language: language, voice: settings.voice))
        startDrainingIfNeeded()
    }

    /// Speaks a short sample with `voice` (voice picker preview); interrupts anything playing.
    func preview(_ voice: VoiceChoice, language: TranscriptionLanguage) {
        interrupt()
        let sample = language == .swedish
            ? "Hej! Så här låter jag. Roten ur hundra är tio."
            : "Hello! This is how I sound. The square root of a hundred is ten."
        queue.append(Request(text: sample, language: language, voice: voice))
        startDrainingIfNeeded()
    }

    /// Stops speech and forgets queued sentences (new question, stop listening).
    func interrupt() {
        drainGeneration += 1
        drainTask?.cancel()
        drainTask = nil
        queue.removeAll()
        playback.stop()
        status = .idle
    }

    func applyRate() {
        playback.rate = settings.rate
    }

    private func startDrainingIfNeeded() {
        guard drainTask == nil else { return }
        drainTask = Task { [weak self] in
            await self?.drain()
        }
    }

    private func drain() async {
        let generation = drainGeneration
        defer {
            if generation == drainGeneration {
                drainTask = nil
                status = .idle
            }
        }
        while !queue.isEmpty {
            if Task.isCancelled || generation != drainGeneration { return }
            let request = queue.removeFirst()
            await speak(request)
        }
    }

    private func speak(_ request: Request) async {
        let provider: any TTSProvider = (request.voice.kind == .elevenLabs ? premium : nil) ?? apple
        status = .speaking(provider: provider.name)
        onSentenceStarted?(provider.name)
        do {
            try await provider.speak(request.text, language: request.language, voice: request.voice)
            spokenCount += 1
            notice = nil
        } catch {
            if Task.isCancelled || error == .cancelled { return }
            Log.playback.error("\(provider.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            if error.wantsFallback, provider.name != apple.name {
                fallbackCount += 1
                notice = "Premium voice unavailable — using Apple's voice (\(error.localizedDescription))"
                status = .speaking(provider: apple.name)
                onSentenceStarted?(apple.name)
                do {
                    try await apple.speak(request.text, language: request.language, voice: .appleDefault)
                    spokenCount += 1
                } catch {
                    notice = error.localizedDescription
                }
            } else {
                notice = error.localizedDescription
            }
        }
    }
}
