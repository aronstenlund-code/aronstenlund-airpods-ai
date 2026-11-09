import Foundation
import Testing
@testable import Lumen

/// T7 (Toby): Angela's A15 "Mer?" window through the app's real chain in the Simulator: capture → VAD → Scribe live →
/// the window → `/answer` → the speaker (Apple's voice, no /tts cost).
///
/// The window opens when a short answer has been *spoken*, and that moment depends on /answer and the speech, so a
/// fixed WAV list cannot hit it. This test builds the app's own composition (as `AppContainer` does) with a capture of
/// its own, `CueCapture`: silence like a quiet room, and a WAV file played the moment the test says so. The test waits
/// for "Säg ja för mer" (`isOfferingMore`), waits the case's delay and plays the probe.
///
/// Cases (`AppTests/E2E/Audio/more.tsv`), one session each:
/// - "ja", "mer", "gärna" 1.5 s into the window: the developed answer; time from the end of the word to the first
///   spoken word of it (the requirement is under 1 s, which A15 says waits for Kevin's K13 cache).
/// - "ja" 6 s after the window opened: it closed by silence after 5 s, nothing more.
/// - "ja men vad är fotosyntes?": not a "ja"; the window closes and the question is answered.
/// - "ja" / "ja gärna" in another voice with the wearer's voice learned (D81): not a "ja".
/// - a new question in the window: closes it, and the question is answered.
///
/// Output: `<LUMEN_E2E_OUT>/more.json`. Live and paid (Scribe, /answer): only when `scripts/apptest/more.sh` sets
/// `LUMEN_E2E_MORE_DIR`. Simulator only: never a verification on a device (nod and AirPods press are Aron's).
enum MoreEnvironment {
    static var audioDir: URL? {
        ProcessInfo.processInfo.environment["LUMEN_E2E_MORE_DIR"].map { URL(fileURLWithPath: $0) }
    }
}

// MARK: - A capture that plays a file when told

/// Silence in 40 ms chunks in real time, and the samples of `play` mixed in when asked. Same contract as
/// `FileCaptureService` (which `SessionController` takes for tests, A1).
@MainActor
final class CueCapture: CaptureServicing {
    private(set) var isCapturing = false
    private(set) var level: AudioLevel.Reading = .silence
    private(set) var chunks: AsyncStream<AudioChunk>?
    let ringBuffer = Int16RingBuffer(seconds: LumenAudioFormat.ringBufferSeconds, sampleRate: LumenAudioFormat.sampleRate)
    var inputFormatDescription: String? { "Cue capture (T7) · 16000 Hz · 1 ch · Int16" }
    var conversionErrorCount: Int { 0 }
    var onFormatChange: (@MainActor (String) -> Void)?
    var onError: (@MainActor (AudioError) -> Void)?
    var voiceProcessing = false

    private var queue: [Int16] = []
    private var task: Task<Void, Never>?
    private var continuation: AsyncStream<AudioChunk>.Continuation?
    private(set) var lastPlayEnded: Date?

    func start() throws(AudioError) {
        stop()
        let (stream, continuation) = AsyncStream.makeStream(of: AudioChunk.self, bufferingPolicy: .bufferingNewest(500))
        chunks = stream
        self.continuation = continuation
        isCapturing = true
        task = Task { [weak self] in
            var index: Int64 = 0
            let frames = FileCaptureService.chunkFrames
            while let self, !Task.isCancelled, self.isCapturing {
                var samples = [Int16](repeating: 0, count: frames)
                if !self.queue.isEmpty {
                    let n = min(frames, self.queue.count)
                    samples.replaceSubrange(0..<n, with: self.queue.prefix(n))
                    self.queue.removeFirst(n)
                    if self.queue.isEmpty { self.lastPlayEnded = Date() }
                }
                self.ringBuffer.write(samples)
                self.level = AudioLevel.reading(samples)
                self.continuation?.yield(AudioChunk(samples: samples, hostTime: mach_absolute_time(), firstSampleIndex: index))
                index += Int64(samples.count)
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }

    func stop() {
        isCapturing = false
        task?.cancel()
        task = nil
        continuation?.finish()
        continuation = nil
        chunks = nil
        level = .silence
    }

    /// Plays the samples (real time) and returns when the last one was sent.
    func play(_ samples: [Int16]) async -> Date {
        lastPlayEnded = nil
        queue.append(contentsOf: samples)
        while !queue.isEmpty || lastPlayEnded == nil {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return lastPlayEnded ?? Date()
    }

    func exportLast(seconds: Double) throws(AudioError) -> URL {
        try exportSamples(ringBuffer.snapshot(lastSeconds: seconds), name: "cue-last\(Int(seconds))s")
    }

    func exportSamples(_ samples: [Int16], name: String) throws(AudioError) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lumen-\(name)-\(UUID().uuidString.prefix(6)).wav")
        try WAVWriter.write(samples: samples, sampleRate: Int(LumenAudioFormat.sampleRate), to: url)
        return url
    }
}

// MARK: - The app's composition with that capture

/// The same wiring as `AppContainer.init` (2026-11-09), with `CueCapture` and a voice profile in a file of its own.
@MainActor
struct MoreRig {
    let controller: SessionController
    let model: ListeningModel
    let consent: ConsentStore
    let speakers: SpeakerIdentifier

    init(capture: CueCapture, profileFile: URL) {
        let graph = AudioGraph()
        let session = AudioSessionManager()
        let playback = PlaybackService(graph: graph)
        let consent = ConsentStore()
        let language = LanguageSettings()
        let activationSettings = ActivationSettings()
        let voiceSettings = VoiceSettings()
        let controller = SessionController(session: session, capture: capture, playback: playback, graph: graph)
        let activation = ActivationController(settings: activationSettings)
        let http = URLSessionHTTP()
        let auth = SupabaseAuth(config: .lumen, store: KeychainSessionStore(), http: http)
        let transcription = TranscriptionCoordinator(controller: controller, language: language, settings: STTSettings(),
                                                     vad: VoiceActivityLoader(),
                                                     makeProvider: { locale, engine in
            switch engine {
            case .scribe:
                ScribeProvider(locale: locale, language: language.selected, config: .lumen, auth: auth, http: http)
            case .legacyOnDevice:
                LegacySpeechProvider(locale: locale)
            case .speechTranscriber, .dictationTranscriber:
                AppleSpeechProvider(locale: locale, engine: engine)
            }
        })
        let answers = AnswerEngine(provider: CloudAnswerProvider(config: .lumen, auth: auth, http: http))
        let speaker = Speaker(settings: voiceSettings,
                              apple: AppleTTSProvider(playback: playback),
                              premium: ElevenLabsTTSProvider(config: .lumen, auth: auth, http: http, playback: playback),
                              playback: playback)
        let share = ShareSettings()
        let speakers = SpeakerIdentifier(profiles: VoiceProfileStore(file: profileFile))
        let model = ListeningModel(controller: controller, consent: consent,
                                   transcription: transcription, activation: activation,
                                   answers: answers, speaker: speaker,
                                   voices: VoiceCatalog(config: .lumen, auth: auth, http: http),
                                   notes: NotesStore(), prep: PrepStore(),
                                   warmer: BackendWarmer(config: .lumen, http: http),
                                   activity: ListeningActivityPresenter(),
                                   history: HistoryStore(), memory: MemoryStore(),
                                   feedback: FeedbackClient(config: .lumen, auth: auth, http: http, settings: share),
                                   remote: RemoteCommandHub(),
                                   memoryExtractor: MemoryExtractor(config: .lumen, auth: auth, http: http),
                                   speakers: speakers, studyCards: StudyCardStore(),
                                   studyCardsClient: StudyCardsClient(config: .lumen, auth: auth, http: http),
                                   studyProfileClient: StudyProfileClient(config: .lumen, auth: auth, http: http),
                                   examMaterials: ExamMaterials(), examClient: ExamClient(config: .lumen, auth: auth, http: http),
                                   examPlans: ExamPlanStore(), phrases: CommandPhraseStore(), music: MusicRemote.live(),
                                   tips: CommandTipStore(), preferences: PreferenceStore())
        transcription.sink = model
        self.controller = controller
        self.model = model
        self.consent = consent
        self.speakers = speakers
    }
}

// MARK: - The test

@MainActor
@Suite(.serialized, .enabled(if: MoreEnvironment.audioDir != nil, "set LUMEN_E2E_MORE_DIR (scripts/apptest/more.sh)"))
struct MoreE2ETests {
    struct Case: Codable {
        let id: String
        let kind: String
        let delay: Double
        let voice: String
        let key: String
        let question: String
        let probe: String
    }

    struct CaseResult: Codable {
        let id: String
        let kind: String
        let delay: Double
        let voice: String
        let question: String
        let probe: String
        var enrolled: String?
        var firstAnswer: String?
        var firstAnswerWords: Int?
        var windowOpenAt: Double?
        var screenShowedOffer = false
        var probeStartAt: Double?
        var probeEndAt: Double?
        var closedAt: Double?
        var closeReason: String?
        var screenClearedAfterClose: Bool?
        var askedAfterProbe: [String] = []
        var answeredAfterProbe: [String] = []
        var answerAfterProbe: String?
        var answerAfterProbeWords: Int?
        /// End of the probe word → first word of the next answer spoken.
        var secondsToSpeech: Double?
        /// End of the probe word → the next answer complete.
        var secondsToAnswer: Double?
        var verdict = ""
        var log: [String] = []
    }

    struct Event {
        let t: Double
        let kind: String
        let text: String
    }

    @Test func moreWindowThroughTheRealChain() async throws {
        let dir = try #require(MoreEnvironment.audioDir)
        let cases = try Self.cases(in: dir)
        var results: [CaseResult] = []
        for item in cases {
            let result = try await run(item, dir: dir)
            print("T7 case \(item.id): \(result.verdict)")
            results.append(result)
            try write(results)
            try await Task.sleep(for: .seconds(3)) // a breath for /answer's rate limit between sessions
        }
        for result in results where !result.verdict.hasPrefix("ok") {
            Issue.record("\(result.id) '\(result.probe)' (\(result.kind), \(result.delay) s): \(result.verdict)")
        }
        // The requirement: the long answer under 1 s after "ja". A15: not before K13's cached long answer.
        for result in results where result.kind == "more" {
            withKnownIssue("A15/K13: the long answer is fetched as 'utveckla' until K13's cache", isIntermittent: true) {
                #expect((result.secondsToSpeech ?? .infinity) < 1, "\(result.id): \(result.secondsToSpeech.map { String(format: "%.2f s", $0) } ?? "no speech") after the word")
            }
        }
    }

    // MARK: One case in one session

    private func run(_ item: Case, dir: URL) async throws -> CaseResult {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: VoiceSettings.speakKey)
        defaults.set(try JSONEncoder().encode(VoiceChoice.appleDefault), forKey: VoiceSettings.voiceKey)

        let question = try FileCaptureService.decode(dir.appendingPathComponent("question-\(item.id).wav"))
        let probe = try FileCaptureService.decode(dir.appendingPathComponent("probe-\(item.id).wav"))
        let profileFile = FileManager.default.temporaryDirectory.appendingPathComponent("t7-voice-\(item.id)-\(UUID().uuidString.prefix(6)).json")

        let capture = CueCapture()
        let rig = MoreRig(capture: capture, profileFile: profileFile)
        let model = rig.model
        var result = CaseResult(id: item.id, kind: item.kind, delay: item.delay, voice: item.voice, question: item.question,
                                probe: item.probe)
        if item.voice == "other" {
            let samples = try FileCaptureService.decode(dir.appendingPathComponent("enroll-wearer.wav"))
            switch await rig.speakers.enroll(samples) {
            case .saved(let seconds): result.enrolled = String(format: "saved, %.1f s of speech", seconds)
            case .tooLittleSpeech: result.enrolled = "too little speech"
            case .modelsUnavailable: result.enrolled = "models unavailable"
            }
        }
        rig.consent.grant()

        let start = Date()
        var events: [Event] = []
        model.sessionObserver = { event, date in
            let t = date.timeIntervalSince(start)
            switch event {
            case .heard(let text): events.append(Event(t: t, kind: "heard", text: text))
            case .asked(let query, let trigger): events.append(Event(t: t, kind: "asked", text: "\(query) [\(trigger)]"))
            case .answered(let question, let answer, _, let source):
                events.append(Event(t: t, kind: "answered", text: "\(question) → \(answer) [\(source)]"))
                events.append(Event(t: t, kind: "answer", text: answer))
            case .spoke(let text): events.append(Event(t: t, kind: "spoke", text: text))
            }
        }
        rig.controller.logObserver = { entry in
            events.append(Event(t: entry.time.timeIntervalSince(start), kind: "log", text: entry.text))
        }
        func now() -> Double { Date().timeIntervalSince(start) }

        await model.startMode(.standard)
        try await Task.sleep(for: .seconds(4)) // Scribe connects
        _ = await capture.play(question)

        // The window opens when the short answer has been spoken.
        var opened = false
        let openDeadline = Date().addingTimeInterval(45)
        while Date() < openDeadline {
            if model.isOfferingMore { opened = true; break }
            try await Task.sleep(for: .milliseconds(50))
        }
        result.firstAnswer = events.last { $0.kind == "answer" }?.text
        result.firstAnswerWords = result.firstAnswer.map { $0.split(whereSeparator: \.isWhitespace).count }
        if opened {
            result.windowOpenAt = now()
            result.screenShowedOffer = true
            try await Task.sleep(for: .seconds(item.delay))
            result.probeStartAt = now()
            result.probeEndAt = await capture.play(probe).timeIntervalSince(start)
            // Afterwards: the next answer (if any) and quiet.
            let watchUntil = Date().addingTimeInterval(30)
            var quietSince: Date?
            while Date() < watchUntil {
                try await Task.sleep(for: .milliseconds(100))
                if result.closedAt == nil, let close = events.first(where: { $0.kind == "log" && $0.text.hasPrefix("More? window closed") }) {
                    result.closedAt = close.t
                    result.screenClearedAfterClose = !model.isOfferingMore
                }
                if model.isAnswering || model.speaker.isSpeaking { quietSince = nil; continue }
                quietSince = quietSince ?? Date()
                if let quiet = quietSince, Date().timeIntervalSince(quiet) > 6 { break }
            }
        }
        if model.isActiveSession { await model.endSession() }
        model.sessionObserver = nil
        rig.controller.logObserver = nil
        try? FileManager.default.removeItem(at: profileFile)

        if let close = events.first(where: { $0.kind == "log" && $0.text.hasPrefix("More? window closed") }) {
            result.closedAt = close.t
            result.closeReason = close.text.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "")
        }
        if let end = result.probeEndAt, let begin = result.probeStartAt {
            let after = events.filter { $0.t >= begin }
            result.askedAfterProbe = after.filter { $0.kind == "asked" }.map(\.text)
            result.answeredAfterProbe = after.filter { $0.kind == "answered" }.map(\.text)
            let answer = after.first { $0.kind == "answer" }
            result.answerAfterProbe = answer?.text
            result.answerAfterProbeWords = answer.map { $0.text.split(whereSeparator: \.isWhitespace).count }
            result.secondsToAnswer = answer.map { $0.t - end }
            result.secondsToSpeech = after.first { $0.kind == "spoke" && $0.t >= end - 0.5 }.map { $0.t - end }
        }
        result.log = events.sorted { $0.t < $1.t }.filter { $0.kind != "answer" }.map { String(format: "%7.2f ", $0.t) + "\($0.kind) " + $0.text }
        result.verdict = Self.judge(result, key: item.key)
        return result
    }

    static func judge(_ r: CaseResult, key: String) -> String {
        guard r.windowOpenAt != nil else {
            return "no window: first answer \(r.firstAnswerWords ?? 0) words (\(r.firstAnswer ?? "none"))"
        }
        let tookMore = r.closeReason?.hasPrefix("yes") == true
        switch r.kind {
        case "more":
            guard tookMore else { return "the word was not taken as more (closed: \(r.closeReason ?? "never"))" }
            guard r.secondsToSpeech != nil else { return "taken, but no long answer spoken" }
            return "ok"
        case "late":
            guard !tookMore else { return "a 'ja' after 6 s still got more" }
            guard r.closeReason == "silence" else { return "closed by \(r.closeReason ?? "nothing"), expected silence" }
            if let open = r.windowOpenAt, let closed = r.closedAt, abs(closed - open - MoreOffer.window) > 1 {
                return String(format: "closed after %.1f s, expected 5", closed - open)
            }
            return r.answeredAfterProbe.isEmpty ? "ok" : "the late 'ja' got an answer: \(r.answeredAfterProbe)"
        case "other":
            if r.enrolled?.hasPrefix("saved") != true { return "voice not learned: \(r.enrolled ?? "nil")" }
            return tookMore ? "another voice's '\(r.probe)' got more" : "ok"
        default: // "newquestion": the window closes and the words are an ordinary turn
            guard !tookMore else { return "taken as more" }
            let answered = r.answeredAfterProbe.contains { $0.lowercased().contains(key) }
            return answered ? "ok" : "the new question was not answered (asked \(r.askedAfterProbe))"
        }
    }

    private func write(_ results: [CaseResult]) throws {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(results).write(to: out.appendingPathComponent("more.json"))
    }

    private static func cases(in dir: URL) throws -> [Case] {
        // more.tsv is copied next to the generated audio by scripts/apptest/more.sh.
        let text = try String(contentsOf: dir.appendingPathComponent("more.tsv"), encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let p = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard p.count >= 7 else { return nil }
            return Case(id: p[0], kind: p[1], delay: Double(p[2]) ?? 1.5, voice: p[3], key: p[4].lowercased(), question: p[5], probe: p[6])
        }
    }
}
