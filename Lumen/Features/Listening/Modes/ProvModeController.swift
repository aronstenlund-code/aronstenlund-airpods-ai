import Foundation
import Observation

/// D199 step 6c (A126): what the mini test uses of `ListeningModel`: the model's own calls, unchanged.
@MainActor
protocol MiniTestHost: ListeningModeHost {
    func say(_ line: String)
    /// A38 (K31): a quiz answer today, for the streak.
    func noteQuizAnswer(at date: Date)
    /// D83: the tutor's persona (the profile, the exam, the last turns), for the grading call.
    func tutorPersona() -> PersonaRequest?
    /// Right or wrong on the card itself.
    func markStudyCard(_ id: UUID, right: Bool)
    /// A43 (K33): the mini test's answers count in the study plan too, like the flip cards.
    func recordInStudyPlan(_ card: StudyCard, right: Bool)
}

/// D81 (A126, D199 step 6c): the mini test inside Provläge, five questions by voice on the last session's study cards.
/// Moved unchanged out of `ListeningModel`: Lumen asks a card's question, the student answers aloud, the tutor grades
/// through the ordinary answer pipeline, and the next card follows. The model still picks the cards and starts
/// Provläge before the test begins.
@MainActor
@Observable
final class MiniTestController {
    @ObservationIgnored weak var host: (any MiniTestHost)?
    /// The running mini test. Nil: none.
    private(set) var test: MiniTest?
    /// The card whose answer the tutor is judging.
    @ObservationIgnored private var gradingCardID: UUID?

    var isActive: Bool { test != nil }

    func begin(cards: [StudyCard]) {
        test = MiniTest(cards: cards)
        gradingCardID = nil
        host?.modeLog("Mini test started (\(cards.count) cards)")
        askQuestion()
    }

    /// Another exercise takes over (the exam session, the practice exam): the test goes without a summary, as before.
    func drop() {
        test = nil
    }

    /// Provläge ended. True: a mini test was running and is gone now.
    func endWithSession() -> Bool {
        guard test != nil else { return false }
        test = nil
        gradingCardID = nil
        return true
    }

    private func askQuestion() {
        guard let host, let current = test else { return }
        if let question = current.question(swedish: host.language == .swedish) {
            host.say(question)
            return
        }
        host.say(current.summary(swedish: host.language == .swedish))
        host.modeLog("Mini test done: \(current.rightCount) of \(current.cards.count)")
        test = nil
    }

    /// The student's answer to the card's question: skipped, or sent to the tutor to grade.
    func turn(_ text: String) {
        guard let host, var current = test, let card = current.current else { return }
        if MiniTest.isSkip(text) {
            current.skip()
            host.markStudyCard(card.id, right: false)
            test = current
            host.study.resumeListening()
            askQuestion()
            return
        }
        guard let query = current.gradingQuery(for: text, swedish: host.language == .swedish) else { return }
        gradingCardID = card.id
        host.activated(ActivationRequest(query: query, trigger: .tutor, language: host.language), persona: host.tutorPersona())
    }

    /// An answer from the tutor arrived. True: it was the verdict on the card being graded, so it is no study card
    /// of its own; the next question follows.
    func graded(by answer: String) -> Bool {
        guard let host, let id = gradingCardID, var current = test else { return false }
        gradingCardID = nil
        current.graded(answer)
        let right = current.results[id] ?? false
        host.markStudyCard(id, right: right)
        host.noteQuizAnswer(at: Date()) // A38
        if let card = current.cards.first(where: { $0.id == id }) { host.recordInStudyPlan(card, right: right) } // A43
        test = current
        askQuestion()
        return true
    }
}

/// D199 step 6d (A127): what the silent quiz uses of `ListeningModel`: the model's own calls, unchanged. The head
/// tracking (`HeadMotionListener`) is the model's; the quiz only asks it to listen or to stop.
@MainActor
protocol SilentQuizHost: ListeningModeHost {
    var mode: ConversationMode { get }
    var conversation: Conversation { get }
    var headMotion: HeadMotionListener { get }
    func say(_ line: String)
    /// A38 (K31): a quiz answer today, for the streak.
    func noteQuizAnswer(at date: Date)
    /// D83: the tutor's persona, for the quiz's questions and the answers to them.
    func tutorPersona() -> PersonaRequest?
    /// A9.1: "förhör mig" was used, so it is never tipped.
    func markQuizUsed()
}

/// A20.2 (A127, D199 step 6d): the silent quiz inside Provläge. Moved unchanged out of `ListeningModel`: Lumen asks
/// yes-or-no questions, a nod answers "ja" and a shake "nej" (the voice works too), and after ten questions or two
/// missed answers in a row the result is said. The questions and the verdicts come through the ordinary answer
/// pipeline; after each of Lumen's lines the model tells the quiz that it has spoken (`afterSpeech`).
@MainActor
@Observable
final class SilentQuizController {
    @ObservationIgnored weak var host: (any SilentQuizHost)?
    /// The running quiz. Nil: not running.
    private(set) var quiz: SilentQuiz?
    /// How many answers the conversation had when the quiz last counted one.
    @ObservationIgnored private var seenAnswers = 0

    var isActive: Bool { quiz != nil }

    func start() {
        guard let host, host.study.isActive, host.mode == .prov, quiz == nil else { return }
        quiz = SilentQuiz()
        seenAnswers = host.conversation.answers.count
        host.modeLog("Silent quiz started (A20)")
        host.markQuizUsed()
        host.activated(ActivationRequest(query: SilentQuiz.questionRequest, trigger: .tutor, language: host.language),
                       persona: host.tutorPersona())
        // After `activated` (it interrupts speech): the start line plays before the first question arrives.
        host.say(SilentQuiz.startLine)
        if !host.headMotion.isAvailable { host.say(SilentQuiz.noHeadTrackingLine) }
    }

    func end(speak: Bool = true) {
        guard let ended = quiz else { return }
        quiz = nil
        host?.headMotion.stop()
        host?.modeLog("Silent quiz ended: \(ended.summary) (A20)")
        if speak { host?.say(ended.summary) }
    }

    /// A20.2: "ja" / "nej" by voice is the answer the quiz waits for; A38: it counts for the streak.
    func answeredByVoice() {
        guard quiz?.awaitingAnswer == true else { return }
        quiz?.answered()
        host?.noteQuizAnswer(at: Date())
    }

    /// After Lumen spoke in the quiz: count the new answer once, then wait for a nod or a shake.
    func afterSpeech() {
        guard let host, var current = quiz, host.study.isActive, host.mode == .prov else { return }
        let count = host.conversation.answers.count
        if count > seenAnswers, let answer = host.conversation.answers.last?.answer {
            seenAnswers = count
            current.lumenSaid(answer)
            quiz = current
        }
        if current.graded >= SilentQuiz.questions || current.isFinished {
            end()
            return
        }
        if current.awaitingAnswer { listenForAnswer() }
    }

    private func listenForAnswer() {
        guard let host, host.headMotion.isAvailable else { return } // the voice answers ("ja" / "nej")
        host.headMotion.listen(for: SilentQuiz.answerWindow) { [weak self] gesture in
            guard let self, let host = self.host, self.quiz?.awaitingAnswer == true else { return }
            self.quiz?.answered()
            host.noteQuizAnswer(at: Date()) // A38
            let text = gesture == .nod ? "Ja" : "Nej"
            host.modeLog("Silent quiz: \(gesture == .nod ? "nod" : "shake") → \(text) (A20)")
            host.activated(ActivationRequest(query: text, trigger: .tutor, language: host.language), persona: host.tutorPersona())
        }
        let asked = quiz?.asked
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(SilentQuiz.answerWindow + 0.3))
            guard let self, var current = self.quiz, current.awaitingAnswer, current.asked == asked else { return }
            current.missed()
            self.quiz = current
            if current.isFinished {
                self.end()
            } else {
                self.host?.say(SilentQuiz.nudgeLine)
            }
        }
    }
}

/// D199 step 6e (A128): what the study plan uses of `ListeningModel`: the model's own calls, unchanged. The history
/// of what was right and wrong, the quiz days and the streak (A38) are still the model's; the plan reads them here.
@MainActor
protocol StudyPlanHost: ListeningModeHost {
    var mode: ConversationMode { get }
    var isListening: Bool { get }
    var conversation: Conversation { get }
    var voiceIsSpeaking: Bool { get }
    var hasPendingSpeech: Bool { get }
    var examPlans: ExamPlanStore? { get }
    /// Kevin's `/study-plan`. Nil: no plan.
    var studyPlanClient: StudyPlanClient? { get }
    /// A38: the streak as the model last counted it.
    var streak: QuizDays.Streak { get }
    /// A38: the days with a quiz answer (yyyy-MM-dd).
    var quizDayList: [String] { get }
    /// An exam session, a practice exam or a mini test runs: no summary then.
    var examOrTestIsRunning: Bool { get }
    /// When the running Provläge session began.
    var provSessionStart: Date? { get }
    /// A38: the streak is counted again, and the widget follows (A44).
    func refreshStreak()
    /// A19 (K17): what came up for the exam, right or wrong, per concept.
    func planHistory(for examID: UUID) -> [String: [StudyHistory.Entry]]
    func updateWidget(now: Date)
    func say(_ line: String)
    func tutorPersona() -> PersonaRequest?
    /// A19.2: the summary is kept as a study card and, with the session, as a note.
    func saveSummary(_ answer: String)
    /// A19.3: the link is put on the answer and in Historik.
    func attach(_ link: LearningLink, to turn: AnswerTurn)
    /// Ends the mode and the microphone.
    func endSessionNow() async
}

/// A19 (A128, D199 step 6e): the study plan. Moved unchanged out of `ListeningModel`: today's plan per exam from
/// Kevin's `/study-plan` (K17) and the local reminders made of it (`LumenNotifications`, A38), the plan's question
/// when Provläge starts ("I går missade du … Ska vi ta dem nu?"), the summary at "avsluta" (A19.2: one last call
/// whose answer ends the session), and the link sent with an answer (A19.3, K19).
@MainActor
@Observable
final class StudyPlanController {
    @ObservationIgnored weak var host: (any StudyPlanHost)?
    /// A19: today's plan per exam, from `/study-plan`.
    private(set) var plans: [UUID: StudyPlanAPI.ExamPlanReply] = [:]
    @ObservationIgnored private var promptSaid: Set<String> = []
    /// A19: "Påminn mig om passen" on Start: iOS asks once, then the plan's days are reminders at 16:00.
    private(set) var canAskForReminders = false
    /// A19.2: the id of the session-end call ("avsluta" in Provläge): its answer is the summary.
    @ObservationIgnored private var summaryRequestID: UUID?
    @ObservationIgnored private var summaryTimeout: Task<Void, Never>?

    /// A19.2: the session's summary was asked for and has not ended the session yet.
    var isSummarizing: Bool { summaryRequestID != nil }

    /// A19.2: this call is the session-end call (`context.session_end`).
    func isSummary(_ request: ActivationRequest) -> Bool { request.id == summaryRequestID }

    // MARK: - Today's plan and the reminders

    /// Asks `/study-plan` for every upcoming exam: what is due today, and the days up to the exam (local reminders).
    func refresh(askForReminders: Bool = false) async {
        guard let host else { return }
        host.refreshStreak()
        #if DEBUG
        if ScreenshotStage.requested != nil { return } // A43: the staged plan, not the live one (the Simulator has network)
        #endif
        let upcoming = host.examPlans?.upcomingDated() ?? [] // D189: a plan needs a real date
        guard let studyPlanClient = host.studyPlanClient, !upcoming.isEmpty || !host.quizDayList.isEmpty else { return }
        let exams = upcoming.prefix(10).map { plan in
            StudyPlanAPI.ExamIn(name: plan.name, date: StudyHistory.day(plan.date),
                                concepts: StudyPlanAPI.concepts(history: host.planHistory(for: plan.id),
                                                                topics: StudyPlanAPI.topics(plan.topics)))
        }
        let request = StudyPlanAPI.Request(today: StudyHistory.day(Date()), exams: Array(exams), quiz_days: host.quizDayList)
        guard let reply = await studyPlanClient.plan(request) else {
            host.modeLog("Study plan: no reply")
            return
        }
        var byExam: [UUID: StudyPlanAPI.ExamPlanReply] = [:]
        var planDays: [String: [String]] = [:]
        for (plan, answer) in zip(upcoming.prefix(10), reply.exams) {
            byExam[plan.id] = answer
            for day in answer.plan where planDays[day.date] == nil && !day.concepts.isEmpty { planDays[day.date] = day.concepts }
        }
        plans = byExam
        host.updateWidget(now: Date()) // A44: the readiness too
        // A38: one reminder a day at the chosen time (K31's text today, a countdown on the other days).
        let daily = LumenNotifications.days(today: Date(), note: reply.notification, doneToday: host.streak.doneToday,
                                            exams: upcoming.map { (name: $0.name, date: $0.date) }, plan: planDays)
        host.modeLog("Study plan: \(byExam.count) exams, streak \(host.streak.current), \(daily.count) reminders")
        await LumenNotifications.scheduleDaily(daily, ask: askForReminders)
        let status = await LumenNotifications.status()
        canAskForReminders = !daily.isEmpty && LumenNotifications.remindersOn && status == .notDetermined
    }

    /// A43 (K33): how ready the student is for the exam, when the backend could count it.
    func readiness(for plan: ExamPlan) -> StudyPlanAPI.Readiness? {
        // Nothing practised yet: no ring (a new exam at "0 %" says nothing and discourages).
        guard let readiness = plans[plan.id]?.readiness, readiness.readyPct != nil, (readiness.practiced ?? 1) > 0 else { return nil }
        return readiness
    }

    /// "I dag: 10 min Biologi (cellandning, klorofyll)" when the plan has a pass today.
    func todayLine(for plan: ExamPlan) -> String? {
        let today = StudyHistory.day(Date())
        guard let day = plans[plan.id]?.plan.first(where: { $0.date == today }) else { return nil }
        return StudyPlanAPI.todayLine(subject: plan.subject, day: day)
    }

    /// A19 (K17): "I går missade du cellandning och mitos. Ska vi ta dem nu?", once a day per exam.
    func sayPrompt(for plan: ExamPlan) {
        guard let host, host.study.isActive, host.mode == .prov, let prompt = plans[plan.id]?.prompt, !prompt.isEmpty else { return }
        let key = plan.id.uuidString + StudyHistory.day(Date())
        guard !promptSaid.contains(key) else { return }
        promptSaid.insert(key)
        host.modeLog("Provläge: the study plan's question (A19)")
        host.say(prompt)
    }

    #if DEBUG
    /// A38/A43: the plan's reply for the Simulator screenshots (no network there).
    func stage(_ plan: ExamPlan, reply: StudyPlanAPI.ExamPlanReply) {
        plans[plan.id] = reply
    }
    #endif

    // MARK: - The summary at "avsluta" (A19.2)

    /// "avsluta" in Provläge after real questions: one last call says the summary, then Lumen stops.
    func summarizeBeforeEnding() -> Bool {
        guard let host, host.study.isActive, host.mode == .prov, host.isListening, !host.examOrTestIsRunning,
              summaryRequestID == nil, let start = host.provSessionStart,
              host.conversation.answers.filter({ $0.createdAt >= start && $0.isOwnQuestion && $0.interrupted != true }).count >= 2 else {
            return false
        }
        let request = ActivationRequest(query: "avsluta", trigger: .tutor, language: host.language)
        summaryRequestID = request.id
        host.modeLog("Provläge: the session's summary before ending (A19)")
        summaryTimeout?.cancel()
        summaryTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(45))
            guard !Task.isCancelled else { return }
            self?.endAfterSummary(reason: "no summary within 45 s")
        }
        host.activated(request, persona: host.tutorPersona())
        return true
    }

    /// The summary is spoken: kept as a study card and with the session in Anteckningar, then Provläge ends.
    func summaryArrived(_ turn: AnswerTurn) {
        summaryTimeout?.cancel()
        host?.saveSummary(turn.answer)
        host?.modeLog("Provläge: summary saved as a study card and a note (A19)")
        Task { [weak self] in
            for _ in 0..<1_200 {
                guard let self, let host = self.host, self.summaryRequestID != nil else { return }
                if !host.voiceIsSpeaking, !host.hasPendingSpeech { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            self?.endAfterSummary(reason: "summary spoken")
        }
    }

    func endAfterSummary(reason: String) {
        guard summaryRequestID != nil else { return }
        summaryRequestID = nil
        summaryTimeout?.cancel()
        host?.modeLog("Provläge ends: \(reason) (A19)")
        Task { [weak self] in await self?.host?.endSessionNow() }
    }

    /// "Avsluta" again while the summary is on its way: no summary, the session ends at once.
    func cancelSummary() {
        summaryRequestID = nil
        summaryTimeout?.cancel()
    }

    // MARK: - The link sent with an answer (A19.3, K19)

    /// The link is on the answer, in Historik, and a notification (the phone is in the pocket).
    func linkArrived(_ link: LearningLink, for turn: AnswerTurn) {
        host?.attach(link, to: turn)
        host?.modeLog("Link sent: \(link.sourceName) (A19)")
        Task { await LumenNotifications.sendLink(link) }
    }
}

/// D199 step 6c (A126): what Provläge's controller uses of `ListeningModel`, beside what its parts use.
@MainActor
protocol ProvModeHost: ExamSessionHost, PracticeExamHost, MiniTestHost, SilentQuizHost, StudyPlanHost {
    /// D83: Provläge's first-start answers (grade, subject, exam date, check questions, explanation length).
    var studyProfile: StudyProfileStore { get }
    /// D97: this pass only answers, it never quizzes.
    var provAnswersOnly: Bool { get }
    /// A8.4: the rest of a turn split into several questions goes to the queue Provläge shares with Frågor
    /// (`TurnQueue`).
    func queueTurns(_ parts: [String])
    /// What follows the name when it is not a command (D74).
    func instruct(_ text: String)
}

/// D36 (A126, D199 step 6c): Provläge behind `ListeningModeController`. It holds Provläge's parts that have left
/// `ListeningModel` (the exam session, the practice exam by voice, the mini test, the silent quiz, the study plan)
/// and the order a turn is offered to them in, which is the order the model had:
/// 1. the practice exam, before the filler filter ("ja" can be an answer, A16);
/// 2. the mini test;
/// 3. the exam session (nothing is answered, only "Lumen, …" counts);
/// 4. the ordinary turn to the tutor.
///
/// Since step 7a (A137, D221) the ordinary turn is here too: the question to the tutor, the tutor's persona, the
/// last turns sent with every call (D87) and the nod that answers a check question (D83). The queue of split turns
/// is `TurnQueue`, which Frågor shares. `StudySessionController` decides when a turn ends, as before.
@MainActor
final class ProvModeController: ListeningModeController {
    let mode: ConversationMode = .prov
    /// Set by the model right after its own init; weak, the model owns this controller.
    weak var host: (any ProvModeHost)? {
        didSet {
            exam.host = host
            practice.host = host
            miniTest.host = host
            silentQuiz.host = host
            studyPlan.host = host
        }
    }
    /// D84: the exam session with the uploaded practice exam (step 6a).
    let exam = ExamSessionController()
    /// A16: the practice exam by voice (step 6b).
    let practice = PracticeExamController()
    /// D81: the mini test (step 6c).
    let miniTest = MiniTestController()
    /// A20.2: the silent quiz, answered with a nod or a shake (step 6d). It is no part of the turn's order: its
    /// questions and answers are ordinary turns to the tutor.
    let silentQuiz = SilentQuizController()
    /// A19: the study plan (today's plan, the reminders, the summary at "avsluta", the links), step 6e. Start reads
    /// it too, outside a running Provläge.
    let studyPlan = StudyPlanController()

    /// A14: Provläge has the same short words as Frågor.
    var spokenKeyterms: [String] { StandardModeController.spokenKeyterms }

    func startBlock() -> ModeStartBlock? { nil }
    func startScreen() -> ModeStartBlock? { nil }

    /// Before the filler filter. True: the practice exam took the turn.
    func takesUnfiltered(_ text: String) -> Bool {
        guard practice.isActive else { return false }
        practice.turn(text)
        return true
    }

    /// A finished turn that is not a command or filler.
    func turn(_ text: String) {
        if miniTest.isActive {
            miniTest.turn(text)
            return
        }
        if exam.isActive {
            exam.turn(text)
            return
        }
        ordinaryTurn(text)
    }

    // MARK: - The ordinary turn to the tutor (step 7a)

    /// D87: the wearer's Provläge turns (answered or not), for `context.recent_turns`.
    private(set) var turns: [AnswerContext.Turn] = []

    /// D83: `persona: "tutor"` + `persona_setup` with the profile, on every Provläge call.
    func tutorPersona() -> PersonaRequest? {
        guard let host else { return nil }
        var profile = host.studyProfile.profile
        if host.provAnswersOnly { profile.checkQuestions = StudyProfile.CheckQuestions.none } // D97: never quiz
        return profile.setupText().map { PersonaRequest(persona: "tutor", setup: $0) }
    }

    /// Provläge's ordinary turn: a question to the tutor.
    private func ordinaryTurn(_ text: String) {
        guard let host else { return }
        host.headMotion.stop() // answered with the voice
        silentQuiz.answeredByVoice() // A20.2: "ja" / "nej" by voice; A38
        // A8.4: several questions in one breath are separate turns, each with its own answer.
        var parts = QuestionSplitter.split(text)
        let first = parts.isEmpty ? text : parts.removeFirst()
        if !parts.isEmpty { host.modeLog("\(host.mode.rawValue): one turn split into \(parts.count + 1) parts") }
        host.queueTurns(parts) // A21.1: turns heard while the last one was answered stay queued
        host.activated(ActivationRequest(query: first, trigger: .tutor, language: host.language), persona: tutorPersona())
        recordTurn(first)
    }

    /// D87: a Provläge turn; answered or not is filled in when the answer is complete.
    func recordTurn(_ text: String) {
        turns.append(AnswerContext.Turn(text: text, answered: false))
        if turns.count > 10 { turns.removeFirst(turns.count - 10) }
    }

    /// The last three turns before `query` (the turn being answered is the fragment, not a recent turn).
    func turnsBefore(_ query: String) -> [AnswerContext.Turn] {
        var before = turns
        if let last = before.last, AheadAnswer.key(last.text) == AheadAnswer.key(query) { before.removeLast() }
        return Array(before.suffix(AnswerContext.turnLimit))
    }

    /// The answer to `question` is complete.
    func turnAnswered(_ question: String) {
        guard let index = turns.lastIndex(where: { AheadAnswer.key($0.text) == AheadAnswer.key(question) }) else { return }
        turns[index].answered = true
    }

    /// Another exam is studied now: its turns are not this one's.
    func forgetTurns() {
        turns = []
    }

    /// D83: after a yes/no check question in Provläge, a nod or a shake answers it for 6 s. The voice works too.
    func listenForHeadAnswerIfAsked() {
        guard let host, host.study.isActive, host.mode == .prov, !silentQuiz.isActive,
              host.studyProfile.profile.checkQuestions == .yesNo,
              let answer = host.conversation.answers.last?.answer.trimmingCharacters(in: .whitespacesAndNewlines),
              answer.hasSuffix("?") else { return }
        guard host.headMotion.isAvailable else {
            host.modeLog("Head gestures: not supported by these AirPods, answer with the voice")
            return
        }
        host.headMotion.listen(for: 6) { [weak self] gesture in
            guard let self, let host = self.host, host.study.isActive, host.study.phase == .listening else { return }
            let text = gesture == .nod ? "Ja" : "Nej"
            host.modeLog("Head gesture: \(gesture == .nod ? "nod" : "shake") → \(text)")
            host.activated(ActivationRequest(query: text, trigger: .tutor, language: host.language), persona: self.tutorPersona())
        }
    }

    /// D80: in Provläge a turn is answered ahead only while it listens and no exercise runs.
    func aheadRequest(for text: String) -> (request: ActivationRequest, persona: PersonaRequest?)? {
        guard let host, host.study.isActive, host.study.phase == .listening,
              !exam.isActive, !practice.isActive, !miniTest.isActive else { return nil }
        return (ActivationRequest(query: text, trigger: .tutor, language: host.language), tutorPersona())
    }

    /// "Lumen, …" for a running exercise: the practice exam in Provläge ("Lumen, nästa"), then the exam session.
    /// True: it was taken.
    func takesInstruction(_ text: String, inProv: Bool) -> Bool {
        if practice.isActive, inProv {
            practice.instruction(text)
            return true
        }
        if exam.isActive {
            exam.instruction(text)
            return true
        }
        return false
    }

    /// "Lumen, …" in Provläge: the model's own path, which asks the exercises first.
    func instruction(_ text: String) {
        host?.instruct(text)
    }
}
