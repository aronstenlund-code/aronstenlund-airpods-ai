import AVFAudio
import Foundation
import MediaPlayer
import Observation
import UIKit

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
    /// A92 (D166, K57): "Fråga om EarMind". Nil: the row and the ? button are not shown.
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
        self.practice = PracticeTracker(defaults: defaults)
        watchNetwork()
        wirePractice()
    }

    /// A103 (Angela Fable A104): no network now, observed, so the views say it before the user tries and grey only
    /// what needs it (Skapa frågor, Dela, Publicera, Prov från din skola). Downloaded exams play without it.
    private(set) var isOffline = !NetworkStatus.shared.isOnline

    #if DEBUG
    /// Screenshots (A104): the offline rows without turning the network off.
    func stageOffline(_ offline: Bool) { isOffline = offline; isOfflineStaged = offline }
    /// The staged state stays when the Simulator's own network reports in (the pictures showed no offline row).
    private var isOfflineStaged = false
    #endif

    private func watchNetwork() {
        Task { [weak self] in
            for await online in NetworkStatus.shared.changes() {
                guard let self else { return }
                #if DEBUG
                if self.isOfflineStaged { continue }
                #endif
                let cameBack = online && self.isOffline
                self.isOffline = !online
                if cameBack { await self.refresh() } // the sound that was waiting goes on
            }
        }
    }

    var drills: [Drill] { store.drills }

    /// A132 (D215, Aron's screenshot 13:48): the exams on Start. A text from "Säg i AirPods" is not one of them.
    var examDrills: [Drill] { store.drills.filter { !$0.isSaid } }
    /// A132: the texts from "Säg i AirPods", for "Senaste" under the field.
    var saidDrills: [Drill] { store.drills.filter(\.isSaid) }
    /// A132: the said text that is exactly this text (the same lines), if there is one. The same text is never saved
    /// twice, also when it was put back from "Senaste".
    func saidDrill(for text: String) -> Drill? {
        // The server cleans the blanks in each line (K90), so the words decide.
        let plain: (String) -> String = { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let parts = SaidText.parts(text).map(plain)
        guard !parts.isEmpty else { return nil }
        return saidDrills.first { $0.items.map { plain($0.long) } == parts }
    }

    // MARK: Making (A79)

    func make(_ material: DrillMaterial, settings: DrillSettings, correction: String? = nil,
              subject: String? = nil, grade: String? = nil) async throws(DrillMakingError) -> DrillDraft {
        try await maker.make(material, subject: subject, grade: grade, correction: correction,
                             questions: settings.questions, longWords: settings.length.words)
    }

    /// A105 (D185, K70): Läs upp texten: the material cleaned for reading aloud. Nothing is stored or counted until
    /// `save(draft.drill)`.
    func readText(_ material: DrillMaterial, subject: String? = nil, grade: String? = nil,
                  title: String? = nil) async throws(DrillMakingError) -> DrillTextDraft {
        try await maker.readText(material, subject: subject, grade: grade, title: title)
    }

    /// Saves on the phone at once, then on the server, which starts the sound in the background (D143: when the exam
    /// is saved). Items whose texts changed lose their old sound; the others keep it.
    @discardableResult
    func save(_ drill: Drill) -> Drill {
        var drill = drill
        let before = store.drill(drill.id)
        drill.items = drill.items.map { item in
            var item = item
            if item.part == nil { item.long = DrillItem.long(item.long, startingWith: item.short) } // D145
            if let old = before?.items.first(where: { $0.id == item.id }), !old.sameText(as: item) {
                item.questionAudio = old.question == item.question ? old.questionAudio : nil
                item.longAudio = nil
                item.shortEndMs = nil
                // A105: a changed text part is split and timed again by the server.
                item.sentenceTimesMs = nil
                if item.part != nil { item.sentences = nil }
            }
            return item
        }
        drill.questionCount = drill.items.count
        if cloud != nil { drill.needsUpload = true }
        // Toby (moln) T24, 2026-11-15: an exam that has never been on the server and has no sound has asked for none
        // (every save defers it, K71), also before the server's first answer. Until then the card said
        // "Ljud: 0 av 6 klara" for a moment instead of "Ljudet görs när du startar". The server's answer decides after.
        if cloud != nil, drill.serverID == nil, before?.serverID == nil, drill.audioStarted == nil,
           drill.items.allSatisfy({ $0.questionAudio == nil && $0.longAudio == nil }) {
            drill.audioStarted = false
        }
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
        Task {
            let before = (audio as? CloudDrillAudio)?.refunds
            await audio.prepare(drill)
            // A112 (K78, D200): questions counted for sound that was never made came back.
            if let before, (audio as? CloudDrillAudio)?.refunds != before { await refreshQuota() }
        }
    }

    /// A112 (D200): the voice service is out, so this exam is text for now ("Uppläsningen är tillfälligt avstängd.
    /// Texten fungerar som vanligt."). Not an error: nothing is counted and the sound comes when the credits are back.
    func isReadingAloudOff(_ drill: Drill) -> Bool { audio.problem(for: drill) == CloudDrillAudio.unavailableLine }

    /// Aron's phone 2026-11-17: the sound did not come and the player said "Ingen kontakt med EarMind just nu" with
    /// a pause button, as if something played. Whatever the reason the sound is not coming (the voice service is out,
    /// no contact, no network), the player that waits for it is stepped by hand and offers nothing to pause.
    func soundIsNotComing(_ drill: Drill) -> Bool { Self.soundIsNotComing(problem: audio.problem(for: drill)) }
    nonisolated static func soundIsNotComing(problem: String?) -> Bool { !(problem ?? "").isEmpty }

    /// On opening: the exams of this account on the server (R5: another phone), then the sound of every exam that is
    /// not ready.
    func refresh() async {
        if let cloud {
            do throws(DrillCloudError) {
                let remote = try await cloud.list()
                // A131 (D213): the list's quota is taken unless it would turn the month back from credits to
                // questions (a reply in the older form); `/drill quota` decides then.
                if let client = cloud as? DrillCloudClient, let latest = client.lastQuota,
                   latest.isCredits || quota?.isCredits != true { quota = latest }
                let ids = Set(remote.map(\.id))
                let account = await cloud.accountID()
                for entry in remote where !store.drills.contains(where: { $0.serverID == entry.id }) {
                    if let view = try? await cloud.status(id: entry.id) {
                        // Toby T27/T31: the save's reply may have come while we waited.
                        guard !store.drills.contains(where: { $0.serverID == entry.id }) else { continue }
                        var drill = Drill.from(view)
                        if var twin = Self.unsavedTwin(of: drill, in: store.drills) {
                            // The phone's own exam, saved on the server before its reply came back (a ChatGPT import
                            // left after ~3 s, or the app closed meanwhile): the same exam, not another phone's.
                            twin.serverID = entry.id
                            twin.ownerID = account
                            twin.needsUpload = true // sent again with the id: an update, never a second exam
                            store.save(twin)
                            continue
                        }
                        drill.ownerID = account
                        store.save(drill)
                    }
                }
                for decision in Self.listDecisions(store.drills, listed: ids, account: account) {
                    switch decision {
                    case .stamp(let id):
                        if var drill = store.drill(id) { drill.ownerID = account; store.save(drill) }
                    case .delete(let id):
                        store.delete(id) // deleted on another phone of the same account
                    case .keepOtherAccount(let id):
                        Log.repetition.error("Drill \(id.uuidString, privacy: .public) is not in this account's list: another or a new account (T24); kept on the phone")
                    }
                }
            } catch {
                Log.repetition.info("Drill list: \(error.userMessage, privacy: .public)")
            }
        }
        askForMissingSound()
        await reschedulePracticeReminders() // A108: the week ahead, today only if not practised
    }

    /// The sound of every exam that is not ready, and the exams with changes to send. Safe to call again: an exam that
    /// is already being followed is left alone.
    private func askForMissingSound() {
        for drill in store.drills where !audio.hasAllSound(drill) || drill.needsUpload == true { prepareAudio(drill) }
    }

    /// Aron's phone 2026-11-17 (Kevin's K87, point 4): the card said "Ljud: 0 av 30 klara" while the server had had
    /// all 30 files for minutes. The sound was asked for when Start appeared and when the network came back; once
    /// that had ended (the voice service was out, a file failed, 20 minutes had passed) nothing asked again while the
    /// app stayed open, so the counter stood still until a restart. Coming back to the app asks again.
    func appBecameActive() {
        askForMissingSound()
    }

    @ObservationIgnored private var foregroundObserver: (any NSObjectProtocol)?

    /// The app's own start (`AppContainer`): from now on, coming back to the app asks for the sound that is missing.
    func watchForeground() {
        guard foregroundObserver == nil else { return }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                    object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.appBecameActive() }
        }
    }

    /// Toby T27/T31: the phone's exam that the server already has but the phone does not know it has (no server id
    /// yet): the same kind, and the same questions and answers in the same order.
    nonisolated static func unsavedTwin(of remote: Drill, in drills: [Drill]) -> Drill? {
        drills.first { local in
            local.serverID == nil && local.isText == remote.isText && local.items.count == remote.items.count
                && !local.items.isEmpty && zip(local.items, remote.items).allSatisfy { mine, theirs in
                    // The server cleans whitespace; the words decide.
                    plain(mine.question) == plain(theirs.question) && plain(mine.long) == plain(theirs.long)
                }
        }
    }

    nonisolated private static func plain(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    enum ListDecision: Equatable { case stamp(UUID), delete(UUID), keepOtherAccount(UUID) }

    /// Toby 2 T24 (lost exams after an account change): what the server's list means for each exam here.
    /// - In the list: it is this account's (stamped with the account).
    /// - Not in the list, with this account as its owner and nothing unsent: deleted on another phone, gone here too.
    /// - Not in the list otherwise (another account, a new anonymous user, an exam from before the owner was kept, or
    ///   the account unknown): kept. Never deleted because the account changed.
    nonisolated static func listDecisions(_ drills: [Drill], listed: Set<String>, account: String?) -> [ListDecision] {
        drills.compactMap { drill in
            guard let serverID = drill.serverID else { return nil }
            if listed.contains(serverID) {
                return drill.ownerID == account || account == nil ? nil : .stamp(drill.id)
            }
            guard drill.needsUpload != true else { return nil }
            if let account, drill.ownerID == account { return .delete(drill.id) }
            return .keepOtherAccount(drill.id)
        }
    }

    func prepareAllAudio() {
        Task { await refresh() }
    }

    func progress(_ drill: Drill) -> (ready: Int, total: Int) { audio.progress(for: drill) }

    func isAudioReady(_ drill: Drill) -> Bool {
        let p = progress(drill)
        return p.total > 0 && p.ready == p.total
    }

    // MARK: Streak och påminnelse (A108, D194)

    /// A108: the practised days and the streak ("3 dagar i rad"); observed, so the views follow it.
    let practice: PracticeTracker

    /// A108 (D194): the first exam was played through and iOS has not been asked yet: the moment for the app's own
    /// short question about a reminder (Angela Fable's A109), never at the first start. Answer with
    /// `allowPracticeReminders()` or `declinePracticeReminders()`.
    var asksForReminders = false
    static let reminderAskedKey = "reminders.practice.asked"
    /// A108: iOS's notifications (`LivePracticeReminders`); set by the app, nil in tests and the mock mode.
    @ObservationIgnored var reminders: (any PracticeReminding)?

    private func wirePractice() {
        session.onQuestionPlayed = { [weak self] id in self?.practice.questionPlayed(in: id) }
        session.onReadSeconds = { [weak self] id, seconds in self?.practice.read(seconds: seconds, in: id) }
        session.onFinished = { [weak self] _ in self?.examFinished() }
        practice.onDayDone = { [weak self] in self?.reminders?.cancelToday() } // D194: only on days not practised
    }

    private func examFinished() {
        practice.examFinished()
        guard !defaults.bool(forKey: Self.reminderAskedKey), let reminders, reminders.isOn else { return }
        Task {
            if await reminders.notAskedYet() { asksForReminders = true }
        }
    }

    /// A109's "Ja": iOS's own question now, then the reminders.
    func allowPracticeReminders() async {
        defaults.set(true, forKey: Self.reminderAskedKey)
        asksForReminders = false
        await reschedulePracticeReminders(ask: true)
    }

    /// A109's "Inte nu": not asked again by itself; Inställningar can turn reminders on later.
    func declinePracticeReminders() {
        defaults.set(true, forKey: Self.reminderAskedKey)
        asksForReminders = false
    }

    /// A108: the reminders for the coming week, at the chosen time, for the latest exam. Called at every open, after
    /// a change in Inställningar, and after the app's question. Never asks iOS unless `ask`.
    func reschedulePracticeReminders(ask: Bool = false) async {
        guard let reminders else { return }
        // D215 (A132): a text said in "Säg i AirPods" is no exam, so the reminder never names or opens one. When the
        // last thing practised was such a text, or nothing is practised yet, the reminder is for the newest exam
        // (the list is newest first; before, the fallback took the oldest one).
        let practised = practice.lastDrillID.flatMap { store.drill($0) }.flatMap { $0.isSaid ? nil : $0 }
        let latest = practised ?? examDrills.first
        await reminders.schedule(drillID: latest?.id, examTitle: latest?.title, doneToday: practice.practisedToday, ask: ask)
    }

    // MARK: Ljud vid Starta prov (A107, D190, K71)

    /// A107: the exam's sound is not asked for yet. Starta prov asks for it (`startAudio`), then plays as the sound
    /// comes. Saving and editing until then cost nothing.
    func awaitsAudioStart(_ drill: Drill) -> Bool { (store.drill(drill.id) ?? drill).awaitsAudioStart }

    /// A107: Starta prov is asking the server for the sound now ("Gör ljudet …"); then `progress` counts the files.
    func isStartingAudio(_ drill: Drill) -> Bool { audio.isStarting(drill) }

    /// A107 (D190): asks for the exam's sound (the month's quota is counted now) without playing. False when it could
    /// not start; `audio.problem(for:)` says why (no network, the month used up).
    @discardableResult
    func startAudio(_ drill: Drill) async -> Bool {
        guard awaitsAudioStart(drill) else { return true }
        let started = await audio.startAudio(store.drill(drill.id) ?? drill)
        await refreshQuota()
        return started
    }

    /// Kelly Ke49: Starta prov works as soon as the first question has its sound; the player waits for the rest.
    /// A107: an exam whose sound is not asked for yet can always be started (Starta prov asks for it).
    func canStart(_ drill: Drill) -> Bool {
        if awaitsAudioStart(drill) { return true }
        if drill.isText { return audio.reading(for: drill, part: 0) != nil } // A105
        return audio.track(for: drill, at: 0) != nil
    }

    func newAnswer(for question: String, in drill: Drill) async throws(DrillMakingError) -> DrillItem {
        try await maker.answer(question, summary: drill.summary, notes: drill.summary.covers, longWords: drill.longWords)
    }

    // MARK: Playing (A78, A80)

    func savedIndex(_ drill: Drill) -> Int? { session.savedIndex(for: drill) }

    func start(_ drill: Drill, at index: Int = 0) async {
        // A107 (D190): Starta prov asks for the sound first; the player then waits for each question's sound.
        if awaitsAudioStart(drill) {
            guard await startAudio(drill) else {
                // A112b (D200, Kelly U1): the voice service is out. Starta prov still opens the exam: the questions
                // and answers (or the text) are read on the screen and stepped through by hand. Nothing is counted.
                if let latest = store.drill(drill.id), isReadingAloudOff(latest) { await showAsText(latest, at: index) }
                return
            }
            let started = store.drill(drill.id) ?? drill
            if started.isText { await read(started, at: index, waitingForSound: true) } else {
                await play(started, at: index)
            }
            return
        }
        if isReadingAloudOff(drill), !canStart(drill) { await showAsText(drill, at: index); return } // A112b
        if drill.isText { await read(drill, at: index); return }
        guard !drill.items.isEmpty, canStart(drill) || audio.track(for: drill, at: index) != nil else { return }
        await play(drill, at: index)
    }

    /// A112b (D200): the player without sound. It waits for a sound that is not coming, shows the question with its
    /// answer (or the text), and the screen's buttons step by hand.
    private func showAsText(_ drill: Drill, at index: Int) async {
        if drill.isText { await read(drill, at: index, waitingForSound: true) } else { await play(drill, at: index) }
    }

    /// The questions' player, whether the first question has its sound yet or not (it waits in silence, Ke49).
    private func play(_ drill: Drill, at index: Int) async {
        guard !drill.items.isEmpty else { return }
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

    // MARK: Läsläget (A105, D185)

    /// A105 (Ke63 §5): the sentence a text was left at ("Fortsätt"), nil for the start.
    func savedSentence(_ drill: Drill) -> Int? { session.savedSentence(for: drill) }

    /// A105 (D185): reads a text aloud from `sentence` (counted through the whole text). Plays without network once
    /// the sound is downloaded (A103); a part whose sound has not come is waited for. Starts when the sound of the
    /// part it starts in is here.
    func read(_ drill: Drill, at sentence: Int = 0, waitingForSound: Bool = false) async {
        guard drill.isText, !drill.items.isEmpty else { return }
        let startPart = Self.part(of: sentence, in: drill)
        guard waitingForSound || audio.reading(for: drill, part: startPart) != nil || canStart(drill) else { return }
        await stopListening?()
        let audio = self.audio
        let store = self.store
        let id = drill.id
        if let publishing, drill.fromPublication != nil, let serverID = drill.serverID {
            Task { await publishing.played(drillID: serverID) }
        }
        let saying = sayOptions
        sayOptions = nil
        session.startReading(drill, at: sentence, tempo: tempo, saying: saying) { part in
            audio.reading(for: store.drill(id) ?? drill, part: part)
        }
        // A132 (D215.6, Kelly Ke72): a text from "Säg i AirPods" plays on its card on Start ("Spelar i AirPods", the
        // time left, pause and Stoppa); a tap on the text opens the player with the sentences. Without sound (D200)
        // the player opens as before, since the text is then read on the screen.
        showsPlayer = saying == nil || isReadingAloudOff(drill)
    }

    // MARK: Säg i AirPods (A115, D203)

    /// A130: the text that was last given to "Säg i AirPods" and its exam. Kept here, not in the view: the field is
    /// rebuilt when Start changes, and it must not forget what it has already saved.
    private(set) var lastSaid: (text: String, drillID: UUID)?

    /// A130 (D212): a Spela that did not open the player is never silent. The server's own words when it refused
    /// (the month's questions, K64), with when they are filled up; else the sound's problem, else a plain line.
    func sayRefusal(_ drill: Drill) -> String? {
        guard !showsPlayer, !isSayingOnCard else { return nil }
        let latest = store.drill(drill.id) ?? drill
        return SaidText.refusalLine(problem: audio.problem(for: latest), quotaExceeded: quotaExceeded(latest),
                                    refill: quota?.isCredits == true ? nil : Self.refillLine(quota?.resets))
    }

    /// "Fylls på den 1 december." from the server's "2026-12-01".
    nonisolated static func refillLine(_ resets: String?) -> String? {
        let parts = (resets ?? "").split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "sv_SE")
        return "Fylls på den \(parts[2]) \(calendar.monthSymbols[parts[1] - 1])."
    }

    /// A132 (D215.8, K92): what Spela would cost for this text, asked of the server without saving anything. A text
    /// that is already an exam is asked about as that exam, so sound that exists costs nothing. Nil when the server
    /// cannot be asked; the app then says nothing about the cost, and the server answers at Spela.
    func sayCost(_ text: String) async -> DrillCost? {
        guard let cloud else { return nil }
        let parts = SaidText.parts(text)
        guard !parts.isEmpty else { return nil }
        let drill = saidDrill(for: text)
            ?? Drill.text(title: SaidText.title(text), summary: DrillSummary(subject: "", grade: "", covers: ""),
                          parts: parts.map { DrillItem.textPart($0, part: .para) })
        return try? await cloud.cost(drill)
    }

    /// A132 (D215.6): a text from "Säg i AirPods" is being read (or waits for its sound) and has not reached its end.
    var isSayingOnCard: Bool {
        guard session.saying != nil, let reader = session.reader else { return false }
        return !reader.isAtEnd
    }

    /// A132 (D215.1, Ke72): the field on Start has a text that can be played, or plays one. Then Spela is the one
    /// filled button and Starta prov is toned down. Set by the field.
    var sayHoldsTheStage = false

    /// How the next text is read (set by `say`, used once by `read`).
    @ObservationIgnored private var sayOptions: RepetitionSession.SayOptions?

    /// A115 (D203): the free text on Start. Saved as a text read aloud exactly as written (one part per paragraph),
    /// then started like any text: Starta prov asks for the sound, the month's questions are counted per started 800
    /// characters (D185), and repeating the same sound costs nothing. Without credits the text is shown and nothing is
    /// counted (D200). Always with the player on the screen; nothing is scheduled and nothing plays hidden.
    @discardableResult
    func say(_ text: String, repeatMinutes: Int?) async -> Drill? {
        let parts = SaidText.parts(text)
        guard !parts.isEmpty else { return nil }
        // A130 (D212, Aron's phone 2026-11-17 13:48): the server refused the text (402) and every press on Spela made
        // one more unstarted exam. The same text is the same exam: it is started again, never saved again.
        if let same = saidDrill(for: text) ?? lastSaid.flatMap({ $0.text == text ? store.drill($0.drillID) : nil }) {
            await sayAgain(same, repeatMinutes: repeatMinutes)
            return store.drill(same.id) ?? same
        }
        var made = Drill.text(title: SaidText.title(text), summary: DrillSummary(subject: "", grade: "", covers: ""),
                              parts: parts.map { DrillItem.textPart($0, part: .para) })
        made.audioStarted = false // nothing is asked for or counted until it is started, just below
        made.said = true // A132 (D215): kept as "Senaste" under the field, never as an exam on Start
        let drill = save(made)
        lastSaid = (text, drill.id)
        sayOptions = RepetitionSession.SayOptions(repeatMinutes: repeatMinutes)
        await start(drill)
        sayOptions = nil
        // A131 (D212 point 3, K90): the credits did not cover it, so the server saved nothing. The phone keeps nothing
        // either: no card on Start for a text that was refused. The text is still in the field, and why is said there.
        if !showsPlayer, !isSayingOnCard, quotaExceeded(drill), let refused = store.drill(drill.id), refused.serverID == nil {
            store.delete(refused.id)
            lastSaid = nil
            return refused
        }
        return store.drill(drill.id) ?? drill
    }

    /// A115: Spela on the same text again: the sound that is already made, from the beginning. Costs nothing.
    func sayAgain(_ drill: Drill, repeatMinutes: Int?) async {
        sayOptions = RepetitionSession.SayOptions(repeatMinutes: repeatMinutes)
        await start(store.drill(drill.id) ?? drill, at: 0)
        sayOptions = nil
    }

    /// The part sentence number `sentence` is in.
    static func part(of sentence: Int, in drill: Drill) -> Int {
        var left = max(sentence, 0)
        for (i, item) in drill.items.enumerated() {
            let n = item.readingSentences.count
            if left < n { return i }
            left -= n
        }
        return max(drill.items.count - 1, 0)
    }

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
        // D175: at most what is left of the month's questions (never more than 20).
        if let quota, !quota.isUsedUp { settings.questions = max(1, quota.suggestedQuestions) }
        return settings
    }

    /// D175: Antal frågor goes up to what is left this month (the server never makes more).
    var newDrillQuestionRange: ClosedRange<Int> {
        guard let quota, !quota.isUsedUp else { return DrillSettings.questionRange }
        return 1...max(1, min(DrillSettings.questionRange.upperBound, quota.left))
    }

    /// D175: nothing left this month, shown in Nytt prov before Skapa frågor (the server's words, K61).
    var quotaUsedUp: Bool { quota?.isUsedUp ?? false }
    static let quotaUsedUpLine = "Du har inga frågor kvar den här månaden. Andras prov är gratis."

    /// K61: the month's questions now (Nytt prov on opening, and after an exam is saved).
    func refreshQuota() async {
        guard let client = cloud as? DrillCloudClient else { return }
        do throws(DrillCloudError) {
            quota = try await client.quota()
        } catch {
            Log.repetition.info("Drill quota: \(error.userMessage, privacy: .public)")
        }
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
    /// D155, K61: "x av 15 frågor kvar den här månaden", from `/drill quota` (and the last `list`). Observed, so Nytt
    /// prov follows it.
    var quota: DrillQuota?

    /// Toby 2 T24 L4: the month's questions are known (Nytt prov showed 20 and then jumped to 15). Until then the
    /// view shows no number, or a grey one. Always known in the mock mode, which has no limit.
    var quotaIsKnown: Bool { quota != nil || cloud == nil }

    func quotaExceeded(_ drill: Drill) -> Bool {
        #if DEBUG
        if stagedQuotaExceeded.contains(drill.id) { return true }
        #endif
        return (audio as? CloudDrillAudio)?.quotaExceeded.contains(drill.id) ?? false
    }

    #if DEBUG
    /// Screenshots (A104): an exam the month's questions ran out for.
    @ObservationIgnored var stagedQuotaExceeded: Set<UUID> = []
    #endif

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
        let view: DrillPublicationView
        do throws(DrillCloudError) {
            view = try await publishing.publish(drillID: id, school: school, subject: subject, examDate: examDate,
                                                displayName: displayName)
        } catch {
            // A107 (D191): publishing an exam never started starts its sound on the server; follow it here.
            if case .refused(_, let code, _) = error, code == "audio_not_ready", var latest = store.drill(drill.id),
               latest.awaitsAudioStart {
                latest.audioStarted = nil
                store.save(latest)
                prepareAudio(latest)
            }
            throw error
        }
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
        // A107 (D191): an exam never started gets its sound first; it is shared when the sound is done.
        if awaitsAudioStart(drill) { await startAudio(drill) }
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
