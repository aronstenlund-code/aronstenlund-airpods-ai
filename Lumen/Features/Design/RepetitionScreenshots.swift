#if DEBUG
import SwiftUI

/// A79–A81 (Kelly Ke49 §7): the repetition mode's screens for the Simulator screenshots, with a made-up biology exam
/// (no student text). The screenshot mode uses the mocks (no network, no ElevenLabs).
@MainActor
enum RepetitionDemo {
    static let scenes: Set<String> = ["repHome", "repHomeEmpty", "repMaterial", "repList", "repEdit", "repControls",
                                      "repControlsDone", "repControlsMissing", "repShareReady", "repMakeError", "repPlayFirst",
                                      "repPlayThink", "repPlayAnswer", "repPaused", "repWaiting",
                                      "repShare", "moreModes",
                                      // A83/A84 (Angela Fable's request): Publicera prov, Prov från din skola, the voice.
                                      "repPublish", "repSchools", "repSchoolsEmpty", "repPublication", "repVoice",
                                      // A92: the help AI (MockHelp in the screenshot mode)
                                      "repHelp", "repHelpAnswer", "repHelpTry",
                                      // A94 (Kelly Ke55): the first start
                                      "fsWelcome", "fsReadMore", "fsNewDrill",
                                      // A93 (Kelly Ke58): Gör med ChatGPT
                                      "gptSteps", "gptFound", "gptWrong",
                                      // A100: Fler lägen only after the first exam; the sound cannot be made (K62)
                                      "repHomeNew", "repHomeStarted", "repSoundProblem", "repHomeSoundProblem",
                                      // A99 (D175, D176): no questions left this month; longer questions
                                      "repQuotaUsedUp", "repLength", "repLengthEdit", "repSoundProblemNone",
                                      "repWaitingProblem"]

    /// A100: an exam whose sound could not be made at all (the voice service is out): Starta prov is grey.
    static let chemistry = Drill(title: "Kemiprovet", summary: DrillSummary(subject: "Kemi", grade: "åk 9", covers: "Syror och baser."),
                                 items: [DrillItem(question: "Vad är en syra?", short: "Ett ämne som lämnar ifrån sig vätejoner i vatten.",
                                                   long: "Ett ämne som lämnar ifrån sig vätejoner i vatten. Därför sjunker pH-värdet.")])

    /// A99: Biologiprovet with its second question a bit longer and its third very long (the server's classes).
    static var drillWithLengths: Drill {
        var copy = drill
        if copy.items.count > 2 {
            copy.items[1].lengthClass = .longer
            copy.items[2].lengthClass = .tooLong
        }
        return copy
    }

    /// A93: ChatGPT's answer for the found screen, 20 questions and one line that cannot be read.
    static let pastedAnswer: String = {
        let pairs = [
            ("Varför behöver växter ljus?", "Växter behöver ljus för fotosyntesen, där de gör socker av koldioxid och vatten. Ljuset ger energin, och sockret blir växtens mat."),
            ("Vad gör klorofyllet?", "Klorofyllet fångar ljusets energi. Det är grönt och sitter i kloroplasterna i bladens celler."),
            ("Vad är cellandning?", "Cellandning är när cellerna bryter ner socker med syre och får energi. Koldioxid och vatten blir kvar."),
            ("Varför är bladen gröna?", "Bladen är gröna för att klorofyllet tar upp rött och blått ljus men kastar tillbaka det gröna."),
        ]
        var text = "Här är dina frågor!\n\n"
        for i in 0..<20 {
            let (question, answer) = pairs[i % pairs.count]
            text += "Fråga: \(question)\nSvar: \(answer)\n\n"
        }
        return text
    }()

    static let items: [DrillItem] = [
        ("Varför behövs klorofyll?", "Klorofyll fångar ljuset som fotosyntesen behöver.",
         "Utan ljusets energi kan växten inte bygga socker av koldioxid och vatten."),
        ("Vad bildas vid fotosyntesen?", "Socker och syre bildas av koldioxid och vatten.",
         "Sockret ger växten energi och byggmaterial, och syret används av djur i cellandningen."),
        ("Hur hänger fotosyntes och cellandning ihop?", "Fotosyntesen bygger socker och cellandningen bryter ner det.",
         "Den enas produkter är den andras råvaror, så kol och syre går runt i ett kretslopp."),
        ("Varför behöver cellen mitokondrier?", "Där sker cellandningen som ger cellen energi.",
         "Mitokondrierna gör om socker och syre till energi i form av ATP, koldioxid och vatten."),
        ("Vad är en näringskedja?", "Den visar vem som äter vem i ett ekosystem.",
         "Energin från solen går från växterna till växtätarna och vidare till rovdjuren, och det mesta blir värme på vägen."),
    ].map { DrillItem(question: $0.0, short: $0.1, long: $0.1 + " " + $0.2) }

    static let drill = Drill(title: "Biologiprovet",
                             summary: DrillSummary(subject: "Biologi", grade: "åk 9",
                                                   covers: "Fotosyntes, cellandning, kolets kretslopp och näringskedjor."),
                             items: items, questionCount: 20)

    static let history = Drill(title: "Historiaprovet", summary: DrillSummary(subject: "Historia", grade: "åk 9", covers: "Industriella revolutionen."),
                               items: [
                                   DrillItem(question: "Varför började industrialiseringen i England?",
                                             short: "England hade kol, järn, kapital och kolonier som köpte varorna.",
                                             long: "England hade kol, järn, kapital och kolonier som köpte varorna. Dessutom fanns många arbetare som flyttat från landsbygden."),
                                   DrillItem(question: "Vad gjorde ångmaskinen viktig?",
                                             short: "Den gav kraft till fabriker, tåg och båtar oberoende av vatten och vind.",
                                             long: "Den gav kraft till fabriker, tåg och båtar oberoende av vatten och vind. Därför kunde fabrikerna ligga nära städerna."),
                               ])

    /// Once, before the first frame.
    static func seed(_ model: RepetitionModel, for name: String) {
        for old in model.store.drills { model.store.delete(old.id) } // left by an earlier screen
        // A83: demo schools and publications instead of the server; my school is set except for the empty list.
        model.publishing = DemoPublishing(empty: name == "repSchoolsEmpty")
        model.mySchool = name == "repSchoolsEmpty" ? nil : DemoPublishing.school
        if name == "repSchoolsEmpty" { model.mySchoolAsked = true }
        // A100: a new user without exams has not started one, so no Fler lägen row (set here, scenes share defaults).
        if name == "repHomeEmpty" { UserDefaults.standard.set(false, forKey: "repetition.controlsChecked") }
        guard name != "repHomeEmpty", name != "moreModes" else { return }
        // The newest is Start's "Nästa prov": Historia first, so Biologiprovet is on the card.
        model.store.save(history)
        model.store.save(drill)
        // A99: the month's questions are used up (D175); the server's length classes (D176).
        if name == "repQuotaUsedUp" { model.quota = DrillQuota(used: 15, limit: 15, resets: "2026-12-01", serverLeft: 0, suggest: 0) }
        if name == "repLength" || name == "repLengthEdit" { model.store.save(drillWithLengths) }
        if name == "repSoundProblemNone", let audio = model.audio as? DeviceVoiceDrillAudio {
            model.store.save(chemistry) // no files at all
            audio.stagedProblems[chemistry.id] = CloudDrillAudio.unavailableLine
        }
        // A100: Fler lägen shows only after the first exam was started (the control check).
        if name == "repHomeNew" { UserDefaults.standard.set(false, forKey: "repetition.controlsChecked") }
        if name == "repHomeStarted" || name == "repHomeSoundProblem" {
            UserDefaults.standard.set(true, forKey: "repetition.controlsChecked")
        }
        if name == "repSoundProblem" || name == "repHomeSoundProblem", let audio = model.audio as? DeviceVoiceDrillAudio {
            audio.stagedProblems[history.id] = CloudDrillAudio.unavailableLine
            audio.stagedProblems[drill.id] = name == "repHomeSoundProblem" ? CloudDrillAudio.unavailableLine : nil
        }
        // Biologiprovet's sound is ready (silent files). Historiaprovet's is not (Kelly K4: "Delas när ljudet är
        // klart (4 av 6)"): its first question has all its files, the second only its question.
        if let audio = model.audio as? DeviceVoiceDrillAudio {
            let silence = [Int16](repeating: 0, count: 1_600)
            for item in drill.items {
                for text in [item.question, item.short, item.long] {
                    try? WAVWriter.write(samples: silence, sampleRate: 16_000, to: audio.url(text: text))
                }
            }
            let first = history.items[0]
            for text in [first.question, first.short, first.long, history.items[1].question] {
                try? WAVWriter.write(samples: silence, sampleRate: 16_000, to: audio.url(text: text))
            }
        }
        let player = RepetitionPlayer(count: drill.items.count, track: { _ in nil }, source: FileRepetitionAudioSource(),
                                      timer: TaskRepetitionTimer(), thinkingSeconds: 6)
        switch name {
        case "repPlayThink": player.stageForScreenshot(.thinking(1), index: 1, lap: 1)
        case "repPlayFirst":
            player.isFirstLap = true // Kelly N1: "Tryck på AirPods för svaret"
            player.stageForScreenshot(.thinking(0), index: 0)
        case "repPlayAnswer": player.stageForScreenshot(.answer(1, .long), index: 1, lap: 1)
        case "repPaused": player.stageForScreenshot(.answer(1, .long), index: 1, lap: 1, paused: true)
        case "repWaiting": player.stageForScreenshot(.waitingForAudio(3), index: 3)
        case "repWaitingProblem":
            // A100: the sound stopped coming mid-exam (the voice service is out): the line instead of "Gör ljud …".
            (model.audio as? DeviceVoiceDrillAudio)?.stagedProblems[drill.id] = CloudDrillAudio.unavailableLine
            player.stageForScreenshot(.waitingForAudio(3), index: 3)
        default: return
        }
        model.session.stageForScreenshot(drill, player: player)
    }

    /// The check after the three presses: all arrived, or AirPods 1/2 (two presses came as play/pause, three never).
    static func stagedCheck(allWork: Bool) -> ControlCheck {
        let check = ControlCheck(hub: RemoteCommandHub(), waitSeconds: 3600, activatesAudio: false,
                                 defaults: UserDefaults(suiteName: "screenshot-controlcheck") ?? .standard)
        check.restart()
        check.received(.toggle)
        if allWork {
            check.received(.next)
            check.received(.previous)
        } else {
            check.received(.toggle)
            check.timedOut()
        }
        return check
    }

    @ViewBuilder
    static func view(_ name: String, listening: ListeningModel) -> some View {
        if let model = listening.repetition {
            switch name {
            case "repHome", "repHomeEmpty", "repHomeNew", "repHomeStarted", "repHomeSoundProblem":
                NavigationStack { HomeView(model: listening) }
            case "repSoundProblem": NavigationStack { DrillView(model: model, drillID: history.id) }
            case "repSoundProblemNone": NavigationStack { DrillView(model: model, drillID: chemistry.id) }
            case "repQuotaUsedUp": NewDrillView(model: model) { _ in }
            case "repLength": NavigationStack { DrillView(model: model, drillID: drill.id) }
            case "repLengthEdit": DrillItemEditor(model: model, drill: drillWithLengths, itemID: drill.items[2].id)
            case "repMaterial": NewDrillView(model: model) { _ in }
            case "fsWelcome": WelcomeView {}
            case "fsReadMore": DataPrivacySheet()
            case "fsNewDrill": NewDrillView(model: model, onLater: {}) { _ in }
            case "gptSteps": ChatGPTImportView(model: model) { _ in }
            case "gptFound":
                if let found = ChatGPTImport.read(pastedAnswer) {
                    ChatGPTImportView(model: model, start: .found(found)) { _ in }
                }
            case "gptWrong": ChatGPTImportView(model: model, start: .wrong) { _ in }
            case "repMakeError":
                NewDrillView(model: model, onSaved: { _ in },
                             stagedProblem: DrillMakingError.server("URLError -1005").userMessage)
            case "repList": NavigationStack { DrillView(model: model, drillID: drill.id) }
            // Kelly B5: the Dela row in view, off (sound not ready) and ready.
            case "repShare": NavigationStack { DrillView(model: model, drillID: history.id, showsShare: true) }
            case "repShareReady": NavigationStack { DrillView(model: model, drillID: drill.id, showsShare: true) }
            case "repEdit": DrillItemEditor(model: model, drill: drill, itemID: drill.items[0].id)
            case "repHelp": HelpChatView(model: model)
            case "repHelpAnswer": HelpChatView(model: model, suggestion: "Hur fungerar trycken?", askNow: true, onOpen: { _ in })
            case "repHelpTry":
                // Kelly H1: as in the app, pushed in the help sheet's stack (title and back button).
                NavigationStack(path: .constant(["try"])) {
                    HelpChatView(model: model)
                        .navigationDestination(for: String.self) { _ in HelpTryView(model: model) {} }
                }
            case "repPublish": PublishSheet(model: model, drill: drill)
            case "repSchools", "repSchoolsEmpty": NavigationStack { SchoolExamsView(model: model) }
            case "repPublication": PublicationView(model: model, publication: DemoPublishing.results[0])
            case "repVoice":
                NavigationStack {
                    Form { DrillVoiceChoice(voice: .constant("A")) }
                        .navigationTitle("Stämmer det här?")
                        .navigationBarTitleDisplayMode(.inline)
                }
            case "repControls":
                ControlCheckView(hub: RemoteCommandHub(), sound: nil, waitSeconds: 3600, onStart: {}, onLater: {})
            case "repControlsDone", "repControlsMissing": ControlCheckView(staged: stagedCheck(allWork: name == "repControlsDone"))
            case "repPlayThink", "repPlayFirst", "repPlayAnswer", "repPaused", "repWaiting", "repWaitingProblem":
                RepetitionPlayerView(model: model)
            case "moreModes": ModeSwitchSheet(model: listening, current: .standard, onPick: { _ in }, onSleep: {})
            default: Text(verbatim: "Okänd skärm: \(name)")
            }
        } else {
            Text(verbatim: "Inget repetitionsläge")
        }
    }
}
/// A83: Publicera prov's server in the screenshots (made-up schools and exams, no account, no network).
@MainActor
final class DemoPublishing: DrillPublishingService {
    static let school = DrillSchool(code: "10000001", name: "Kungsholmens gymnasium", locality: "Stockholm")
    static let results: [DrillPublicationView] = [
        DrillPublicationView(id: "p1", title: "Biologiprovet", subject: "Biologi", school: school,
                             exam_date: DrillPublishing.dayString(Date().addingTimeInterval(5 * 86_400)), items: 20,
                             display_name: "plugghajen"),
        DrillPublicationView(id: "p2", title: "Andra världskriget", subject: "Historia", school: school,
                             exam_date: DrillPublishing.dayString(Date().addingTimeInterval(12 * 86_400)), items: 15,
                             display_name: nil),
        DrillPublicationView(id: "p3", title: "Ekvationer", subject: "Matematik", school: school,
                             exam_date: DrillPublishing.dayString(Date().addingTimeInterval(-40 * 86_400)), items: 12,
                             display_name: nil),
    ]
    let empty: Bool

    init(empty: Bool) { self.empty = empty }

    func schools(matching query: String) async throws(DrillCloudError) -> [DrillSchool] { [Self.school] }
    func publish(drillID: String, school: DrillSchool, subject: String, examDate: Date,
                 displayName: String?) async throws(DrillCloudError) -> DrillPublicationView { Self.results[0] }
    func unpublish(drillID: String) async throws(DrillCloudError) {}
    func search(school: DrillSchool?, subject: String?, mySchool: DrillSchool?) async throws(DrillCloudError) -> [DrillPublicationView] {
        empty ? [] : Self.results
    }
    func importPublication(id: String) async throws(DrillCloudError) -> DrillCloudView {
        throw .offline("screenshots")
    }
    func report(publicationID: String, reason: DrillReportReason) async throws(DrillCloudError) {}
    func played(drillID: String) async {}
}
#endif
