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
}

/// K47 (`/drill-share`, `/drill-import`). Until it is deployed `notAvailable` is the honest answer.
@MainActor
protocol DrillSharing: AnyObject {
    func link(for drill: Drill) async throws(DrillShareError) -> URL
    func importDrill(code: String) async throws(DrillShareError) -> Drill
}

@MainActor
final class DrillShareClient: DrillSharing {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    static func url(code: String) -> URL? { URL(string: "earmind://prov/\(code)") }

    /// `earmind://prov/<code>` → the code.
    static func code(in url: URL) -> String? {
        guard url.scheme == "earmind", url.host() == "prov" else { return nil }
        let code = url.lastPathComponent
        return code.isEmpty || code == "/" ? nil : code
    }

    func link(for drill: Drill) async throws(DrillShareError) -> URL {
        struct Reply: Decodable { var code: String }
        let items = drill.items.map { ["id": $0.id.uuidString, "question": $0.question, "short": $0.short, "long": $0.long] }
        let body: [String: Any] = ["drill_id": drill.id.uuidString, "title": drill.title, "items": items,
                                   "summary": ["subject": drill.summary.subject, "grade": drill.summary.grade,
                                               "covers": drill.summary.covers]]
        let reply: Reply = try await call("drill-share", body)
        guard let url = Self.url(code: reply.code) else { throw .server("bad code") }
        return url
    }

    func importDrill(code: String) async throws(DrillShareError) -> Drill {
        struct Reply: Decodable {
            struct Item: Decodable { var question: String; var short: String; var long: String }
            struct Summary: Decodable { var subject: String?; var grade: String?; var covers: String? }
            var title: String
            var summary: Summary?
            var items: [Item]
        }
        let reply: Reply = try await call("drill-import", ["code": code])
        return Drill(title: reply.title,
                     summary: DrillSummary(subject: reply.summary?.subject ?? "", grade: reply.summary?.grade ?? "",
                                           covers: reply.summary?.covers ?? ""),
                     items: reply.items.map { DrillItem(question: $0.question, short: $0.short, long: $0.long) },
                     questionCount: reply.items.count, sharedFrom: code)
    }

    private func call<Reply: Decodable>(_ function: String, _ body: [String: Any]) async throws(DrillShareError) -> Reply {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.projectURL.appending(path: "functions/v1/\(function)"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 20
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (response, data) = try await http.data(for: request)
            switch response.statusCode {
            case 200: return try JSONDecoder().decode(Reply.self, from: data)
            case 404: throw DrillShareError.notAvailable // K47 not deployed yet
            case 409:
                struct Progress: Decodable { var ready: Int?; var total: Int? }
                let progress = try? JSONDecoder().decode(Progress.self, from: data)
                throw DrillShareError.audioNotReady(ready: progress?.ready ?? 0, total: progress?.total ?? 0)
            default: throw DrillShareError.server("HTTP \(response.statusCode)")
            }
        } catch let error as DrillShareError {
            throw error
        } catch {
            throw .server(error.localizedDescription)
        }
    }
}

// MARK: - The mode

/// D142 (A79–A81): the repetition mode for the screens. Exams, making them (K45), their sound (K46), the AirPods
/// check (R11), Starta prov and sharing (K47).
@MainActor
@Observable
final class RepetitionModel {
    let store: DrillStore
    let session: RepetitionSession
    let maker: any DrillMaking
    let audio: any DrillAudioProviding
    let sharing: any DrillSharing
    let remote: RemoteCommandHub
    /// Ends a listening mode before the repetition takes the audio and the AirPods buttons.
    @ObservationIgnored var stopListening: (@MainActor () async -> Void)?

    /// The playing screen is up.
    var showsPlayer = false
    /// "Fortsätt där du var?" after iOS closed the app (R8).
    var resumeOffer: ResumeOffer?
    /// A share link opened in the app: the exam to add.
    var incomingCode: String?
    var importMessage: String?

    struct ResumeOffer: Identifiable, Equatable {
        var id: UUID { drill.id }
        let drill: Drill
        let index: Int
    }

    init(store: DrillStore, session: RepetitionSession, maker: any DrillMaking, audio: any DrillAudioProviding,
         sharing: any DrillSharing, remote: RemoteCommandHub) {
        self.store = store
        self.session = session
        self.maker = maker
        self.audio = audio
        self.sharing = sharing
        self.remote = remote
    }

    var drills: [Drill] { store.drills }

    // MARK: Making (A79)

    func make(_ material: DrillMaterial, settings: DrillSettings, correction: String? = nil,
              subject: String? = nil, grade: String? = nil) async throws(DrillMakingError) -> DrillDraft {
        try await maker.make(material, subject: subject, grade: grade, correction: correction,
                             questions: settings.questions, longWords: settings.length.words)
    }

    /// Saves and starts the sound in the background (D143: when the exam is saved).
    @discardableResult
    func save(_ drill: Drill) -> Drill {
        var drill = drill
        drill.items = drill.items.map { item in
            var item = item
            item.long = DrillItem.long(item.long, startingWith: item.short) // D145
            return item
        }
        store.save(drill)
        prepareAudio(drill)
        return drill
    }

    func delete(_ drill: Drill) {
        if session.drill?.id == drill.id { end() }
        store.delete(drill.id)
    }

    func prepareAudio(_ drill: Drill) {
        let audio = self.audio
        Task { await audio.prepare(drill) }
    }

    /// The sound of every exam that is not ready, on opening.
    func prepareAllAudio() {
        for drill in store.drills where audio.tracks(for: drill) == nil { prepareAudio(drill) }
    }

    func progress(_ drill: Drill) -> (ready: Int, total: Int) { audio.progress(for: drill) }

    func isAudioReady(_ drill: Drill) -> Bool {
        let p = progress(drill)
        return p.total > 0 && p.ready == p.total
    }

    func newAnswer(for question: String, in drill: Drill) async throws(DrillMakingError) -> DrillItem {
        try await maker.answer(question, summary: drill.summary, notes: drill.summary.covers, longWords: drill.longWords)
    }

    // MARK: Playing (A78, A80)

    func savedIndex(_ drill: Drill) -> Int? { session.savedIndex(for: drill) }

    func start(_ drill: Drill, at index: Int = 0) async {
        guard let tracks = audio.tracks(for: drill) else { return }
        await stopListening?()
        session.start(drill, tracks: tracks, at: index)
        showsPlayer = true
    }

    func end() {
        session.stop()
        showsPlayer = false
    }

    /// On opening: the last run's exam and question, if iOS closed the app while it played.
    func checkResume() {
        guard !session.isActive, resumeOffer == nil, let saved = RepetitionProgress.load(),
              let drill = store.drill(saved.drillID), saved.index > 0, saved.index < drill.items.count,
              Date().timeIntervalSince(saved.savedAt) < 24 * 3600 else { return }
        resumeOffer = ResumeOffer(drill: drill, index: saved.index)
    }

    // MARK: Sharing (A81)

    func shareLink(_ drill: Drill) async throws(DrillShareError) -> URL {
        let p = progress(drill)
        guard p.total > 0, p.ready == p.total else { throw .audioNotReady(ready: p.ready, total: p.total) }
        return try await sharing.link(for: drill)
    }

    func handle(_ url: URL) -> Bool {
        guard let code = DrillShareClient.code(in: url) else { return false }
        incomingCode = code
        Task { await importIncoming() }
        return true
    }

    private func importIncoming() async {
        guard let code = incomingCode else { return }
        incomingCode = nil
        do throws(DrillShareError) {
            let drill = try await sharing.importDrill(code: code)
            save(drill)
            importMessage = "\(drill.title) är tillagt."
        } catch {
            importMessage = error == .notAvailable ? "Delade prov går inte att öppna än." : "Provet gick inte att öppna."
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
    /// What arrived, for the log ("2 tryck → play").
    private(set) var heard: [String] = []

    private let hub: RemoteCommandHub
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var player: AVAudioPlayer?
    private let waitSeconds: Double
    private let activatesAudio: Bool

    init(hub: RemoteCommandHub, waitSeconds: Double = 10, activatesAudio: Bool = true) {
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
        if step == nil { timeout?.cancel() } else { armTimeout() }
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
