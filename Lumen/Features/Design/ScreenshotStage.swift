#if DEBUG
import SwiftUI

/// A2: one screen with demo data, for the Simulator screenshots (`.github/workflows/screenshots.yml`). Debug builds
/// only, never in Release. Started with the launch argument `-LumenScreenshot <name>`; no microphone, no network.
struct ScreenshotStage: View {
    let name: String
    let container: AppContainer

    static var requested: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-LumenScreenshot"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// Demo exams, a profile, a practice item and two answered questions. Called once, before the first frame.
    static func seed(_ container: AppContainer, for name: String) {
        let model = container.listening
        if name == "empty" {
            for plan in model.examPlans?.plans ?? [] { model.examPlans?.delete(plan.id) } // left by an earlier screen
            return
        }
        guard name != "intro" else { return }
        // A30: Lyssnar while listening in Provläge, before the first frame (the stage is not observed).
        switch name {
        case "listeningProv": model.screenshotShows = .prov
        case "addExamFirst": model.screenshotShows = .standard // A46: "Säg till exempel", not "Startar …"
        case "practice": model.stagePracticeForScreenshot(PracticeDemo.run, result: nil)
        case "practiceResult": model.stagePracticeForScreenshot(nil, result: PracticeDemo.result)
        default: break
        }
        let today = Calendar.current.startOfDay(for: Date())
        func day(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: today) ?? today }
        if model.examPlans?.plans.isEmpty == true {
            model.examPlans?.save(ExamPlan(grade: .y9, area: .no, subject: "Biologi", date: day(5), topics: "fotosyntes, cellandning"))
            model.examPlans?.save(ExamPlan(grade: .y9, area: .sprak, subject: "Engelska", date: day(10)))
            model.examPlans?.save(ExamPlan(grade: .y9, area: .so, subject: "Historia", date: day(16)))
        }
        var profile = model.studyProfile.profile
        profile.subject = "Biologi"
        profile.grade = .y9
        profile.examDate = day(5)
        profile.onboarded = true
        model.studyProfile.profile = profile
        if !model.memory.facts.contains(where: { $0.text.hasPrefix("Provträning") }) {
            model.memory.add("Provträning: öva på uppgifter som \"Cellandning och klorofyll\"", kind: .fact, source: .automatic)
        }
        // A38/A43: a streak of three days and the readiness ring on the nearest exam.
        if let nearest = model.examPlans?.upcoming().first {
            model.stageStudyPlanForScreenshot(nearest, reply: ReadinessDemo.reply(for: nearest), quizDays: ReadinessDemo.quizDays)
        }
        // A46: study cards, so Start shows "Öva med 3 vändkort".
        if model.studyCards?.current().isEmpty == true {
            for card in FlipDemo.cards { model.studyCards?.add(question: card.question, answer: card.answer, profile: profile) }
        }
        if model.conversation.answers.isEmpty {
            model.receiveAnswer(question: "Vad är klorofyll?", answer: "Klorofyll är det gröna ämnet i bladen som fångar ljuset.", source: "cloud")
            model.receiveAnswer(question: "Vad är fotosyntes?",
                                answer: "Fotosyntesen är när växter använder ljusenergi för att göra socker av koldioxid och vatten. Syre bildas som en restprodukt.",
                                source: "cloud")
        }
    }

    var body: some View {
        let model = container.listening
        Group {
            switch name {
            case "intro": IntroView {}.lumenScreen() // A26 R3: as in the app (FirstStartView applies it)
            case "first": FirstQuestionView(model: model, microphoneDenied: false) {}.lumenScreen()
            case "home", "empty": NavigationStack { HomeView(model: model) }
            case "addExam": AddExamView(model: model) {}
            case "listening": ListeningScreen(model: model) {}
            case "cannotAnswer": ListeningScreen(model: model) {}.onAppear { model.showProblemForScreenshot(.overloaded) }
            case "switch": ModeSwitchSheet(model: model, current: .prov)
            case "errors":
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach([LumenProblem.overloaded, .offline, .voiceUnavailable, .microphoneDenied, .airPodsDisconnected], id: \.self) { problem in
                            ErrorCard(problem: problem) {}
                        }
                    }
                    .padding(20)
                }
                .lumenScreen()
            case "settings": NavigationStack { SettingsView(model: model, diagnostics: container.diagnostics) }
            case "voice": NavigationStack { VoicePageView(model: model) } // A26 R5
            // A30 (Kelly Ke20): Lyssnar in Provläge while listening, the practice exam on Lyssnar (with its badge), its
            // result, and the first start's exam step.
            case "listeningProv", "practice", "practiceResult": ListeningScreen(model: model) {} // set up in `seed`
            case "addExamFirst": AddExamView(model: model, isFirstStart: true) {}.lumenScreen()
            // A46 (N6): the flip cards, the question, the answer with Kunde / Kunde inte, and the end.
            case "flipCards", "flipCardsBack", "flipCardsDone":
                FlipCardsView(plan: FlipDemo.plan, deck: FlipDemo.deck(name), onMark: { _, _ in }, onClose: {})
            // A43: "Så redo är du".
            case "readiness":
                if let plan = model.examPlans?.upcoming().first, let readiness = model.readiness(for: plan) {
                    ReadinessView(plan: plan, readiness: readiness, known: ["fotosyntes", "klorofyll"],
                                  today: model.todayLine(for: plan), onQuiz: {}, onClose: {})
                }
            // A49 (D123): the night and the morning report (Kelly draws them properly in Ke27).
            case "sleep": SleepView(sleep: SleepController(store: SleepStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("sleep-demo"))))
            case "sleepReport": SleepReportView(night: SleepDemo.night, clipURL: { _ in FileManager.default.temporaryDirectory }, onDelete: {}, onClose: {})
            case "about": NavigationStack { AboutView() } // A13.1
            case "interview": NavigationStack { InterviewSetupView(model: model, settings: model.modeSettings) }
            case "live": NavigationStack { LiveStartView(model: model, settings: model.modeSettings, mode: .social) }
            default: Text(verbatim: "Okänd skärm: \(name)")
            }
        }
    }
}
/// A49: a demo night, 23:10–06:40, two times talking, a little snoring, one restless half hour.
private enum SleepDemo {
    static var night: SleepNight {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .minute, value: -50, to: today) ?? today // 23:10
        var night = SleepNight(start: start, end: start.addingTimeInterval(7.5 * 3600))
        night.talks = [SleepTalk(at: start.addingTimeInterval(2.2 * 3600), seconds: 4, text: "nej, det är min tur att svara", clip: "a.caf"),
                       SleepTalk(at: start.addingTimeInterval(5.1 * 3600), seconds: 3, text: nil, clip: "b.caf")]
        night.snores = (0..<40).map { start.addingTimeInterval(3.0 * 3600 + Double($0) * 5) }
        night.snoreSeconds = 12 * 60
        night.noises = (0..<14).map { start.addingTimeInterval(4.0 * 3600 + Double($0) * 120) }
        night.batteryUsed = 9
        return night
    }
}

/// A38/A43: the plan's reply as K31/K33 send it, and three quiz days ending today.
private enum ReadinessDemo {
    static var quizDays: [String] {
        (0..<3).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }.map { StudyHistory.day($0) }
    }

    static func reply(for plan: ExamPlan) -> StudyPlanAPI.ExamPlanReply {
        let today = StudyHistory.day(Date())
        return StudyPlanAPI.ExamPlanReply(
            name: plan.name, date: StudyHistory.day(plan.date), daysLeft: plan.daysLeft(), prompt: nil,
            plan: [StudyPlanAPI.Day(date: today, minutes: 10, concepts: ["cellandning", "mitokondrier"], note: nil)],
            readiness: StudyPlanAPI.Readiness(
                readyPct: 68, practiced: 7, total: 12,
                weakest: [.init(concept: "cellandning", score: 0, why: "fel senast"),
                          .init(concept: "kolets kretslopp", score: 0, why: "inte övat än"),
                          .init(concept: "mitokondrier", score: 0.4, why: "dags att repetera")],
                explain: "Räknat på 12 begrepp, 7 övade. Ett begrepp räknas fullt när du har haft rätt tre gånger i rad."))
    }
}

/// A46: demo flip cards, biology like the demo exam.
private enum FlipDemo {
    static let plan = ExamPlan(grade: .y9, area: .no, subject: "Biologi", date: Date().addingTimeInterval(5 * 86_400),
                               topics: "fotosyntes, cellandning")
    static let cards = [
        StudyCard(question: "Vad behöver en växt för fotosyntesen?",
                  answer: "Ljus, koldioxid och vatten. Klorofyllet i bladen fångar ljuset.", subject: "Biologi", examDate: nil),
        StudyCard(question: "Var i cellen sker cellandningen?",
                  answer: "I mitokondrierna. Där blir socker och syre till energi, koldioxid och vatten.", subject: "Biologi", examDate: nil),
        StudyCard(question: "Vad är klorofyll?",
                  answer: "Det gröna ämnet i bladen som fångar ljusets energi.", subject: "Biologi", examDate: nil),
    ]

    static func deck(_ name: String) -> FlipDeck {
        var deck = FlipDeck(cards: cards)
        if name == "flipCardsBack" {
            deck.flip(); deck.mark(knew: true)
            deck.flip()
        } else if name == "flipCardsDone" {
            for knew in [true, false, true] { deck.flip(); deck.mark(knew: knew) }
        }
        return deck
    }
}

/// A16: demo questions for the practice exam's screenshots.
private enum PracticeDemo {
    static var tasks: [ExamTask] {
        // A46 (Kelly Ke18): biology, like the demo exam ("Biologiprovet").
        [ExamTask(no: "1", text: "Vad behöver en växt för att fotosyntesen ska fungera?", points: .init(E: 1, C: 0, A: 0),
                  answer: "Ljus, koldioxid och vatten", assessment: "", topic: "fotosyntes"),
         ExamTask(no: "2", text: "Var i cellen sker cellandningen, och vad bildas?", points: .init(E: 1, C: 1, A: 0),
                  answer: "I mitokondrierna; koldioxid, vatten och energi", assessment: "", topic: "cellandning"),
         ExamTask(no: "3", text: "Förklara hur fotosyntes och cellandning hänger ihop. Använd begreppen glukos och syre.",
                  points: .init(E: 1, C: 1, A: 1), answer: "", assessment: "", topic: "kolets kretslopp", answerSource: "eget svar")]
    }

    static var run: PracticeRun? {
        guard var run = PracticeRun(paper: ExamPaper(tasks: tasks, name: "Övningsprov")) else { return nil }
        run.graded(points: 1, max: 1)
        run.move(to: 1)
        run.graded(points: 1, max: 2)
        run.lastFeedback = "Delvis rätt. Cellandningen sker i mitokondrierna. Det som bildas är koldioxid, vatten och energi."
        run.lastFeedbackNo = "2"
        run.move(to: 2)
        return run
    }

    static var result: PracticeRun.Summary? {
        guard var done = run else { return nil }
        done.graded(points: 0, max: 3)
        return done.summary
    }
}
#endif
