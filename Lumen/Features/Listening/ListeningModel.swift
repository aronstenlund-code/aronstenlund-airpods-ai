import Foundation
import Observation

/// Drives the Listening screen (MVP items 1–9). No business logic in views.
@MainActor
@Observable
final class ListeningModel: TranscriptSink, AnswerSink {
    let controller: SessionController
    let consent: any ConsentStoring
    let transcription: TranscriptionCoordinator
    let activation: ActivationController
    let answers: AnswerEngine
    let speaker: Speaker
    let voices: VoiceCatalog
    let notes: NotesStore
    let prep: PrepStore
    /// Historik and Minne (D49/D56), on this phone only.
    let history: HistoryStore
    let memory: MemoryStore
    /// Reports and shared history (D57). Nil: nothing leaves the phone this way.
    let feedback: FeedbackClient?
    /// The AirPods press (D74).
    private let remote: RemoteCommandHub?
    /// The hands-free mode to go back to when listening returns after a pause or an interruption (D74).
    private var resumeMode: ConversationMode?
    /// The last voice command and when, so a command seen both as a final result and as a turn runs once.
    private var lastVoice: (intent: VoiceIntent, at: Date)?
    /// An instruction is on its way to the backend for this mode (D69): what comes back is a calibration, or the
    /// suggestions the wearer asked for ("ge mig tre", D72).
    private var instructing: ConversationMode?
    /// The suggestion trigger that waits until the instruction is back.
    private var deferredTrigger: String?
    /// The trigger of the suggestions being made, so an instruction that cancels them can ask again.
    private var inFlightTrigger: String?
    /// The instruction was a request for more and its suggestions are on screen: nothing replaces them at once.
    private var instructionSuggested = false
    /// "Skickat", or why not.
    private(set) var reportNotice: String?
    /// "Fråga Lumen": the hands-free session ends after one answer.
    private var isSingleTurn = false
    /// Mikrofon per mode (D55).
    let microphone: MicrophoneSettings
    /// What the session is for: decides the microphone.
    private(set) var mode: ConversationMode = .standard
    /// The mode picker on the Listening screen, remembered between launches (D72).
    var selectedMode: ConversationMode = .standard {
        didSet { modeSettings.lastMode = selectedMode }
    }
    /// Intervjuläge and Rizzläge setup.
    let modeSettings: ModeSettings
    /// The running live session, Rizzläge or Socialt läge. Gone when it ends, and the words with it.
    private(set) var rizz: RizzSession?
    var isShowingInterviewSetup = false
    var isShowingLiveStart = false
    var isShowingAgeGate = false
    /// A microphone comparison is running: what is said is a test sentence, never a question.
    private var isComparing = false
    /// Course goals and personal keyword commands (D37).
    let goals: GoalsStore
    let commands: CommandStore
    /// "Sparade kommandot …" after a spoken save, shown once.
    private(set) var commandNotice: String?
    private let warmer: BackendWarmer?
    private let activity: (any ListeningActivityPresenting)?
    /// Provläge (D36): hands-free tutor session.
    let study: StudySessionController
    /// Why Provläge ended, shown once.
    private(set) var studyNotice: String?
    /// Per-answer latency budget (item 7), shown in the debug overlay.
    let latency = LatencyLog()
    private(set) var conversation = Conversation()
    /// The most recent question handed to the answer engine.
    private(set) var pendingQuestion: ActivationRequest?
    /// One-line notice under the answers: "not a question", failures, offline.
    private(set) var answerNotice: String?
    /// When the session was last saved as a note (item 8).
    private(set) var noteSavedAt: Date?
    var isShowingPrivacy = false
    var isShowingSettings = false
    var isShowingNotes = false
    var isShowingPrep = false
    var isShowingCommands = false
    var isShowingDiagnostics = false
    /// Text mode (item 6): the question being typed. Works without the microphone.
    var draftQuestion = ""

    var state: SessionState { controller.state }
    var isListening: Bool { controller.state.isListening }
    var isActiveSession: Bool { controller.isActiveSession }
    var canResume: Bool { controller.canResume }
    var lastError: String? { controller.lastError }
    var level: AudioLevel.Reading { controller.level }
    var language: TranscriptionLanguage { transcription.language.selected }
    var isAnswering: Bool {
        if case .answering = answers.status { return true }
        return false
    }
    var useMockAnswers: Bool {
        get { answers.useMock }
        set { answers.useMock = newValue }
    }
    /// Installed Apple voices for the selected language (settings picker).
    var appleVoices: [VoiceChoice] { AppleTTSProvider.installedVoices(for: language) }
    var canSaveNote: Bool { !conversation.answers.isEmpty }

    /// "AirPods Pro · HFP" — which microphone is live, from the session snapshot.
    var routeSummary: String? {
        guard let snapshot = controller.snapshot, let input = snapshot.inputs.first else { return nil }
        return "\(input.portName) · \(snapshot.transport)"
    }

    init(controller: SessionController, consent: any ConsentStoring,
         transcription: TranscriptionCoordinator, activation: ActivationController,
         answers: AnswerEngine, speaker: Speaker, voices: VoiceCatalog,
         notes: NotesStore, prep: PrepStore, warmer: BackendWarmer? = nil,
         activity: (any ListeningActivityPresenting)? = nil, study: StudySessionController? = nil,
         goals: GoalsStore? = nil, commands: CommandStore? = nil,
         history: HistoryStore? = nil, memory: MemoryStore? = nil, microphone: MicrophoneSettings? = nil,
         modeSettings: ModeSettings? = nil, feedback: FeedbackClient? = nil, remote: RemoteCommandHub? = nil) {
        self.controller = controller
        self.consent = consent
        self.transcription = transcription
        self.activation = activation
        self.answers = answers
        self.speaker = speaker
        self.voices = voices
        self.notes = notes
        self.prep = prep
        self.history = history ?? HistoryStore()
        self.memory = memory ?? MemoryStore()
        self.microphone = microphone ?? MicrophoneSettings()
        let modes = modeSettings ?? ModeSettings()
        self.modeSettings = modes
        // The remembered mode. Rizzläge only if the 18+ question was answered; the gate is never skipped.
        self.selectedMode = modes.lastMode == .rizz && !modes.isAdultConfirmed ? .standard : modes.lastMode
        self.feedback = feedback
        self.remote = remote
        self.goals = goals ?? GoalsStore()
        self.commands = commands ?? CommandStore()
        self.warmer = warmer
        self.activity = activity
        self.study = study ?? StudySessionController(settings: StudySettings(), session: controller)
        self.study.onEvent = { [weak self] event in self?.studyEvent(event) }
        controller.onStateChanged = { [weak self] state in self?.sessionStateChanged(state) }
        voices.onLoaded = { [weak speaker] voices, defaultID in
            speaker?.settings.reconcile(with: voices, defaultID: defaultID)
        }
        activation.onActivate = { [weak self] request in self?.activated(request) }
        answers.sink = self
        speaker.onSentenceStarted = { [weak self] provider in
            guard let self else { return }
            self.latency.markFirstSpeech(provider: provider)
            if self.study.isActive {
                // Our own voice is playing: gate the recogniser, watch the level for a barge-in (D36).
                self.study.speechStarted()
                self.transcription.setInputGated(true)
            }
        }
        speaker.onFinished = { [weak self] in self?.speechFinished() }
        refreshKeyterms()
        prep.onChange = { [weak self] in self?.refreshKeyterms() }
        remote?.onToggle = { [weak self] in await self?.togglePause() }
        remote?.onPlay = { [weak self] in
            guard let self, !self.isListening else { return }
            await self.togglePause()
        }
        remote?.onPause = { [weak self] in
            guard let self, self.isListening else { return }
            await self.togglePause()
        }
    }

    // MARK: - User actions

    /// The Listening screen opened, the app came back, or listening starts: wake the backend (D31) and load the
    /// voices (D23), which also signs in ahead of the first question. Quiet when offline; retried next time.
    func prepareBackend() async {
        history.purgeExpired()
        memory.purgeExpired()
        guard !answers.useMock else { return }
        Task { await feedback?.sync(history.entries) }
        Task { await warmer?.warm() }
        await voices.refreshIfNeeded()
    }

    /// Primary button: start when idle/error, stop when listening or paused.
    func toggleListening() async {
        if isActiveSession {
            await stopListening()
        } else {
            await startListening()
        }
    }

    func startListening() async {
        // Consent is checked here as well as in the UI: no microphone without a current consent record.
        guard consent.isGranted else {
            controller.log("Start refused: no consent")
            return
        }
        Task { await prepareBackend() }
        refreshKeyterms()
        await useMicrophone(for: mode)
        await controller.start()
        logMicrophone()
    }

    /// Selects the microphone for `mode`. A running session moves to the new route at once (D55).
    private func useMicrophone(for mode: ConversationMode) async {
        await use(config: microphone.source(for: mode).captureConfig(echoCancellation: mode == .prov && study.settings.useVoiceChatMode))
    }

    private func use(config: CaptureConfig) async {
        guard config != controller.config else { return }
        let wasActive = isActiveSession
        if wasActive { await controller.stop() }
        controller.config = config
        if wasActive {
            await controller.start()
            logMicrophone()
        }
    }

    private func logMicrophone() {
        controller.log("Microphone \(microphone.source(for: mode).rawValue) for \(mode.rawValue) · \(controller.config.rawValue) · \(routeSummary ?? "no route")")
    }

    /// The phone listens to other people best from a table, not from a pocket (D55).
    var usesPhoneMicrophone: Bool { controller.config.inputPreference == .builtInMic }
    var recognizerName: String {
        if case .running(let engine) = transcription.status { return engine.displayName }
        return "none"
    }

    // MARK: - Microphone comparison (D55)

    /// Starts listening on `source`; returns where the run begins in the transcript. Nil without consent.
    func startComparison(_ source: MicrophoneSource) async -> Int? {
        guard consent.isGranted else { return nil }
        isComparing = true
        await use(config: source.captureConfig())
        if !isListening {
            if canResume { await resume() } else { await controller.start() }
        }
        guard isListening else {
            isComparing = false
            return nil
        }
        return conversation.finalSegments.count
    }

    /// Everything heard since `mark`, including words the recogniser has not finalised.
    func finishComparison(from mark: Int) -> String {
        isComparing = false
        var parts = conversation.finalSegments.dropFirst(mark).map(\.text)
        if let partial = conversation.partial { parts.append(partial.text) }
        return parts.joined(separator: " ")
    }

    /// Command keywords first: they decide what happens, and Scribe takes a limited number of keyterms (D44).
    private func refreshKeyterms() {
        transcription.setContextualStrings(commands.commands.map(\.keyword) + prep.sttTerms)
    }

    func stopListening() async {
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        await controller.stop()
    }

    func resume() async {
        await controller.resume()
    }

    /// One tap to switch to music and back (D33): screen button, Live Activity and Control. Never starts a
    /// session: the microphone is only switched on from the app.
    func togglePause() async {
        if isListening {
            await controller.pause()
        } else if canResume {
            await controller.resume()
        }
    }

    private func sessionStateChanged(_ state: SessionState) {
        if state != .listening, study.isActive {
            // Paused, stopped or failed: the hands-free session cannot continue without the microphone. After a
            // pause or an interruption it comes back in the same mode (D74).
            if case .paused = state { resumeMode = mode }
            study.stop()
            transcription.setInputGated(false)
            handsFreeEnded()
        }
        switch state {
        case .listening:
            showActivity()
            if let again = resumeMode {
                resumeMode = nil
                controller.log("Listening again: back to \(again.rawValue)")
                Task { await startHandsFree(again) }
            }
        case .paused:
            // Whoever has the audio now keeps it: no speech may restart the engine behind their back.
            answers.cancel()
            speaker.interrupt()
            conversation.cancelAnswer()
            showActivity()
        case .idle, .error:
            resumeMode = nil
            conversation.clearTranscript()
            activity?.end()
        }
        switch state {
        case .listening, .paused: remote?.show(listening: state.isListening, mode: VoiceChannel.spokenName(resumeMode ?? mode))
        case .idle, .error: remote?.clear()
        }
    }

    private func showActivity() {
        activity?.show(ListeningActivityAttributes.ContentState(isPaused: !isListening, suggestions: rizz?.suggestions ?? [],
                                                                currentSuggestion: rizz?.index ?? 0))
    }

    /// Stops the microphone, forgets the session's transcript and clears the consent record; the consent
    /// screen is shown again by `RootView`.
    func withdrawConsent() async {
        await stopListening()
        conversation.clear()
        pendingQuestion = nil
        answerNotice = nil
        consent.revoke()
    }

    func clearHistory() {
        answers.cancel()
        speaker.interrupt()
        latency.clear()
        conversation.clear()
        pendingQuestion = nil
        answerNotice = nil
        noteSavedAt = nil
        commandNotice = nil
    }

    func previewVoice() {
        speaker.preview(speaker.settings.voice, language: language)
    }

    // MARK: - Provläge (D36)

    /// One tap starts the hands-free session (starting the microphone if needed), one tap ends it.
    func toggleStudyMode() async {
        if study.isActive {
            endStudy(bySilence: false)
        } else {
            await startStudy()
        }
    }

    /// The Listening screen's mode button. Intervjuläge and Rizzläge go through their start screens first.
    func toggleSelectedMode() async {
        if study.isActive {
            endStudy(bySilence: false)
            return
        }
        switch selectedMode {
        case .standard: await toggleListening()
        case .prov: await startStudy()
        case .interview: isShowingInterviewSetup = true
        case .rizz:
            if modeSettings.isAdultConfirmed { isShowingLiveStart = true } else { isShowingAgeGate = true }
        case .social: isShowingLiveStart = true
        }
    }

    /// The picker moved: Rizzläge asks for the age the first time it is opened (D63).
    func modeSelected() {
        if selectedMode == .rizz, !modeSettings.isAdultConfirmed { isShowingAgeGate = true }
    }

    func answerAgeGate(confirmed: Bool) {
        isShowingAgeGate = false
        if confirmed {
            modeSettings.confirmAdult()
        } else {
            selectedMode = .standard
        }
    }

    func startStudy() async {
        await startHandsFree(.prov)
    }

    func startHandsFree(_ newMode: ConversationMode) async {
        guard consent.isGranted else {
            controller.log("Hands-free \(newMode.rawValue) refused: no consent")
            return
        }
        if newMode == .rizz, !modeSettings.isAdultConfirmed {
            controller.log("Rizzläge refused: no age confirmation")
            isShowingAgeGate = true
            return
        }
        studyNotice = nil
        mode = newMode
        await useMicrophone(for: newMode)
        if !isListening {
            if canResume { await resume() } else { await startListening() }
            guard isListening else { return }
        }
        answers.cancel()
        speaker.interrupt()
        conversation.cancelAnswer()
        if let style = newMode.liveStyle {
            rizz = RizzSession(style: style)
            study.stallSilence = Self.stallSilence
            controller.playback.speechVolume = Self.rizzVolume
        } else {
            study.stallSilence = nil
        }
        study.start()
        controller.log("Hands-free \(newMode.rawValue) started")
    }

    /// Socialt läge and Rizzläge show and speak exactly one suggestion (D72).
    static let suggestionsShown = 1

    /// The Provläge card on the main screen (D72): one tap, no setup in between.
    func startProvFromCard() async {
        selectedMode = .prov
        await startStudy()
    }

    /// ~4 s of silence asks for a way to carry on (D43).
    static let stallSilence: TimeInterval = 4
    /// Quiet enough to say under one's breath, not loud enough to carry (D43). Tuned on device.
    static let rizzVolume: Float = 0.6

    /// Own lines reach Historik only from the AirPods mic: on the iPhone the level tag cannot tell the people on
    /// either side of the table apart, and other people's words are never saved (D56).
    private var ownLinesAreReliable: Bool { microphone.source(for: mode) == .airPods }

    /// One hands-free question for "Fråga Lumen", then the microphone goes off.
    func askFromShortcut() async {
        await controller.waitForForeground()
        isSingleTurn = true
        await startStudy()
    }

    func startFromShortcut() async {
        await controller.waitForForeground()
        if !isListening { await startListening() }
    }

    func startStudyFromShortcut() async {
        await controller.waitForForeground()
        if !study.isActive { await startStudy() }
    }

    func pauseFromShortcut() async {
        if isListening { await controller.pause() }
    }

    /// True when "Fråga Lumen" has had its answer and the session was closed.
    private func finishSingleTurn() -> Bool {
        guard isSingleTurn else { return false }
        endStudy(bySilence: false)
        Task { await stopListening() }
        return true
    }

    private func handsFreeEnded() {
        isSingleTurn = false
        if let session = rizz, !session.offered.isEmpty {
            let lines = ownLinesAreReliable ? session.ownLines.joined(separator: "\n") : ""
            history.record(HistoryEntry(question: lines.isEmpty ? nil : lines, answer: "",
                                        summary: "\(mode == .rizz ? "Rizzläge" : "Socialt läge"): \(session.offered.count) förslag.",
                                        suggestions: session.offered))
        }
        rizz = nil
        instructing = nil
        deferredTrigger = nil
        inFlightTrigger = nil
        controller.playback.speechVolume = 1
        mode = .standard
    }

    /// Ends the session. After the silence timeout the microphone is released too ("sparläge").
    func endStudy(bySilence: Bool) {
        guard study.isActive || bySilence else { return }
        study.stop()
        handsFreeEnded()
        showActivity()
        transcription.setInputGated(false)
        if bySilence {
            studyNotice = "Ended after \(study.settings.autoEndMinutes) min of silence; the microphone was switched off."
            controller.log("Hands-free session auto-ended after silence")
            Task { await stopListening() }
        } else {
            controller.log("Provläge ended by the user")
        }
    }

    private func studyEvent(_ event: StudyEvent) {
        switch event {
        case .turnStarted:
            break
        case .endOfTurn(let raw):
            // "Lumen, …" can close a turn before its final result arrives (D74).
            let utterance = VoiceChannel.parse(raw)
            if let intent = utterance.intent { perform(intent) }
            guard let text = utterance.before else {
                study.resumeListening()
                return
            }
            logTurn()
            if !mode.isLive, FillerFilter.isOnlyFiller(text) {
                controller.log("\(mode.rawValue): filler only, not sent")
                study.resumeListening()
                return
            }
            switch mode {
            case .interview: interviewTurn(text)
            case .rizz, .social: rizzTurn(text)
            case .standard, .prov: activated(ActivationRequest(query: text, trigger: .tutor, language: language))
            }
        case .stalled:
            if let session = rizz { requestSuggestions(trigger: session.hasConversation ? "stall" : "opener") }
        case .bargeIn:
            controller.log("Provläge: barge-in — stopping the answer")
            answers.cancel()
            speaker.interrupt()
            conversation.cancelAnswer()
            latency.end()
            transcription.setInputGated(false)
        case .autoEnded:
            endStudy(bySilence: true)
        }
    }

    // MARK: - Intervjuläge (D42)

    /// D72: the interviewer's question gets the finished answer, read aloud, and nothing else: no feedback, no
    /// follow-up questions. The wearer's own words (louder, by input level) are never answered, unless they ask for
    /// something out loud ("klar", "sammanfatta", "ge mig feedback").
    private func interviewTurn(_ text: String) {
        let speaker = RizzSpeaker.tag(levelDBFS: study.lastTurnLevelDBFS, thresholdDBFS: modeSettings.speakerThresholdDBFS)
        if speaker == .user, !VoiceCommand.isInterviewRequest(text) {
            controller.log("Intervjuläge: own turn at \(study.lastTurnLevelDBFS ?? -99) dBFS, not answered")
            study.resumeListening()
            return
        }
        activated(ActivationRequest(query: text, trigger: .overheard, language: language),
                  persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup, turn: "question"))
    }

    /// Likely questions and model answers from the role or job ad. Long, so it is shown, not spoken.
    func prepareInterview() {
        activated(ActivationRequest(query: language == .swedish ? "Förbered mig inför intervjun" : "Prepare me for the interview",
                                    trigger: .interviewPrep, language: language),
                  persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup))
    }

    // MARK: - Rizzläge (D43)

    private func rizzTurn(_ text: String) {
        let speaker = RizzSpeaker.tag(levelDBFS: study.lastTurnLevelDBFS, thresholdDBFS: modeSettings.speakerThresholdDBFS)
        controller.log("Rizzläge: turn tagged \(speaker.rawValue) · level \(study.lastTurnLevelDBFS ?? -99) dBFS · threshold \(modeSettings.speakerThresholdDBFS)")
        study.resumeListening() // the room goes on while the suggestions are being made
        guard var session = rizz else { return }
        if speaker == .user, session.usesSuggestion(text) {
            modeSettings.countUse(of: session.style)
        }
        session.add(speaker, text: text, at: Date())
        rizz = session
        if speaker == .other, !FillerFilter.isOnlyFiller(text) {
            requestSuggestions(trigger: "other_spoke")
        }
    }

    // MARK: - Voice (D74)

    /// "Lumen, …" in every mode. True when the words were for Lumen: they are never conversation.
    @discardableResult
    private func handleVoice(in text: String, at date: Date) -> Bool {
        let utterance = VoiceChannel.parse(text)
        guard let intent = utterance.intent else { return false }
        study.discardTurnText()
        if let before = utterance.before, study.isActive { study.transcriptFinal(before, at: date) }
        perform(intent)
        return true
    }

    private func perform(_ intent: VoiceIntent) {
        let now = Date()
        if let last = lastVoice, last.intent == intent, now.timeIntervalSince(last.at) < 5 { return }
        lastVoice = (intent, now)
        switch intent {
        case .switchTo(let target):
            controller.log("Voice: switch to \(target.rawValue)")
            Task { await switchByVoice(to: target) }
        case .pause:
            controller.log("Voice: pause")
            Task { await pauseByVoice() }
        case .stopListening:
            controller.log("Voice: stop listening")
            Task { await stopByVoice() }
        case .instruction(let text):
            controller.log("Voice: instruction (\(text.count) characters)") // the words stay out of the log
            instruct(text)
        }
    }

    /// "Lumen, byt till provläge" (D74). The same checks as the screen: Rizzläge needs the 18+ answer, a live mode
    /// its start screen once, Intervjuläge a role.
    func switchByVoice(to target: ConversationMode) async {
        if target == .rizz, !modeSettings.isAdultConfirmed {
            say("Rizzläge kräver att du bekräftar 18 år i appen.")
            return
        }
        if target.isLive, !modeSettings.hasConfirmedLiveStart(target) {
            say("\(VoiceChannel.spokenName(target).dropLast()) startas i appen första gången.")
            return
        }
        if target == .interview, modeSettings.interviewSetup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            say("Intervjuläge behöver en roll i appen först.")
            return
        }
        let current: ConversationMode? = study.isActive ? mode : (isListening ? .standard : nil)
        if current == target {
            say(VoiceChannel.spokenName(target))
            return
        }
        if study.isActive { endStudy(bySilence: false) }
        selectedMode = target
        if target == .standard {
            if !isListening {
                if canResume { await resume() } else { await startListening() }
            }
        } else {
            await startHandsFree(target)
        }
        say(VoiceChannel.spokenName(target))
    }

    private func pauseByVoice() async {
        guard isListening else { return }
        say(language == .swedish ? "Pausar." : "Pausing.")
        await speechDone()
        await controller.pause()
    }

    private func stopByVoice() async {
        say(language == .swedish ? "Slutar lyssna." : "Stopping.")
        await speechDone()
        await stopListening()
    }

    /// What follows the name when it is not a command. Socialt läge and Rizzläge: the D69 instruction path.
    /// The other modes: a question to Lumen.
    private func instruct(_ text: String) {
        if rizz != nil {
            liveInstruction(text)
        } else if study.isActive, mode == .interview {
            activated(ActivationRequest(query: text, trigger: .overheard, language: language),
                      persona: PersonaRequest(persona: "interview", setup: modeSettings.interviewSetup, turn: "question"))
        } else if study.isActive {
            activated(ActivationRequest(query: text, trigger: .tutor, language: language))
        } else {
            activated(ActivationRequest(query: text, trigger: .text, language: language))
        }
    }

    /// D69/D72: "Lumen, lite mindre kaxig" or "Lumen, ge mig tre pickup lines" in Socialt läge or Rizzläge. Sent
    /// as `social.calibrate` with the stored calibration, never as a line of the conversation. The backend answers a
    /// calibration with `done.calibration` and a request for more with that many suggestions.
    func liveInstruction(_ text: String) {
        guard let session = rizz,
              let persona = LiveRequest.instruction(text, for: session, interests: modeSettings.interests,
                                                    profile: modeSettings.rizzProfile,
                                                    calibration: modeSettings.calibration(for: mode),
                                                    adultConfirmed: modeSettings.isAdultConfirmed) else { return }
        if let trigger = inFlightTrigger { deferredTrigger = trigger } // the suggestions being made are cancelled
        inFlightTrigger = nil
        instructing = mode
        instructionSuggested = false
        controller.log("\(mode.rawValue): instruction sent") // the words stay out of the log
        let request = ActivationRequest(query: "", trigger: .rizz, language: language)
        pendingQuestion = request
        latency.begin(request)
        answers.answer(request, context: AnswerContext(memories: memory.backendItems()), persona: persona)
    }

    /// The instruction came back: store a calibration, then ask for the suggestions that waited.
    private func instructionEnded(_ calibration: String?, answered: Bool) {
        guard let instructed = instructing else { return }
        instructing = nil
        if let calibration {
            modeSettings.setCalibration(calibration, for: instructed)
            controller.log("\(instructed.rawValue): calibration stored (\(calibration.count) characters)")
            say(language == .swedish ? "Okej." : "Okay.")
        }
        let suggested = instructionSuggested
        instructionSuggested = false
        if let trigger = deferredTrigger, answered, !suggested {
            deferredTrigger = nil
            requestSuggestions(trigger: trigger)
        }
        deferredTrigger = nil
    }

    /// A short confirmation in the AirPods. Not while paused: the audio belongs to someone else then.
    private func say(_ line: String) {
        if case .paused = state { return }
        speaker.enqueue(line, language: language)
    }

    private func speechDone() async {
        for _ in 0..<60 where speaker.isSpeaking || speaker.hasPendingSpeech {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Which recogniser and microphone heard the turn (D74): cut sentences are traced to one of them.
    private func logTurn() {
        controller.log("Turn · \(mode.rawValue) · STT \(recognizerName) · mic \(microphone.source(for: mode).rawValue) · \(controller.config.rawValue)")
    }

    private func requestSuggestions(trigger: String) {
        guard let session = rizz else { return }
        if instructing != nil {
            deferredTrigger = trigger // the instruction goes first, the suggestions follow it
            return
        }
        guard let persona = LiveRequest.suggestions(for: session, trigger: trigger, interests: modeSettings.interests,
                                                    profile: modeSettings.rizzProfile,
                                                    calibration: modeSettings.calibration(for: mode),
                                                    adultConfirmed: modeSettings.isAdultConfirmed) else { return }
        let request = ActivationRequest(query: "", trigger: .rizz, language: language)
        pendingQuestion = request
        inFlightTrigger = trigger
        latency.begin(request)
        answers.answer(request, context: AnswerContext(memories: memory.backendItems()), persona: persona)
    }

    func answerSuggestions(_ options: [String]) {
        latency.markFirstText(provider: answers.activeProvider.name)
        if instructing != nil {
            // The wearer asked for more ("ge mig tre", D72): all of them, shown and spoken, this time only.
            instructionSuggested = true
            rizz?.offer(options)
            showActivity()
            speakAllSuggestions()
            return
        }
        inFlightTrigger = nil
        rizz?.offer(Array(options.prefix(Self.suggestionsShown))) // D72: one suggestion, shown and spoken
        showActivity()
        speakSuggestion()
    }

    private func speakAllSuggestions() {
        guard let options = rizz?.suggestions, !study.someoneIsTalking() else { return }
        for line in options { speaker.enqueue(line, language: language) }
    }

    /// "nästa", or the button on the Live Activity. With one suggestion on screen (D72) it asks for a fresh one.
    func nextSuggestion() {
        guard let session = rizz else { return }
        if session.suggestions.count <= 1 {
            requestSuggestions(trigger: session.hasConversation ? "stall" : "opener")
            return
        }
        rizz?.next()
        showActivity()
        speakSuggestion()
    }

    /// Only in a pause, never over anyone. A missed moment stays on the Live Activity.
    private func speakSuggestion() {
        guard let line = rizz?.current, !study.someoneIsTalking(), !speaker.isSpeaking else { return }
        speaker.enqueue(line, language: language)
    }

    private func speechFinished() {
        guard study.isActive, !finishSingleTurn() else { return }
        transcription.setInputGated(false)
        study.resumeListening()
    }

    /// The answer produced no speech (silent mode, empty answer): back to listening right away.
    private func studyAnswerEnded() {
        guard study.isActive, !mode.isLive, !speaker.hasPendingSpeech, !finishSingleTurn() else { return }
        transcription.setInputGated(false)
        study.resumeListening()
    }

    /// Item 8: saves the session's answers as a local note.
    @discardableResult
    func saveNote() -> Note? {
        guard let note = notes.save(conversation, language: language) else {
            controller.log("Save note: nothing to save")
            return nil
        }
        noteSavedAt = note.createdAt
        controller.log("Note saved: \(note.title)")
        return note
    }

    // MARK: - Activation (item 3)

    func askAboutLast() {
        if !activation.answerLast(conversation: conversation, language: language) {
            controller.log("Ask about last: nothing final in the transcript yet")
        }
    }

    /// Text mode (item 6): typed questions take the same path as spoken ones (`mode: text` to the backend).
    func submitText(_ text: String) {
        activation.submitText(text, language: language)
    }

    var canSendDraft: Bool { !draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func sendDraft() {
        guard canSendDraft else { return }
        let text = draftQuestion
        draftQuestion = ""
        submitText(text)
    }

    private func activated(_ request: ActivationRequest, persona: PersonaRequest? = nil) {
        if VoiceCommand.isMusicHandOff(request.query) { return } // the final result already paused the session
        if request.trigger == .auto, FillerFilter.isOnlyFiller(request.query) { return } // D74
        pendingQuestion = request
        answerNotice = nil
        // A new question interrupts the current answer and its speech (assignment item 5).
        speaker.interrupt()
        latency.begin(request)
        controller.log("Activation (\(request.trigger.rawValue)): \(request.query)")
        if !study.isActive { logTurn() }
        // Provläge sends the whole session's memory (the backend keeps the last 6 pairs).
        let qaLimit = study.isActive ? AnswerContext.qaLimit : 3
        let matched = commands.matches(in: request.query)
        if !matched.isEmpty {
            controller.log("Commands matched: \(matched.map(\.keyword).joined(separator: ", "))")
        }
        let context = AnswerContext(transcript: conversation.recentText(seconds: 60),
                                    recentQA: conversation.recentQA(limit: qaLimit),
                                    prepTerms: prep.backendTerms,
                                    goals: goals.compact,
                                    commands: matched.map { AnswerContext.Command(keyword: $0.keyword, instruction: $0.instruction) },
                                    memories: memory.backendItems())
        answers.answer(request, context: context, persona: persona)
    }

    // MARK: - AnswerSink (item 4)

    func answerStarted(_ request: ActivationRequest, source: String) {
        if request.trigger == .rizz { return } // suggestions have no answer of their own
        conversation.beginAnswer(question: request.query, source: source, at: request.createdAt,
                                 isOwnQuestion: request.trigger.isUsersOwnWords)
        if study.isActive { study.answerStarted() }
    }

    func answerQuestionReconstructed(_ question: String) {
        conversation.setAnswerQuestion(question)
    }

    func answerDelta(_ text: String) {
        latency.markFirstText(provider: answers.activeProvider.name)
        conversation.appendAnswerText(text)
    }

    func answerSentence(_ sentence: String) {
        if case .paused = state { return } // a typed question while paused is shown, not spoken over the music
        if pendingQuestion?.trigger == .interviewPrep { return }
        speaker.enqueue(sentence, language: pendingQuestion?.language ?? language)
    }

    func answerCompleted(latencyMs: Double?, done: AnswerDone?) {
        if instructing != nil {
            latency.end()
            instructionEnded(done?.calibration, answered: true)
            return
        }
        inFlightTrigger = nil
        if let turn = conversation.completeAnswer(latencyMs: latencyMs) {
            history.record(HistoryEntry(createdAt: turn.createdAt, question: turn.isOwnQuestion ? turn.question : nil,
                                        answer: turn.answer, summary: done?.summary))
            Task { await feedback?.sync(history.entries) }
        }
        if let fact = done?.memoryAdd {
            memory.add(fact)
        }
        if let latencyMs {
            controller.log("Answer · first text after \(Int(latencyMs)) ms" + (done?.usage?.model.map { " · \($0)" } ?? ""))
        }
        studyAnswerEnded()
    }

    func answerReportRequested() {
        latency.end()
        conversation.cancelAnswer()
        Task { await reportPreviousTurn() }
        studyAnswerEnded()
    }

    /// "Rapportera" on an answer (D57). The question goes along only if it was the user's own.
    @discardableResult
    func report(_ turn: AnswerTurn, comment: String? = nil) async -> Bool {
        guard let feedback else { return false }
        do {
            try await feedback.send(type: "report", fragment: turn.isOwnQuestion ? turn.question : nil, answer: turn.answer,
                                    comment: comment, mode: mode.rawValue, persona: mode.isLive ? "social" : nil,
                                    timings: turn.latencyMs.map { ["first_text_ms": $0] })
            reportNotice = language == .swedish ? "Skickat" : "Sent"
            return true
        } catch {
            reportNotice = error.localizedDescription
            controller.log("Report failed: \(error.localizedDescription)")
            return false
        }
    }

    /// The spoken command: the last answer, or the suggestion on screen in Rizzläge. Confirms by voice.
    private func reportPreviousTurn() async {
        let suggestion = rizz?.current.map { AnswerTurn(question: "", answer: $0, source: "rizz", isOwnQuestion: false) }
        guard let turn = suggestion ?? conversation.answers.last else {
            reportNotice = language == .swedish ? "Inget svar att rapportera" : "No answer to report"
            return
        }
        if await report(turn), let notice = reportNotice {
            if case .paused = state { return }
            speaker.enqueue(notice, language: language)
        }
    }

    /// Settings → Feedback & suggestions.
    func sendFeedback(type: String, text: String) async -> Bool {
        guard let feedback else { return false }
        do {
            try await feedback.send(type: type, comment: text)
            return true
        } catch {
            controller.log("Feedback failed: \(error.localizedDescription)")
            return false
        }
    }

    func setSharing(_ sharing: Bool) {
        feedback?.settings.setSharing(sharing)
        Task { await feedback?.sync(history.entries) }
    }

    func answerSkipped(_ request: ActivationRequest) {
        if instructing != nil {
            latency.end()
            instructionEnded(nil, answered: true)
            return
        }
        latency.end()
        conversation.cancelAnswer()
        answerNotice = "Not a question — no answer (auto mode)"
        controller.log("Auto: backend says not a question: \(request.query)")
        studyAnswerEnded()
    }

    func answerFailed(_ message: String, wantsFallback: Bool) {
        if instructing != nil {
            latency.end()
            answerNotice = message
            controller.log("Instruction failed: \(message)")
            instructionEnded(nil, answered: false)
            return
        }
        inFlightTrigger = nil
        latency.end()
        conversation.cancelAnswer()
        answerNotice = message
        controller.log("Answer failed: \(message)" + (wantsFallback ? " · fallback requested (on-device engine not available on this iPhone)" : ""))
        studyAnswerEnded()
    }

    // MARK: - TranscriptSink (fed by TranscriptionCoordinator)

    func receivePartialTranscript(_ text: String, at date: Date = Date()) {
        conversation.updatePartial(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        if study.isActive { study.transcriptPartial(text) }
    }

    func receiveFinalTranscript(_ text: String, at date: Date = Date()) {
        let before = conversation.finalSegments.count
        conversation.finalize(text, at: date, overlapsPlayback: controller.playback.isSpeaking)
        guard conversation.finalSegments.count > before, let segment = conversation.finalSegments.last else { return }
        if isComparing { return }
        if !segment.overlapsPlayback, VoiceCommand.isMusicHandOff(segment.text) {
            controller.log("Spoken pause: handing the audio back")
            Task { await controller.pause() }
            return
        }
        if !segment.overlapsPlayback, handleVoice(in: segment.text, at: date) {
            return
        }
        if rizz != nil, RizzCommand.isNext(segment.text) {
            study.resumeListening()
            nextSuggestion()
            return
        }
        if rizz != nil, VoiceCommand.isReport(segment.text) {
            study.resumeListening()
            Task { await reportPreviousTurn() }
            return
        }
        if !segment.overlapsPlayback, saveSpokenCommand(segment.text) {
            return // "spara kommando …" is handled on the phone, never sent as a question
        }
        if study.isActive {
            // Provläge decides turns by silence, not by the question gate.
            study.transcriptFinal(segment.text, at: date)
            return
        }
        activation.segmentFinalized(segment, conversation: conversation, language: language,
                                    isPlaybackSpeaking: controller.playback.isSpeaking, now: date)
    }

    /// Voice-created command (D37): "spara kommando <ord>: <instruktion>". Confirms by voice.
    @discardableResult
    func saveSpokenCommand(_ text: String) -> Bool {
        guard let parsed = CommandMatcher.parseSaveCommand(text),
              let command = commands.save(keyword: parsed.keyword, instruction: parsed.instruction) else { return false }
        commandNotice = "Saved command \"\(command.keyword)\""
        controller.log("Command saved by voice: \(command.keyword) → \(command.instruction)")
        let confirmation = language == .swedish ? "Sparade kommandot \(command.keyword)." : "Saved the command \(command.keyword)."
        if case .paused = state { return true }
        speaker.enqueue(confirmation, language: language)
        return true
    }

    func receiveAnswer(question: String, answer: String, latencyMs: Double? = nil, source: String) {
        conversation.append(AnswerTurn(question: question, answer: answer, latencyMs: latencyMs, source: source))
    }
}
