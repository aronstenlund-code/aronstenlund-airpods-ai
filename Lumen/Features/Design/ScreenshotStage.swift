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
        guard name != "empty", name != "intro" else { return }
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
            case "intro": IntroView {}
            case "first": FirstQuestionView(model: model, microphoneDenied: false) {}
            case "home", "empty": NavigationStack { HomeView(model: model) }
            case "addExam": AddExamView(model: model) {}
            case "listening": ListeningScreen(model: model) {}
            case "switch": ModeSwitchSheet(model: model, current: .prov)
            case "errors":
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach([LumenProblem.microphoneDenied, .offline, .airPodsDisconnected, .overloaded], id: \.self) { problem in
                            ErrorCard(problem: problem) {}
                        }
                    }
                    .padding(20)
                }
                .lumenScreen()
            case "settings": NavigationStack { SettingsView(model: model, diagnostics: container.diagnostics) }
            case "interview": NavigationStack { InterviewSetupView(model: model, settings: model.modeSettings) }
            case "live": NavigationStack { LiveStartView(model: model, settings: model.modeSettings, mode: .social) }
            default: Text(verbatim: "Okänd skärm: \(name)")
            }
        }
    }
}
#endif
