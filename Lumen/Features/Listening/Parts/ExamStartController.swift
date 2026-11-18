import Foundation
import Observation

/// D231 (A149, G7 step 7c): what the exam start uses of `ListeningModel`: the model's own state and calls, unchanged.
/// Starting and stopping the listening stay in the model; nothing here records, routes or plays audio.
@MainActor
protocol ExamStartHost: ListeningModeHost {
    var mode: ConversationMode { get }
    var selectedMode: ConversationMode { get set }
    var isListening: Bool { get }
    var canResume: Bool { get }
    var isActiveSession: Bool { get }
    var problem: LumenProblem? { get }
    var studyProfile: StudyProfileStore { get }
    var studyProfileClient: StudyProfileClient? { get }
    var examPlans: ExamPlanStore? { get }
    var memory: MemoryStore { get }
    var provMode: ProvModeController { get }
    /// The screens the start opens or closes.
    var isShowingAddExam: Bool { get set }
    var isShowingStudyOnboarding: Bool { get set }
    var showsListeningScreen: Bool { get set }
    func say(_ line: String)
    func refreshKeyterms()
    /// A44: the home screen widget shows the nearest exam.
    func updateWidget(now: Date)
    func startStudy() async
    func resume() async
    func startListening() async
    /// "Förhör mig", as said or pressed.
    func askForQuiz()
    /// A new pass through the exam's cards.
    func beginFreshPass()
    /// What was answered ahead is not for these words.
    func discardAhead(reason: String)
}

/// D72, D83–D86, A24, A33 (A149, D231, G7 step 7c): how Provläge is started and which exam it is about. Moved unchanged
/// out of `ListeningModel`: the Provläge card and "Har du prov snart?", the first-start answers, the profile and the
/// exam said by voice, the saved exams and the one being studied, the exam that is only an area ("NO") and its
/// subject, "Förhör mig" and "Få A-svar till provet". The turn's way to the modes stays in the model.
@MainActor
@Observable
final class ExamStartController {
    /// Set by the model right after its own init; weak, the model owns this part.
    @ObservationIgnored weak var host: (any ExamStartHost)?

    /// D87: the exam the Provläge turns belong to. The turns themselves are `provMode.turns` (G7 step 7a).
    private(set) var activeExamID: UUID?
    /// "Lägg till prov" → the microphone button: the next sentence is the exam, said aloud.
    private(set) var awaitingExamStatement = false

    /// The Provläge card on the main screen (D72): one tap, no setup in between.
    func startProvFromCard() async {
        guard let host else { return }
        host.selectedMode = .prov
        if !host.studyProfile.profile.onboarded {
            // Ke35 (Toby T8b finding 6): no five questions first. Defaults (Automatiskt), changed in Inställningar
            // or by voice ("kortare"); the subject is asked in the first quiz (A22).
            var profile = host.studyProfile.profile
            profile.onboarded = true
            host.studyProfile.profile = profile
        }
        if host.examPlans?.upcoming().isEmpty != false, !provAskedForExam {
            // Ke35: at most one question, and only without an exam: "Har du prov snart?". "Inte nu" starts anyway.
            provAskedForExam = true
            startsProvAfterExamStep = true
            host.isShowingAddExam = true
            return
        }
        if let plan = host.examPlans?.upcoming().first {
            await startProv(for: plan)
        } else {
            await host.startStudy()
        }
    }

    /// Ke35: Provläge asked for the exam once in this run of the app.
    @ObservationIgnored private var provAskedForExam = false
    /// Ke35: the exam step was opened by Starta in Provläge; when it closes (saved or "Inte nu"), Provläge starts.
    @ObservationIgnored var startsProvAfterExamStep = false

    /// Ke35: after "Har du prov snart?" from Starta in Provläge: with the exam if one was saved, else without.
    func startProvAfterExamStep() async {
        guard let host, startsProvAfterExamStep else { return }
        startsProvAfterExamStep = false
        if let plan = host.examPlans?.upcoming().first {
            await startProv(for: plan)
        } else {
            await host.startStudy()
        }
        host.showsListeningScreen = host.problem != .microphoneDenied || host.isActiveSession
    }

    /// D83: the first-start questions were answered (or skipped): save, put the exam in Minne, start.
    func finishStudyOnboarding(_ answers: StudyProfile) async {
        guard let host else { return }
        var profile = answers
        profile.onboarded = true
        host.studyProfile.profile = profile
        host.isShowingStudyOnboarding = false
        studyProfileChanged()
        await host.startStudy()
    }

    /// Settings or a voice command changed the profile: Minne follows (absolute exam date).
    func studyProfileChanged() {
        guard let host else { return }
        host.memory.forget("provprofil")
        for fact in host.studyProfile.profile.memoryFacts() { host.memory.add(fact, kind: .fact, source: .manual) }
        host.refreshKeyterms()
    }

    /// D84: "Lumen, jag går i åk 9 och ska snart ha prov i biologi". The phone's reading answers at once ("Biologi
    /// åk 9, sparat."); Kevin's `/study-profile` then adds the subject's terms and what the phone could not read.
    private func profileStatement(_ text: String) {
        guard let host else { return }
        var profile = host.studyProfile.profile
        let local = ProfileStatement.parse(text)
        if let local {
            local.apply(to: &profile)
            host.studyProfile.profile = profile
            studyProfileChanged()
            saveSpokenExam(profile)
            host.say(local.confirmation())
            host.modeLog("Profile by voice (phone): \(local.confirmation())")
        }
        guard let studyProfileClient = host.studyProfileClient else {
            if local == nil { host.say(host.language == .swedish ? "Jag uppfattade inte vad du läser." : "I did not catch what you study.") }
            return
        }
        let body = StudyProfileClient.body(text: text, profile: host.studyProfile.profile, swedish: host.language == .swedish)
        Task { [weak self] in
            let reply = await studyProfileClient.read(body)
            guard let self, let host = self.host else { return }
            guard let reply else {
                if local == nil { host.say(host.language == .swedish ? "Jag uppfattade inte vad du läser." : "I did not catch what you study.") }
                return
            }
            var updated = host.studyProfile.profile
            reply.apply(to: &updated)
            host.studyProfile.profile = updated
            self.studyProfileChanged()
            self.saveSpokenExam(updated)
            host.modeLog("Profile by voice (server): \(reply.terms.count) terms")
            if local == nil {
                let heard = ProfileStatement(grade: updated.grade, course: updated.course.isEmpty ? nil : updated.course,
                                             subject: updated.subject.isEmpty ? nil : updated.subject, examDate: updated.examDate)
                if !heard.isEmpty { host.say(heard.confirmation()) }
            }
        }
    }

    /// D86: a said exam with a subject and a date is one of the saved exams too.
    private func saveSpokenExam(_ profile: StudyProfile) {
        guard let examPlans = host?.examPlans, !profile.subject.isEmpty, let date = profile.examDate, !profile.noExam else { return }
        examPlans.save(ExamPlan(grade: profile.grade, course: profile.course, area: .of(subject: profile.subject),
                                subject: profile.subject, date: date, topics: profile.topics ?? ""))
    }

    /// The exam being studied: the one chosen, else the nearest exam in the profile's subject.
    func currentExamID() -> UUID? {
        guard let host else { return nil }
        if let activeExamID, host.examPlans?.plans.contains(where: { $0.id == activeExamID }) == true { return activeExamID }
        let subject = host.studyProfile.profile.subject
        return host.examPlans?.upcoming().first { $0.subject.caseInsensitiveCompare(subject) == .orderedSame }?.id
    }

    /// D86 "Spara prov": kept with the others, and Provläge's profile from now on. The subject's terms follow.
    func saveExamPlan(_ plan: ExamPlan) {
        guard let host else { return }
        host.examPlans?.save(plan)
        host.updateWidget(now: Date()) // A44
        useExamPlan(plan)
        host.modeLog("Exam saved: \(plan.name), \(plan.daysLeft()) days")
    }

    /// Provläge for this exam: its grade, subject, date and topics become the profile.
    func useExamPlan(_ plan: ExamPlan) {
        guard let host else { return }
        if activeExamID != plan.id { host.provMode.forgetTurns() } // another exam: its turns are not this one's
        activeExamID = plan.id
        var profile = host.studyProfile.profile
        plan.apply(to: &profile)
        profile.onboarded = true
        profile.terms = nil
        host.studyProfile.profile = profile
        studyProfileChanged()
        guard let studyProfileClient = host.studyProfileClient else { return }
        let body = StudyProfileClient.body(text: "", profile: profile, swedish: host.language == .swedish)
        Task { [weak self] in
            guard let reply = await studyProfileClient.read(body), let self, let host = self.host else { return }
            var updated = host.studyProfile.profile
            if !reply.terms.isEmpty { updated.terms = Array(reply.terms.prefix(50)) }
            host.studyProfile.profile = updated
            host.refreshKeyterms()
        }
    }

    /// D86 start screen: an exam row's microphone, or "Få A-svar till provet".
    func startProv(for plan: ExamPlan, answersOnly: Bool = false, sayPlan: Bool = true) async {
        guard let host else { return }
        useExamPlan(plan)
        host.selectedMode = .prov
        provAnswersOnly = answersOnly
        await host.startStudy()
        askSubjectIfOnlyArea(plan)
        if sayPlan, !answersOnly, awaitingSubject == nil { host.provMode.studyPlan.sayPrompt(for: plan) }
    }

    /// A24: an exam that is only an area ("NO", from the first start) waits for its subject; the quiz can wait for it.
    @ObservationIgnored private var awaitingSubject: (planID: UUID, area: ExamPlan.Area, quizAfter: Bool)?

    private func askSubjectIfOnlyArea(_ plan: ExamPlan) {
        guard let host, host.study.isActive, host.mode == .prov, let area = SubjectQuestion.area(of: plan) else {
            awaitingSubject = nil
            return
        }
        awaitingSubject = (plan.id, area, false)
        host.modeLog("Provläge: the exam is only an area (\(area.title)), the subject is asked for (A24)")
        host.say(SubjectQuestion.prompt(for: area))
    }

    /// The answer to "Vilket ämne i NO …?". True: it was the subject (saved, and the quiz starts if it waited).
    private func subjectAnswered(_ text: String) -> Bool {
        guard let host, let waiting = awaitingSubject else { return false }
        awaitingSubject = nil
        guard let subject = SubjectQuestion.subject(in: text, area: waiting.area),
              var plan = host.examPlans?.plans.first(where: { $0.id == waiting.planID }) else {
            if waiting.quizAfter { host.askForQuiz() } // not a subject: the words are a turn of their own, then the quiz
            return false
        }
        plan.subject = subject
        saveExamPlan(plan)
        host.modeLog("Provläge: the subject is \(subject) (A24)")
        if waiting.quizAfter { host.askForQuiz() } // before `say`: the quiz's request interrupts speech
        host.say("Bra, \(plan.name.lowercased()).")
        return true
    }

    /// D97 (owner): "Få A-svar till provet" answers the student's questions and never quizzes; "Förhör mig" does both.
    private(set) var provAnswersOnly = false

    func startAnswersOnly(for plan: ExamPlan) async {
        await startProv(for: plan, answersOnly: true)
    }

    /// A18 (Kelly Ke9): Start's one blue button says what it does, "Förhör mig", the same words as the voice command.
    /// Provläge for the exam, and the first quiz question at once.
    func startQuiz(for plan: ExamPlan) async {
        guard let host else { return }
        host.beginFreshPass()
        await startProv(for: plan, sayPlan: false)
        guard host.study.isActive, host.mode == .prov else { return }
        if awaitingSubject != nil {
            awaitingSubject?.quizAfter = true // A24: the subject first, then the quiz
            return
        }
        host.askForQuiz()
    }

    /// A33 (D109): the first start asks aloud after the first answer; the next utterance is the answer (a short one
    /// is enough: "biologi på fredag"), read on the phone and by `/study-profile`. "Nej" declines.
    @ObservationIgnored private var examAskedAloud = false
    private(set) var examQuestionDeclined = false

    func askAboutExamByVoice(firstStart: Bool = true) async {
        guard let host else { return }
        examQuestionDeclined = false
        await listenForExamStatement()
        examAskedAloud = true
        examAskedAt = Date()
        // A47: from Start the student asked to add one; the first start asks whether there is one at all.
        host.say(firstStart ? "Har du prov snart? Säg vilket ämne och när." : "Vilket prov? Säg ämnet och när det är.")
    }

    /// A60 (Toby T8b finding 1): when the question was asked; the answer must come within `examAnswerWindow`.
    @ObservationIgnored private var examAskedAt: Date?
    nonisolated static let examAnswerWindow: TimeInterval = 30

    /// A60: the exam step was closed (skipped, saved or "Inte nu"): the next sentence is an ordinary one again.
    func stopListeningForExamStatement() {
        awaitingExamStatement = false
        examAskedAloud = false
        examAskedAt = nil
    }

    /// The utterance answers "Har du prov snart?": in time, and not a question of its own ("Hur många ben har en
    /// spindel?"), unless it is about school.
    nonisolated static func answersExamQuestion(_ text: String, askedAt: Date?, at date: Date) -> Bool {
        guard let askedAt, date.timeIntervalSince(askedAt) < examAnswerWindow else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("?"), !ProfileStatement.isAboutSchool(trimmed) { return false }
        return true
    }

    /// "Lägg till prov" → "Eller säg det": listen, and the next sentence about an exam is saved as one.
    func listenForExamStatement() async {
        guard let host else { return }
        awaitingExamStatement = true
        if !host.isListening {
            if host.canResume { await host.resume() } else { await host.startListening() }
        }
    }

    /// The words answer "Har du prov snart?" (A33), or are an exam said after "Lägg till prov" → "Eller säg det".
    /// True: they were the exam (or "nej"), and nothing else takes them.
    func takesExamStatement(_ text: String, overlapsPlayback: Bool, at date: Date) -> Bool {
        guard let host else { return false }
        if awaitingExamStatement, examAskedAloud, !overlapsPlayback,
           Self.answersExamQuestion(text, askedAt: examAskedAt, at: date) {
            // A33: the answer to the question Lumen asked aloud.
            stopListeningForExamStatement()
            host.discardAhead(reason: "the answer about an exam")
            host.study.discardTurnText()
            if ExamAnswer.isDecline(text) {
                examQuestionDeclined = true
                host.say("Okej. Du kan lägga till ett prov på Start när du vill.")
            } else {
                profileStatement(ExamAnswer.statement(text))
            }
            return true
        }
        if awaitingExamStatement, ProfileStatement.isAboutSchool(text) {
            awaitingExamStatement = false
            host.discardAhead(reason: "an exam said aloud")
            profileStatement(text)
            return true
        }
        return false
    }

    /// A24: the answer to "Vilket ämne i NO är provet i?". True: it was the subject.
    func takesSubject(_ text: String, overlapsPlayback: Bool) -> Bool {
        guard let host else { return false }
        return awaitingSubject != nil && host.study.isActive && host.mode == .prov && !overlapsPlayback && subjectAnswered(text)
    }

    /// "Lumen, jag går i åk 9 …" (D84), from the model's voice and instruction paths.
    func profileSaid(_ text: String) {
        profileStatement(text)
    }
}
