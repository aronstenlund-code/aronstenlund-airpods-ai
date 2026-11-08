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
    /// Called when the first audio of a sentence is scheduled, so a slow `/tts` counts (latency, item 7 / D28).
    var onSentenceStarted: (@MainActor (_ provider: String) -> Void)?
    /// D82: every text Lumen speaks, so its echo can be recognised in what the microphone hears next.
    var onSpeak: (@MainActor (String) -> Void)?
    private(set) var spokenCount = 0
    private(set) var fallbackCount = 0

    private let apple: any TTSProvider
    private let premium: (any TTSProvider)?
    private let playback: any PlaybackServicing
    private var queue: [Request] = []
    private var drainTask: Task<Void, Never>?
    /// The provider whose first audio for the current sentence has not been scheduled yet.
    private var awaitingFirstAudio: String?
    /// Bumped by `interrupt()` so a cancelled drain cannot reset the state of the drain that replaced it.
    private var drainGeneration = 0
    /// D80: audio for a sentence fetched before the pause was over, by its text.
    private var prepared: [String: Task<(samples: [Int16], sampleRate: Double)?, Never>] = [:]
    /// A4: how smooth the voice was: this answer so far, the last whole answer, everything since launch.
    private var answerStats = VoiceStreamStats()
    private(set) var lastAnswerStats: VoiceStreamStats?
    private(set) var totalStats = VoiceStreamStats()
    /// A4: called when an answer has been spoken to the end, with its stats (the log line).
    var onVoiceStats: (@MainActor (VoiceStreamStats) -> Void)?

    init(settings: VoiceSettings, apple: any TTSProvider, premium: (any TTSProvider)?, playback: any PlaybackServicing) {
        self.settings = settings
        self.apple = apple
        self.premium = premium
        self.playback = playback
        playback.rate = settings.rate
        playback.onAudioScheduled = { [weak self] in
            guard let self, let provider = self.awaitingFirstAudio else { return }
            self.awaitingFirstAudio = nil
            self.onSentenceStarted?(provider)
        }
    }

    var isSpeaking: Bool { status != .idle || playback.isSpeaking }

    /// Queues a sentence of an answer. Ignored in silent mode.
    func enqueue(_ text: String, language: TranscriptionLanguage) {
        guard settings.speakAnswers else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queue.append(Request(text: trimmed, language: language, voice: settings.voice))
        // A4: something is already being spoken: fetch this sentence's voice now, so it follows without a pause.
        if drainTask != nil { prepare(trimmed, language: language) }
        startDrainingIfNeeded()
    }

    /// A5: a short message from the app itself, always in Apple's voice: it must be heard when ElevenLabs is the
    /// thing that failed. Ignored in silent mode (it is on the screen anyway).
    func announce(_ text: String, language: TranscriptionLanguage) {
        guard settings.speakAnswers else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queue.append(Request(text: trimmed, language: language, voice: .appleDefault))
        startDrainingIfNeeded()
    }

    /// A5: the chosen voice failed (the sentence was read with Apple's voice), or worked again.
    var onVoiceFallback: (@MainActor (String) -> Void)?
    var onVoiceRecovered: (@MainActor () -> Void)?

    /// D80: fetches the voice for `text` now, to play it the moment it is queued. Premium voice only.
    @discardableResult
    func prepare(_ text: String, language: TranscriptionLanguage) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let voice = settings.voice
        guard settings.speakAnswers, voice.kind == .elevenLabs, let premium, !trimmed.isEmpty, prepared[trimmed] == nil else {
            return false
        }
        prepared[trimmed] = Task { try? await premium.synthesize(trimmed, language: language, voice: voice) }
        return true
    }

    /// The answer it was fetched for was thrown away.
    func discardPrepared() {
        for task in prepared.values { task.cancel() }
        prepared.removeAll()
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
        answerStats = VoiceStreamStats()
        queue.removeAll()
        awaitingFirstAudio = nil
        discardPrepared()
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

    /// Nothing queued and nothing being spoken (Provläge goes back to listening).
    var hasPendingSpeech: Bool { !queue.isEmpty || drainTask != nil }

    /// Called when the queue has been spoken to the end (not on interrupt).
    var onFinished: (@MainActor () -> Void)?

    private func drain() async {
        let generation = drainGeneration
        defer {
            if generation == drainGeneration {
                drainTask = nil
                status = .idle
                finishAnswerStats()
                onFinished?()
            }
        }
        while !queue.isEmpty {
            if Task.isCancelled || generation != drainGeneration { return }
            let request = queue.removeFirst()
            await speak(request)
        }
    }

    private func finishAnswerStats() {
        guard answerStats.sentences > 0 else { return }
        lastAnswerStats = answerStats
        totalStats.add(answerStats)
        onVoiceStats?(answerStats)
        answerStats = VoiceStreamStats()
    }

    private func speak(_ request: Request) async {
        onSpeak?(request.text)
        let provider: any TTSProvider = (request.voice.kind == .elevenLabs ? premium : nil) ?? apple
        if let task = prepared.removeValue(forKey: request.text), let audio = await task.value, !audio.samples.isEmpty {
            // Fetched while the user was still pausing (D80): it plays at once.
            status = .speaking(provider: provider.name)
            awaitingFirstAudio = provider.name
            do {
                try playback.play(samples: audio.samples, sampleRate: audio.sampleRate)
                playback.endOfSpeech()
                spokenCount += 1
                answerStats.sentences += 1
                answerStats.prefetched += 1
                notice = nil
                return
            } catch {
                Log.playback.error("prepared audio failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        status = .speaking(provider: provider.name)
        awaitingFirstAudio = provider.name
        do {
            try await provider.speak(request.text, language: request.language, voice: request.voice)
            if provider.name != apple.name { onVoiceRecovered?() }
            spokenCount += 1
            if let stats = provider.lastStats { answerStats.add(stats) } else { answerStats.sentences += 1 }
            notice = nil
        } catch {
            if Task.isCancelled || error == .cancelled { return }
            Log.playback.error("\(provider.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            if error.wantsFallback, provider.name != apple.name {
                fallbackCount += 1
                notice = "Premium voice unavailable — using Apple's voice (\(error.localizedDescription))"
                onVoiceFallback?(error.localizedDescription)
                status = .speaking(provider: apple.name)
                awaitingFirstAudio = apple.name
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
