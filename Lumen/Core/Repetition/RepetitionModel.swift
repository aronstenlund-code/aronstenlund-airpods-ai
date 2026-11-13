import AVFAudio
import Foundation
import MediaPlayer
import Observation

/// Settings for a new exam (D146): number of questions and the long answers' length.
struct DrillSettings: Equatable, Sendable {
    enum Length: String, CaseIterable, Sendable {
        case shorter, normal, longer
        var label: String {
            switch self {
            case .shorter: "Kortare"
            case .normal: "Normal"
            case .longer: "Längre"
            }
        }
        /// D146: about 90 words by default.
        var words: Int {
            switch self {
            case .shorter: 60
            case .normal: Drill.defaultLongWords
            case .longer: 130
            }
        }
    }

    var questions = Drill.defaultQuestionCount
    var length: Length = .normal

    static let questionRange = 3...60
}

// MARK: - K47: sharing

enum DrillShareError: Error, Equatable {
    /// D143: only when all the sound is ready (K47 answers 409 with the progress).
    case audioNotReady(ready: Int, total: Int)
    case notAvailable
    case server(String)

    var userMessage: String {
        switch self {
        case .audioNotReady(let ready, let total): "Delas när ljudet är klart (\(ready) av \(total))."
        case .notAvailable: "Delning kommer snart."
        case .server(let message): message
        }
    }
}

/// What the share sheet sends and what opens a shared exam.
struct DrillShareResult: Equatable, Sendable {
    /// The link to send (`https://earmind.ai/p/<code>`, or `earmind://prov/<code>` without it).
    var url: URL
    var code: String
}

/// K47 (`/drill` "share" and "import"): a link to the exam, and a copy in the receiver's account with the same sound
/// (0 new ElevenLabs characters, D143).
@MainActor
protocol DrillSharing: AnyObject, Sendable {
    func link(for drill: Drill) async throws(DrillShareError) -> DrillShareResult
    func importDrill(code: String) async throws(DrillShareError) -> Drill
}

@MainActor
final class DrillShareClient: DrillSharing {
    private let cloud: (any DrillCloudSyncing)?

    /// Without a cloud (the Simulator's mock mode) sharing honestly says it is not available.
    init(cloud: (any DrillCloudSyncing)?) {
        self.cloud = cloud
    }

    static func url(code: String) -> URL? { URL(string: "earmind://prov/\(code)") }

    /// `earmind://prov/<code>`, `https://earmind.ai/p/<code>` or a pasted text with one of them, or a bare code.
    static func code(in url: URL) -> String? {
        if url.scheme == "earmind" {
            guard url.host() == "prov" else { return nil }
            return clean(url.lastPathComponent)
        }
        if url.scheme == "https", url.host()?.hasSuffix("earmind.ai") == true {
            let parts = url.pathComponents
            guard let p = parts.firstIndex(of: "p"), parts.indices.contains(p + 1) else { return nil }
            return clean(parts[p + 1])
        }
        return nil
    }

    /// What the user pasted in "Har du fått ett prov?": a link or the code itself.
    static func code(inText text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for word in trimmed.split(whereSeparator: \.isWhitespace) {
            if let url = URL(string: String(word)), url.scheme != nil, let code = code(in: url) { return code }
        }
        return clean(trimmed)
    }

    /// K47: codes are 8–16 letters and digits, lower case.
    private static func clean(_ raw: String) -> String? {
        let code = raw.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return (8...16).contains(code.count) ? code : nil
    }

    func link(for drill: Drill) async throws(DrillShareError) -> DrillShareResult {
        guard let cloud else { throw .notAvailable }
        guard let id = drill.serverID else { throw .audioNotReady(ready: 0, total: drill.audioFileCount) }
        do throws(DrillCloudError) {
            let link = try await cloud.share(id: id)
            let url = link.url.flatMap { URL(string: $0) } ?? link.app_url.flatMap { URL(string: $0) } ?? Self.url(code: link.code)
            guard let url else { throw DrillCloudError.offline("bad link") }
            return DrillShareResult(url: url, code: link.code)
        } catch {
            if case .refused(let status, let code, let message) = error {
                if code == "audio_not_ready" { throw .server(message) }
                if status == 404 && code == "not_found" { throw .server(message) }
                if status == 400 { throw .notAvailable } // a server without K47's "share" yet
            }
            throw .server(error.userMessage)
        }
    }

    func importDrill(code: String) async throws(DrillShareError) -> Drill {
        guard let cloud else { throw .notAvailable }
        do throws(DrillCloudError) {
            let view = try await cloud.importShared(code: code)
            var drill = Drill.from(view)
            drill.sharedFrom = code
            return drill
        } catch {
            if case .refused(let status, _, _) = error, status == 400 { throw .notAvailable }
            throw .server(error.userMessage)
        }
    }
}

// MARK: - The mode

/// D142 (A79–A81): the repetition mode for the screens. Exams, making them (K45), their sound and their place on
/// the server (K46), the AirPods check (R11), Starta prov and sharing (K47).
@MainActor
@Observable
final class RepetitionModel {
    let store: DrillStore
    let session: RepetitionSession
    let maker: any DrillMaking
    let audio: any DrillAudioProviding
    let sharing: any DrillSharing
    let remote: RemoteCommandHub
    /// K46: the exams per account. Nil in the mock mode (`-RepetitionMock YES`): only the phone.
    @ObservationIgnored let cloud: (any DrillCloudSyncing)?
    /// Ends a listening mode before the repetition takes the audio and the AirPods buttons.
    @ObservationIgnored var stopListening: (@MainActor () async -> Void)?
    /// A92 (D166, K57): "Fråga om Earmind". Nil: the row and the ? button are not shown.
    @ObservationIgnored var help: (any HelpAnswering)?

    /// A83 (K49): Publicera prov and Prov från din skola. Nil in the mock mode.
    @ObservationIgnored var publishing: (any DrillPublishingService)?

    /// A88 (D161): the profile, where Nytt prov's "Vilken årskurs?" is kept.
    @ObservationIgnored var profile: StudyProfileStore?

    /// A88: the grade chosen last time (nil = skipped, or never asked).
    var preferredGrade: StudyProfile.Grade? {
        get { profile?.profile.grade }
        set {
            guard let profile, profile.profile.grade != newValue, let newValue else { return }
            profile.profile.grade = newValue // "Hoppa över" keeps what the profile had
        }
    }
    @ObservationIgnored private let defaults: UserDefaults

    /// The playing screen is up.
    var showsPlayer = false
    /// A share link opened in the app: the exam to add.
    var incomingCode: String?
    var importMessage: String?
    /// The exam to open after an import or a new exam (Start shows it).
    var openDrill: UUID?

    init(store: DrillStore, session: RepetitionSession, maker: any DrillMaking, audio: any DrillAudioProviding,
         sharing: any DrillSharing, remote: RemoteCommandHub, cloud: (any DrillCloudSyncing)? = nil,
         defaults: UserDefaults = .standard) {
        self.store = store
        self.session = session
        self.maker = maker
        self.audio = audio
        self.sharing = sharing
        self.remote = remote
        self.cloud = cloud
        self.defaults = defaults
    }

    var drills: [Drill] { store.drills }

    // MARK: Making (A79)

    func make(_ material: DrillMaterial, settings: DrillSettings, correction: String? = nil,
              subject: String? = nil, grade: String? = nil) async throws(DrillMakingError) -> DrillDraft {
        try await maker.make(material, subject: subject, grade: grade, correction: correction,
                             questions: settings.questions, longWords: settings.length.words)
    }

    /// Saves on the phone at once, then on the server, which starts the sound in the background (D143: when the exam
    /// is saved). Items whose texts changed lose their old sound; the others keep it.
    @discardableResult
    func save(_ drill: Drill) -> Drill {
        var drill = drill
        let before = store.drill(drill.id)
        drill.items = drill.items.map { item in
            var item = item
            item.long = DrillItem.long(item.long, startingWith: item.short) // D145
            if let old = before?.items.first(where: { $0.id == item.id }), !old.sameText(as: item) {
                item.questionAudio = old.question == item.question ? old.questionAudio : nil
                item.longAudio = nil
                item.shortEndMs = nil
            }
            return item
        }
        drill.questionCount = drill.items.count
        if cloud != nil { drill.needsUpload = true }
        store.save(drill)
        prepareAudio(drill)
        return drill
    }

    func delete(_ drill: Drill) {
        if session.drill?.id == drill.id { end() }
        store.delete(drill.id)
        if let cloud, let id = drill.serverID {
            Task { try? await cloud.delete(id: id) }
        }
    }

    func prepareAudio(_ drill: Drill) {
        let audio = self.audio
        Task { await audio.prepare(drill) }
    }

    /// On opening: the exams of this account on the server (R5: another phone), then the sound of every exam that is
    /// not ready.
    func refresh() async {
        if let cloud {
            do throws(DrillCloudError) {
                let remote = try await cloud.list()
                let ids = Set(remote.map(\.id))
                for entry in remote where !store.drills.contains(where: { $0.serverID == entry.id }) {
                    if let view = try? await cloud.status(id: entry.id) { store.save(Drill.from(view)) }
                }
                // Deleted on another phone: gone here too, unless it has changes the server has not seen.
                for drill in store.drills {
                    if let id = drill.serverID, !ids.contains(id), drill.needsUpload != true { store.delete(drill.id) }
                }
            } catch {
                Log.repetition.info("Drill list: \(error.userMessage, privacy: .public)")
            }
        }
        for drill in store.drills where audio.tracks(for: drill) == nil || drill.needsUpload == true { prepareAudio(drill) }
    }

    func prepareAllAudio() {
        Task { await refresh() }
    }

    func progress(_ drill: Drill) -> (ready: Int, total: Int) { audio.progress(for: drill) }

    func isAudioReady(_ drill: Drill) -> Bool {
        let p = progress(drill)
        return p.total > 0 && p.ready == p.total
    }

    /// Kelly Ke49: Starta prov works as soon as the first question has its sound; the player waits for the rest.
    func canStart(_ drill: Drill) -> Bool {
        audio.track(for: drill, at: 0) != nil
    }

    func newAnswer(for question: String, in drill: Drill) async throws(DrillMakingError) -> DrillItem {
        try await maker.answer(question, summary: drill.summary, notes: drill.summary.covers, longWords: drill.longWords)
    }

    // MARK: Playing (A78, A80)

    func savedIndex(_ drill: Drill) -> Int? { session.savedIndex(for: drill) }

    func start(_ drill: Drill, at index: Int = 0) async {
        guard !drill.items.isEmpty, canStart(drill) || audio.track(for: drill, at: index) != nil else { return }
        await stopListening?()
        let audio = self.audio
        let store = self.store
        let id = drill.id
        // Kelly N1: the first time anyone plays an exam, the first lap explains that the answer comes on a press.
        let firstLap = !defaults.bool(forKey: Self.playedKey)
        defaults.set(true, forKey: Self.playedKey)
        // K49: a play of a copy from a publication is counted there (a number, no identity).
        if let publishing, drill.fromPublication != nil, let id = drill.serverID {
            Task { await publishing.played(drillID: id) }
        }
        session.start(drill, count: drill.items.count, at: index,
                      onePressPausesAnswer: ControlCheck.usesEarbudLayout(defaults),
                      firstLap: firstLap, cue: audio.cue(for: drill), tempo: tempo,
                      pauseMusic: pauseMusicEnabled ? pauseMusic : nil) { i in
            audio.track(for: store.drill(id) ?? drill, at: i)
        }
        showsPlayer = true
    }

    static let playedKey = "repetition.hasPlayed"

    // MARK: Voice, tempo and the limit (A84, D151, D152, D155)

    static let tempoKey = "repetition.tempo"
    /// A91 (D164): music during the pause, on by default when there is music in the app.
    static let pauseMusicKey = "repetition.pauseMusic"
    @ObservationIgnored let pauseMusic: any RepetitionPauseMusic = BundledPauseMusic()

    var pauseMusicEnabled: Bool {
        get { defaults.object(forKey: Self.pauseMusicKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.pauseMusicKey) }
    }
    /// A89 (D162): "Längd på långa svar" lives in Inställningar › Avancerat; Nytt prov has no choice any more.
    static let longAnswerLengthKey = "repetition.longAnswerLength"

    /// What Nytt prov sends as `long_words` (D162: Normal = about 90 words unless changed in Avancerat).
    var longAnswerLength: DrillSettings.Length {
        get { DrillSettings.Length(rawValue: defaults.string(forKey: Self.longAnswerLengthKey) ?? "") ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: Self.longAnswerLengthKey) }
    }

    /// A89: Nytt prov's settings, the length from Avancerat.
    var newDrillSettings: DrillSettings {
        var settings = DrillSettings()
        settings.length = longAnswerLength
        return settings
    }
    /// D151: the tempos on offer; below 0.70 the voice stays at 0.70 and the rest is silence (D152).
    static let tempos: [Double] = [0.5, 0.65, 0.7, 0.75, 0.85, 0.9, 1.0, 1.5]
    /// D151: the three voices (the blind test's A, B and C, the model names never shown).
    static let voices = ["A", "B", "C"]

    var tempo: Double {
        get {
            let saved = defaults.double(forKey: Self.tempoKey)
            return Self.tempos.contains(saved) ? saved : 1
        }
        set { defaults.set(newValue, forKey: Self.tempoKey) }
    }

    static func tempoLabel(_ tempo: Double) -> String {
        tempo == 1 ? "Normal" : String(format: "%.2f", tempo).replacingOccurrences(of: ".", with: ",") + "×"
    }

    /// The bundled sample of a voice (the blind test's three sentences, `Resources/VoiceSamples`).
    static func voiceSample(_ voice: String) -> URL? {
        Bundle.main.url(forResource: "rost-\(voice)", withExtension: "mp3")
    }

    /// D155: "x av 15 frågor kvar den här månaden", from the last `list`.
    var quota: DrillQuota? { (cloud as? DrillCloudClient)?.lastQuota }

    func quotaExceeded(_ drill: Drill) -> Bool {
        (audio as? CloudDrillAudio)?.quotaExceeded.contains(drill.id) ?? false
    }

    // MARK: Publicera prov (A83, D149, D150, K49)

    static let mySchoolKey = "repetition.mySchool"
    static let schoolListOpenedKey = "repetition.schoolListOpened"
    static let lastDisplayNameKey = "repetition.lastDisplayName"

    /// Ke52 "Din skola": kept only on the phone, sent as `my_school`, never published.
    var mySchool: DrillSchool? {
        get {
            defaults.data(forKey: Self.mySchoolKey).flatMap { try? JSONDecoder().decode(DrillSchool.self, from: $0) }
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.mySchoolKey)
            } else {
                defaults.removeObject(forKey: Self.mySchoolKey)
            }
            mySchoolAsked = true
        }
    }

    /// "Vilken skola går du på?" was shown (answered or skipped).
    var mySchoolAsked: Bool {
        get { defaults.bool(forKey: Self.mySchoolKey + ".asked") }
        set { defaults.set(newValue, forKey: Self.mySchoolKey + ".asked") }
    }

    /// Ke52: a user name saved as the suggestion next time (the switch is off again).
    var lastDisplayName: String {
        get { defaults.string(forKey: Self.lastDisplayNameKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.lastDisplayNameKey) }
    }

    var canPublish: Bool { publishing != nil }

    func schools(matching query: String) async throws(DrillCloudError) -> [DrillSchool] {
        guard let publishing else { return [] }
        return try await publishing.schools(matching: query)
    }

    /// Publishes (or updates) and keeps the publication on the exam.
    func publish(_ drill: Drill, school: DrillSchool, subject: String, examDate: Date,
                 displayName: String?) async throws(DrillCloudError) {
        guard let publishing, let id = drill.serverID else {
            throw .refused(status: 409, code: "publish_incomplete", message: "Publiceras när ljudet är klart.")
        }
        let view = try await publishing.publish(drillID: id, school: school, subject: subject, examDate: examDate,
                                                displayName: displayName)
        guard var latest = store.drill(drill.id) else { return }
        latest.publication = DrillPublication(id: view.id, school: view.school, subject: view.subject,
                                              examDate: view.examDate ?? examDate, displayName: view.display_name)
        store.save(latest)
        if let name = displayName, !name.isEmpty { lastDisplayName = name }
    }

    func unpublish(_ drill: Drill) async throws(DrillCloudError) {
        guard let publishing, let id = drill.serverID else { return }
        try await publishing.unpublish(drillID: id)
        guard var latest = store.drill(drill.id) else { return }
        latest.publication = nil
        store.save(latest)
    }

    /// Prov från din skola: the student's own school first (K49 orders it).
    func searchPublications(school: DrillSchool?, subject: String?) async throws(DrillCloudError) -> [DrillPublicationView] {
        guard let publishing else { return [] }
        defaults.set(Date(), forKey: Self.schoolListOpenedKey)
        return try await publishing.search(school: school, subject: subject, mySchool: mySchool)
    }

    /// "Lägg till i mina prov": the user's own copy with the same sound (0 characters).
    func addPublication(_ publication: DrillPublicationView) async throws(DrillCloudError) -> Drill {
        guard let publishing else { throw .refused(status: 400, code: "unavailable", message: "Prov från din skola går inte att öppna än.") }
        let view = try await publishing.importPublication(id: publication.id)
        var drill = Drill.from(view)
        drill.fromPublication = publication.id
        store.save(drill)
        prepareAudio(drill)
        return drill
    }

    /// The copy of a publication already added, if any.
    func added(_ publication: DrillPublicationView) -> Drill? {
        store.drills.first { $0.fromPublication == publication.id }
    }

    func report(_ publication: DrillPublicationView, reason: DrillReportReason) async throws(DrillCloudError) {
        guard let publishing else { return }
        try await publishing.report(publicationID: publication.id, reason: reason)
    }

    func end() {
        session.stop()
        showsPlayer = false
    }

    // MARK: Sharing (A81)

    func shareLink(_ drill: Drill) async throws(DrillShareError) -> DrillShareResult {
        let p = progress(drill)
        guard p.total > 0, p.ready == p.total else { throw .audioNotReady(ready: p.ready, total: p.total) }
        return try await sharing.link(for: drill)
    }

    func handle(_ url: URL) -> Bool {
        guard let code = DrillShareClient.code(in: url) else { return false }
        open(code: code)
        return true
    }

    /// "Har du fått ett prov?": a pasted link or code.
    func open(code: String) {
        incomingCode = code
        Task { await importIncoming() }
    }

    private func importIncoming() async {
        guard let code = incomingCode else { return }
        incomingCode = nil
        do throws(DrillShareError) {
            var drill = try await sharing.importDrill(code: code)
            drill.needsUpload = nil
            store.save(drill)
            prepareAudio(drill)
            openDrill = drill.id
            importMessage = "\(drill.title) är tillagt."
        } catch {
            importMessage = error == .notAvailable ? "Delade prov går inte att öppna än." : error.userMessage
        }
    }
}

// MARK: - The AirPods check (A80, A81, R11)

/// "Styr med dina AirPods": asks for 1, 2 and 3 presses and sees which commands really arrive, so no one has to know
/// their model. iOS sends AirPods presses only to the app that plays, so the check plays the exam's first question
/// once (untested on device whether that is enough).
@MainActor
@Observable
final class ControlCheck {
    enum Step: Int, CaseIterable, Sendable {
        case one = 1, two = 2, three = 3

        var prompt: String {
            switch self {
            case .one: "Tryck en gång nu"
            case .two: "Tryck två gånger nu"
            case .three: "Tryck tre gånger nu"
            }
        }

        var hint: String {
            switch self {
            case .one: "på skaftet, som när du pausar musik"
            case .two: "på skaftet, som när du byter låt"
            case .three: "på skaftet, som när du går tillbaka en låt"
            }
        }

        func accepts(_ command: RemoteCommand) -> Bool {
            switch self {
            case .one: command.repetitionEvent == .long
            case .two: command == .next
            case .three: command == .previous
            }
        }
    }

    private(set) var step: Step? = .one
    private(set) var passed: Set<Step> = []
    private(set) var missed: Set<Step> = []
    /// "Hoppa över" (Kelly B4: "Hoppades över", not "Kom inte fram").
    private(set) var skipped: Set<Step> = []
    /// What arrived, for the log ("2 tryck → play").
    private(set) var heard: [String] = []

    private let hub: RemoteCommandHub
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var player: AVAudioPlayer?
    private let waitSeconds: Double
    @ObservationIgnored private let defaults: UserDefaults

    /// Spec §3, AirPods 1/2: three presses never came, so 1 press (play/pause) pauses during an answer. Saved by
    /// the last check that finished; the player reads it at Starta prov.
    static let earbudLayoutKey = "repetition.earbudLayout"

    static func usesEarbudLayout(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: earbudLayoutKey)
    }
    private let activatesAudio: Bool

    init(hub: RemoteCommandHub, waitSeconds: Double = 8, activatesAudio: Bool = true, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hub = hub
        self.waitSeconds = waitSeconds
        self.activatesAudio = activatesAudio
    }

    var isDone: Bool { step == nil }
    var allWork: Bool { passed.count == Step.allCases.count }
    /// AirPods 1 and 2: one function per earbud, so two presses or three presses never arrive (spec §3).
    var needsEarbudSettings: Bool { isDone && (missed.contains(.two) || missed.contains(.three)) }

    func begin(sound: URL?) {
        if activatesAudio {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try? AVAudioSession.sharedInstance().setActive(true)
            if let sound, let player = try? AVAudioPlayer(contentsOf: sound) {
                player.volume = 0.6
                player.play()
                self.player = player
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: "Styr med dina AirPods",
                                                               MPNowPlayingInfoPropertyPlaybackRate: 1.0]
        }
        hub.takeOver { [weak self] command in self?.received(command) }
        restart()
    }

    /// "Prova igen".
    func restart() {
        passed = []
        missed = []
        skipped = []
        heard = []
        step = .one
        armTimeout()
    }

    func end() {
        timeout?.cancel()
        player?.stop()
        player = nil
        hub.release()
        if activatesAudio { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil }
    }

    func received(_ command: RemoteCommand) {
        guard let current = step else { return }
        heard.append("\(current.rawValue) tryck → \(command.rawValue)")
        Log.repetition.info("Control check: \(current.rawValue) press(es) asked, \(command.rawValue, privacy: .public) came")
        if current.accepts(command) { passed.insert(current) } else { missed.insert(current) }
        advance()
    }

    /// "Hoppa över": counts as not arrived for the instructions, but is shown as skipped.
    func skip() {
        guard let current = step else { return }
        skipped.insert(current)
        timedOut()
    }

    /// Nothing came in time (or a test says so).
    func timedOut() {
        guard let current = step else { return }
        heard.append("\(current.rawValue) tryck → inget")
        missed.insert(current)
        advance()
    }

    private func advance() {
        guard let current = step else { return }
        step = Step(rawValue: current.rawValue + 1)
        if step == nil {
            timeout?.cancel()
            // Only a real answer from the AirPods counts: "Hoppa över" on all three says nothing about the earbuds.
            if passed.contains(.one) { defaults.set(missed.contains(.three), forKey: Self.earbudLayoutKey) }
            Log.repetition.info("Control check done: \(self.heard.joined(separator: ", "), privacy: .public)")
        } else {
            armTimeout()
        }
    }

    private func armTimeout() {
        timeout?.cancel()
        let wait = waitSeconds
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(wait * 1000)))
            guard !Task.isCancelled else { return }
            self?.timedOut()
        }
    }
}
