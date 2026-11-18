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
                                      "repWaitingProblem",
                                      // A102 (K66 point 4): numbers and formulas shown as in a textbook
                                      "repNumbers", "repNumbersEdit",
                                      // A104 (Angela Fable): empty and error states; A103: no network
                                      "repSchoolsOffline", "repSchoolsFailed", "repSchoolSearchNone", "repSchoolSearchFailed", "repPublishFailed", "repSoundMaking", "repQuotaExam", "repHelpTryUsedUp", "repNewOffline", "repExamOffline",
                                      // A106 (Angela Fable, Kelly Ke63): a text read aloud
                                      "repTextNew", "repTextConfirm", "repText", "repTextMaking", "repTextPlay", "repTextPaused",
                                      "repTextEnd", "repTextWaiting", "repHomeText", "repTextControls",
                                      // A107 (D190): the sound is made at Starta prov
                                      "repUnstarted", "repUnstartedEdit", "repHomeUnstarted", "repUnstartedTooMany",
                                      // A109 (D194, Ke65): the practice reminder
                                      "repReminderAsk", "repReminderSettings", "repReminderDenied",
                                      // A110 (D198): the text exam before it is started (no Dela, the line under it)
                                      "repUnstartedText",
                                      // A112 (D200): reading aloud is off for now, the text works as usual
                                      "repOffUnstarted", "repOffText", "repOffTextPlay",
                                      // A115 (D203, Ke69): Säg i AirPods
                                      "repSayText", "repSayPlay", "repSayPlayOnce", "repSayRefused",
                                      // A131 (D213, Ke71): the month in credits
                                      "repSayCredits", "repSayCreditsShort", "repCreditsSheet",
                                      // A132 (D215): said texts are "Senaste" under the field, not exams
                                      "repHomeSaid", "repHomeSaidOnly", "repSayOnCard", "repSayUnlimited",
                                      // A136 (D220, Ke75): the style row, "I takt" and the voice sheet
                                      "repSayStyle", "repSayVoices",
                                      // A134 (D218), A141 (D224), Ke73/Ke77: the purchase part
                                      "repShop", "repShopWeekly", "repShopShort", "repShopWeeklyHome",
                                      // A141 (K99 fields): welcome credits and a rewarded invitation
                                      "repShopWelcome", "repShopReward",
                                      // A140 (D223): the voice the server chose from the style
                                      "repSayPicked",
                                      // Review pictures: A135 (the two lines after ten seconds), A139 (short numbers),
                                      // A136 (what a capsule in Senaste says), T48 (no products from the App Store)
                                      "repSaySlow", "repSayNoNet", "repSayBig", "repHomeSaidMarks", "repShopEmpty", "repSayWaiting",
                                      "repShopRefused", "repSayOnCardWaiting",
                                      // A117 (D205, Ke69): the month's questions, visible
                                      "repCredits", "repHomeCredits"]

    /// A117: the month as Kevin's `/drill quota` gives it (K82), with the price table.
    static let quotaWithPrices: DrillQuota = {
        var quota = DrillQuota(used: 88, limit: 400, per: "month", resets: "2026-12-01", serverLeft: 312, suggest: 20)
        quota.prices = DrillPrices(classes: [.init(name: "normal", min_chars: nil, max_chars: 800, questions: 1, tokens: 40),
                                             .init(name: "longer", min_chars: 801, max_chars: 1600, questions: 1, tokens: 60),
                                             .init(name: "too_long", min_chars: 1601, max_chars: 4000, questions: 1, tokens: 80)],
                                   read: .init(chars_per_question: 800), free: ["shared", "published"])
        return quota
    }()


    /// A115: a text someone might want to hear over and over before an exam (made up).
    static let said = "Fotosyntes: koldioxid + vatten + ljus blir socker och syre.\nCellandning: socker + syre blir energi, koldioxid och vatten."


    /// A107: Fysikprovet is saved but not started: no sound is asked for yet.
    static let unstarted: Drill = {
        var made = Drill(title: "Fysikprovet", summary: DrillSummary(subject: "Fysik", grade: "åk 9", covers: "Kraft och rörelse."),
                         items: [
                            DrillItem(question: "Vad är en kraft?", short: "En kraft är något som kan ändra ett föremåls rörelse eller form.",
                                      long: "En kraft är något som kan ändra ett föremåls rörelse eller form. Den mäts i newton."),
                            DrillItem(question: "Vad säger Newtons första lag?", short: "Ett föremål fortsätter som förut om ingen kraft verkar på det.",
                                      long: "Ett föremål fortsätter som förut om ingen kraft verkar på det. Det kallas tröghetslagen."),
                         ])
        made.audioStarted = false
        return made
    }()

    /// A106 (Ke63): Biologiprovet as a text read aloud: two headings, nine sentences (made up, no student text).
    static let reading: Drill = {
        func part(_ sentences: [String], heading: Bool = false) -> DrillItem {
            var item = DrillItem.textPart(sentences.joined(separator: " "), part: heading ? .heading : .para)
            item.sentences = sentences
            return item
        }
        return Drill.text(title: "Biologiprovet", summary: DrillSummary(subject: "Biologi", grade: "åk 9", covers: ""),
                          parts: [
                            part(["Fotosyntesen"], heading: true),
                            part(["Växter tillverkar sin egen näring genom fotosyntes.", "Det sker i bladens gröna korn, kloroplasterna.",
                                  "Där fångar klorofyllet energin i solljuset."]),
                            part(["Växten tar upp koldioxid ur luften och vatten genom rötterna.",
                                  "Med ljusets energi blir de till socker och syre.",
                                  "Sockret är växtens mat, och syret släpps ut genom klyvöppningarna."]),
                            part(["Cellandningen"], heading: true),
                            part(["I cellandningen bryts sockret ner igen.", "Det sker i mitokondrierna, i alla levande celler.",
                                  "Energin som frigörs använder cellen för att växa och röra sig."]),
                          ])
    }()

    /// A102: Matteprovet, spoken with the numbers as words, shown with digits and formulas (`DrillItem.screen`).
    static let maths: Drill = {
        func item(_ q: String, _ s: String, _ l: String, shown: DrillScreenText) -> DrillItem {
            var item = DrillItem(question: q, short: s, long: l)
            item.screen = shown
            return item
        }
        return Drill(title: "Matteprovet", summary: DrillSummary(subject: "Matematik", grade: "åk 9", covers: "Geometri och historia om talen."),
                     items: [
                        item("Vad säger Pythagoras sats?", "a i kvadrat plus b i kvadrat är c i kvadrat.",
                             "a i kvadrat plus b i kvadrat är c i kvadrat. Det gäller i en rätvinklig triangel.",
                             shown: DrillScreenText(question: nil, short: "a² + b² = c².",
                                                    long: "a² + b² = c². Det gäller i en rätvinklig triangel.")),
                        item("Hur räknar man ut arean av en cirkel?", "A är pi gånger r i kvadrat.",
                             "A är pi gånger r i kvadrat. Pi är ungefär tre komma fjorton.",
                             shown: DrillScreenText(question: nil, short: "A = π · r².",
                                                    long: "A = π · r². π är ungefär 3,14.")),
                        item("När fick Sverige sin första järnväg för persontrafik?", "Artonhundrafemtiosex.",
                             "Artonhundrafemtiosex. Den gick mellan Örebro och Ervalla.",
                             shown: DrillScreenText(question: nil, short: "1856.", long: "1856. Den gick mellan Örebro och Ervalla.")),
                     ])
    }()

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
        // A136: the voice, the style and "Skriv i takt" are staged only in their own scenes.
        UserDefaults.standard.removeObject(forKey: SayText.voiceKey)
        UserDefaults.standard.removeObject(forKey: SayText.inPaceKey)
        SayText.stagedStyle = nil
        SayText.stagedVoicesSheet = false
        // A83: demo schools and publications instead of the server; my school is set except for the empty list.
        model.publishing = DemoPublishing(empty: name == "repSchoolsEmpty", failure: DemoPublishing.failure(for: name),
                                          noSchools: name == "repSchoolSearchNone")
        // A103/A104: no network, said before the user tries.
        if ["repSchoolsOffline", "repNewOffline", "repExamOffline"].contains(name) { model.stageOffline(true) }
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
        // A104: the sound is being made (no file yet, nothing wrong); the month's questions ran out for an exam.
        if name == "repSoundMaking" { model.store.save(chemistry) }
        if name == "repQuotaExam" { model.stagedQuotaExceeded.insert(history.id) }
        if name == "repHelpTryUsedUp" { model.quota = DrillQuota(used: 15, limit: 15, resets: "2026-12-01", serverLeft: 0, suggest: 0) }
        if name == "repNumbers" || name == "repNumbersEdit" { model.store.save(maths) } // A102
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
        if name == "repHomeSaid" || name == "repHomeSaidOnly" { // A132 (D215)
            if name == "repHomeSaid" {
                model.store.save(history)
                model.store.save(drill)
            }
            for text in ["HISTORIA – 1880–1918\nNationalism = stark kärlek till den egna nationen.", said] {
                var made = Drill.text(title: SaidText.title(text), summary: DrillSummary(subject: "", grade: "", covers: ""),
                                      parts: SaidText.parts(text).map { DrillItem.textPart($0, part: .para) })
                made.said = true
                model.store.save(made)
            }
            var credits = DrillQuota(used: 264, limit: 1500, per: "month", resets: "2026-12-01")
            credits.unit = "chars"
            credits.remaining = 1236
            model.quota = credits
            SayText.stagedForScreenshots = nil
            SayText.stagedRefusal = nil
            return
        }
        model.shop = nil
        SayText.stagedRetry = false
        SayText.stagedStarting = false
        if name == "repSayWaiting" { // A144 (D225, Kelly): after 8 s the line, and the spinner goes on
            model.store.save(history)
            model.store.save(drill)
            var credits = DrillQuota(used: 264, limit: 1500, per: "month", resets: "2026-12-01")
            credits.unit = "chars"
            credits.remaining = 1236
            model.quota = credits
            SayText.stagedForScreenshots = said
            SayText.stagedCost = 120
            SayText.stagedRefusal = SayText.slowServerLine
            SayText.stagedStarting = true
            return
        }
        if name == "repSaySlow" || name == "repSayNoNet" || name == "repSayBig" { // A135 (D219.3), A139 (D222)
            model.store.save(history)
            model.store.save(drill)
            let big = name == "repSayBig"
            var credits = DrillQuota(used: big ? 0 : 264, limit: 1500, per: "month", resets: "2026-12-01")
            credits.unit = "chars"
            credits.remaining = big ? 5392 : 1236
            model.quota = credits
            SayText.stagedForScreenshots = said
            SayText.stagedCost = big ? 1251 : 120
            SayText.stagedRefusal = big ? nil : name == "repSaySlow" ? SayText.failedLine : SayText.slowLine
            SayText.stagedRetry = !big
            return
        }
        if name == "repHomeSaidMarks" { // A136 (Kelly's review): the style's first word, else the voice's name
            model.store.save(history)
            model.store.save(drill)
            model.stageSayVoices([SayVoice(voice_id: "nils000000000004", name: "Nils"),
                                  SayVoice(voice_id: "astrid0000000001", name: "Astrid")], defaultName: "Astrid")
            for (text, style, voice) in [("HISTORIA – 1880–1918\nNationalism = stark kärlek till den egna nationen.", String?.none, String?.some("nils000000000004")),
                                         (said, nil, nil), ("1918: Vapenstillestånd.", "Lugnt, som en lärare", nil),
                                         ("Tre rader att kunna.", nil, "astrid0000000001")] {
                var made = Drill.text(title: SaidText.title(text), summary: DrillSummary(subject: "", grade: "", covers: ""),
                                      parts: SaidText.parts(text).map { DrillItem.textPart($0, part: .para) })
                made.said = true
                made.style = style
                made.voiceID = voice
                model.store.save(made)
            }
            var credits = DrillQuota(used: 264, limit: 1500, per: "month", resets: "2026-12-01")
            credits.unit = "chars"
            credits.remaining = 1236
            model.quota = credits
            SayText.stagedForScreenshots = nil
            SayText.stagedRefusal = nil
            return
        }
        if name.hasPrefix("repShop") { // A134 (D218), A141 (D224): packs, the weekly card and the invitation
            model.store.save(history)
            model.store.save(drill)
            let short = name == "repShopShort" || name == "repShopRefused"
            var credits = DrillQuota(used: short ? 1412 : 264, limit: 1500, per: "month", resets: "2026-12-01")
            credits.unit = "chars"
            credits.remaining = short ? 88 : 1236
            credits.resets_day = "1 december"
            credits.subscription = DrillQuota.Subscription(active: name.hasPrefix("repShopWeekly"), until: "2026-11-24T10:00:00.000Z",
                                                           week_used: name.hasPrefix("repShopWeekly") ? 3800 : 0, week_limit: 20_000)
            if name.hasPrefix("repShopWeekly") { credits.remaining = 17_436 }
            if name == "repShopWelcome" { // Ke77 §1b: a new account, only its welcome credits
                credits.remaining = 5000
                credits.gift = DrillQuota.Gift(left: 5000, welcome: 5000, invite: 0)
            }
            model.quota = credits
            let server = StagedPurchaseServer()
            server.rewarded = name == "repShopReward"
            let shopDefaults = UserDefaults(suiteName: "screenshot-shop") ?? .standard
            shopDefaults.removeObject(forKey: CreditShop.seenRewardKey)
            let front = StagedStoreFront()
            front.isEmpty = name == "repShopEmpty"
            let shop = CreditShop(front: front, server: server, defaults: shopDefaults)
            model.shop = shop
            Task { await shop.load() }
            SayText.stagedForScreenshots = ["repShopShort", "repShopWeeklyHome", "repShopRefused"].contains(name) ? said : nil
            // Kelly (kop.md §2): after the server's 402 the row is the same as before it.
            SayText.stagedRefusal = name == "repShopRefused"
                ? "Det här kostar 120 krediter. Du har 88 kvar. Nya krediter den 1 december." : nil
            SayText.stagedCost = 120
            return
        }
        SayText.stagedPicked = nil
        UserDefaults.standard.removeObject(forKey: SayText.mixKey)
        if name == "repSayStyle" || name == "repSayVoices" || name == "repSayPicked" { // A136 (D220, Kelly Ke75), A140
            model.store.save(history)
            model.store.save(drill)
            var credits = DrillQuota(used: 264, limit: 1500, per: "month", resets: "2026-12-01")
            credits.unit = "chars"
            credits.remaining = 1236
            model.quota = credits
            model.stageSayVoices([
                SayVoice(voice_id: "astrid0000000001", name: "Astrid", preview_url: "https://example.com/astrid.mp3", description: "Lugn, rikssvenska"),
                SayVoice(voice_id: "elsa00000000002", name: "Elsa", preview_url: "https://example.com/elsa.mp3", description: "Ung, glad"),
                SayVoice(voice_id: "gustav000000003", name: "Gustav", preview_url: "https://example.com/gustav.mp3", description: "Mörk, tydlig"),
                SayVoice(voice_id: "nils000000000004", name: "Nils", preview_url: "https://example.com/nils.mp3", description: "Skånska"),
                SayVoice(voice_id: "maja000000000005", name: "Maja", preview_url: "https://example.com/maja.mp3", description: "Göteborgska"),
                SayVoice(voice_id: "hindi00000000006", name: "Hindi", preview_url: "https://example.com/hindi.mp3", description: "Svenska med indisk brytning", review: true),
            ], defaultName: "Astrid")
            if name == "repSayPicked" { // A140 (K99): no voice chosen, a style: the server chose Gustav
                SayText.stagedPicked = ("gustav000000003", "Mörk och tydlig, passar en lärare.")
            } else {
                UserDefaults.standard.set("astrid0000000001", forKey: SayText.voiceKey)
                UserDefaults.standard.set(true, forKey: SayText.inPaceKey)
            }
            SayText.stagedForScreenshots = said
            SayText.stagedStyle = "Lugnt, som en lärare"
            SayText.stagedVoicesSheet = name == "repSayVoices"
            SayText.stagedRefusal = nil
            SayText.stagedCost = 120 // K92: a new voice or style is new sound
            return
        }
        if name == "repSayUnlimited" { // A133 (D216): the owner's account has no limit
            model.store.save(history)
            model.store.save(drill)
            var credits = DrillQuota(used: 0, limit: 1500, per: "month", resets: "2026-12-01")
            credits.unit = "chars"
            credits.unlimited = true
            model.quota = credits
            SayText.stagedForScreenshots = said
            SayText.stagedRefusal = nil
            SayText.stagedCost = nil
            return
        }
        if name == "repSayCredits" || name == "repSayCreditsShort" || name == "repCreditsSheet" { // A131 (D213)
            model.store.save(history)
            model.store.save(drill)
            var credits = DrillQuota(used: name == "repSayCreditsShort" ? 1412 : 264, limit: 1500, per: "month", resets: "2026-12-01")
            credits.unit = "chars"
            credits.remaining = name == "repSayCreditsShort" ? 88 : 1236
            credits.resets_day = "1 december"
            model.quota = credits
            SayText.stagedForScreenshots = name == "repCreditsSheet" ? nil : said
            SayText.stagedRefusal = nil
            SayText.stagedCost = 120 // K92: what the server would answer for this text
            return
        }
        if name == "repCredits" || name == "repHomeCredits" { // A117
            model.store.save(history)
            model.store.save(drill)
            model.quota = quotaWithPrices
            if name == "repHomeCredits" { // Kelly G4 (A132): Start is shown in credits now (D213)
                var credits = DrillQuota(used: 264, limit: 1500, per: "month", resets: "2026-12-01")
                credits.unit = "chars"
                credits.remaining = 1236
                model.quota = credits
            }
            return
        }
        if name.hasPrefix("repSay") { // A115 (D203)
            model.store.save(history)
            model.store.save(drill)
            model.quota = DrillQuota(used: 3, limit: 15, resets: "2026-12-01", serverLeft: 12, suggest: 12)
            SayText.stagedForScreenshots = name == "repSayText" || name == "repSayRefused" ? said : nil
            // A130 (D212): the server refused Spela (402); its words and when the month is filled up.
            SayText.stagedRefusal = name == "repSayRefused"
                ? SaidText.refusalLine(problem: "Du har gjort 15 av 15 frågor med ljud den här månaden.", quotaExceeded: true,
                                       refill: RepetitionModel.refillLine("2026-12-01"))
                : nil
            if name == "repSayRefused" {
                model.quota = DrillQuota(used: 15, limit: 15, resets: "2026-12-01", serverLeft: 0, suggest: 0)
                return
            }
            guard name != "repSayText" else { return }
            let text = Drill.text(title: SaidText.title(said), summary: DrillSummary(subject: "", grade: "", covers: ""),
                                  parts: SaidText.parts(said).map { DrillItem.textPart($0, part: .para) })
            let reader = ReadingPlayer(parts: text.readingParts, audio: { _ in nil }, source: FileRepetitionAudioSource(),
                                       timer: TaskRepetitionTimer())
            // Toby (T36 after K100): the card says "Gör ljudet …" before there is any sound; after 8 s the line (D225).
            let waits = name == "repSayOnCardWaiting"
            reader.stageForScreenshot(waits ? .waitingForAudio : .reading, sentence: waits ? 0 : 1)
            let goesRound = name == "repSayPlay" || name == "repSayOnCard" || waits
            model.session.stageSaying(text, reader: reader, minutes: goesRound ? 10 : nil, lap: goesRound && !waits ? 3 : 1, waiting: waits)
            SayText.stagedWaitNote = waits ? SayText.slowServerLine : nil
            if name == "repSayOnCard" || waits { // A132 (D215.6, Ke72): it plays on the card on Start
                model.stageSayVoices([], defaultName: "Astrid") // A140 (D223): the voice that speaks is named
                var credits = DrillQuota(used: 264, limit: 1500, per: "month", resets: "2026-12-01")
                credits.unit = "chars"
                credits.remaining = 1236
                model.quota = credits
            }
            return
        }
        if name.hasPrefix("repOff") { // A112 (D200): the voice service is out
            let staged = model.audio as? DeviceVoiceDrillAudio
            if name == "repOffUnstarted" {
                model.store.save(unstarted)
                staged?.stagedProblems[unstarted.id] = CloudDrillAudio.unavailableLine
                return
            }
            model.store.save(reading) // no files: the text is here, its sound is not
            staged?.stagedProblems[reading.id] = CloudDrillAudio.unavailableLine
            guard name == "repOffTextPlay" else { return }
            let reader = ReadingPlayer(parts: reading.readingParts, audio: { _ in nil }, source: FileRepetitionAudioSource(),
                                       timer: TaskRepetitionTimer())
            reader.stageForScreenshot(.waitingForAudio, sentence: 5)
            model.session.stageForScreenshot(reading, reader: reader)
            return
        }
        if name.hasPrefix("repUnstarted") || name == "repHomeUnstarted" { // A107: the newest exam
            model.store.save(unstarted)
            if name == "repUnstartedText" { // A110
                var text = reading
                text.audioStarted = false
                model.store.save(text)
            }
            // Kelly Ke64b N1: what starting counts as, and a month that does not cover it.
            let left = name == "repUnstartedTooMany" ? 1 : 12
            model.quota = DrillQuota(used: 15 - left, limit: 15, resets: "2026-12-01", serverLeft: left, suggest: left)
            return
        }
        if name.hasPrefix("repText") || name == "repHomeText" { // A106: the text is the newest exam, with its sound
            model.store.save(reading)
            if name != "repTextMaking", let audio = model.audio as? DeviceVoiceDrillAudio {
                for item in reading.items {
                    try? WAVWriter.write(samples: [Int16](repeating: 0, count: 1_600), sampleRate: 16_000, to: audio.url(text: item.long))
                }
            }
            if name == "repHomeText" { UserDefaults.standard.set(true, forKey: "repetition.controlsChecked") }
            let reader = ReadingPlayer(parts: reading.readingParts, audio: { _ in nil }, source: FileRepetitionAudioSource(),
                                       timer: TaskRepetitionTimer())
            switch name {
            case "repTextPlay": reader.stageForScreenshot(.reading, sentence: 5)
            case "repTextPaused": reader.stageForScreenshot(.reading, sentence: 5, paused: true)
            case "repTextEnd": reader.stageForScreenshot(.atEnd, sentence: 10)
            case "repTextWaiting": reader.stageForScreenshot(.waitingForAudio, sentence: 7)
            default: return
            }
            model.session.stageForScreenshot(reading, reader: reader)
            return
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

    /// A106: Nytt prov with Läs upp texten chosen, or its "Stämmer det här?".
    static func readingForm(_ model: RepetitionModel, _ staged: NewDrillView.StagedReading) -> NewDrillView {
        var view = NewDrillView(model: model) { _ in }
        view.stagedReading = staged
        return view
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
            case "repReminderAsk":
                Color(.systemGroupedBackground).ignoresSafeArea()
                    .sheet(isPresented: .constant(true)) {
                        PracticeReminderQuestion(model: model)
                    }
            case "repReminderSettings", "repReminderDenied":
                NavigationStack {
                    Form { PracticeReminderSection(model: model, stagedDenied: name == "repReminderDenied") }
                        .navigationTitle("Inställningar")
                        .navigationBarTitleDisplayMode(.inline)
                }
            case "repUnstartedText", "repOffText": NavigationStack { DrillView(model: model, drillID: reading.id) }
            case "repOffUnstarted": NavigationStack { DrillView(model: model, drillID: unstarted.id) }
            case "repOffTextPlay": RepetitionPlayerView(model: model)
            case "repUnstarted", "repUnstartedTooMany": NavigationStack { DrillView(model: model, drillID: unstarted.id) }
            case "repUnstartedEdit": DrillItemEditor(model: model, drill: unstarted, itemID: unstarted.items[0].id)
            case "repCredits", "repCreditsSheet", "repShop", "repShopWeekly", "repShopWelcome", "repShopReward", "repShopEmpty":
                Color(.systemGroupedBackground).ignoresSafeArea()
                    .sheet(isPresented: .constant(true)) { CreditsSheet(model: model) }
            case "repSayPlay", "repSayPlayOnce": RepetitionPlayerView(model: model)
            case "repHome", "repHomeEmpty", "repHomeNew", "repHomeStarted", "repHomeSoundProblem", "repHomeText", "repHomeUnstarted",
                 "repSayText", "repSayRefused", "repHomeCredits", "repSayCredits", "repSayCreditsShort",
                 "repHomeSaid", "repHomeSaidOnly", "repSayOnCard", "repSayUnlimited", "repSayStyle", "repSayVoices",
                 "repShopShort", "repShopWeeklyHome", "repSayPicked", "repSaySlow", "repSayNoNet", "repSayBig", "repHomeSaidMarks",
                 "repSayWaiting", "repShopRefused", "repSayOnCardWaiting":
                NavigationStack { HomeView(model: listening) }
            // A106 (Kelly Ke63): Läs upp texten
            case "repTextNew": readingForm(model, .choice)
            case "repTextConfirm":
                readingForm(model, .confirm(DrillTextDraft(title: reading.title, summary: reading.summary, parts: reading.items,
                                                           chars: 620, countsAs: 1)))
            case "repText", "repTextMaking": NavigationStack { DrillView(model: model, drillID: reading.id) }
            case "repTextPlay", "repTextPaused", "repTextEnd", "repTextWaiting": RepetitionPlayerView(model: model)
            case "repTextControls":
                ControlCheckView(hub: RemoteCommandHub(), sound: nil, waitSeconds: 3600, forText: true, onStart: {}, onLater: {})
            case "repSoundProblem": NavigationStack { DrillView(model: model, drillID: history.id) }
            case "repSoundProblemNone": NavigationStack { DrillView(model: model, drillID: chemistry.id) }
            case "repQuotaUsedUp", "repNewOffline": NewDrillView(model: model) { _ in }
            case "repSchoolsOffline", "repSchoolsFailed": NavigationStack { SchoolExamsView(model: model) }
            case "repSchoolSearchNone", "repSchoolSearchFailed":
                SchoolPicker(model: model, title: "Välj skola", selected: nil, onSkip: nil, stagedQuery: "Kungsh", onPick: { _ in })
            case "repPublishFailed":
                PublishSheet(model: model, drill: drill, stagedProblem: "Det gick inte att publicera just nu. Försök igen om en stund.")
            case "repSoundMaking": NavigationStack { DrillView(model: model, drillID: chemistry.id) }
            case "repQuotaExam": NavigationStack { DrillView(model: model, drillID: history.id) }
            case "repExamOffline": NavigationStack { DrillView(model: model, drillID: drill.id) }
            case "repHelpTryUsedUp": // the pushed stack showed an empty page in the pictures (43707813309)
                NavigationStack { HelpTryView(model: model) {} }
            case "repLength": NavigationStack { DrillView(model: model, drillID: drill.id) }
            case "repLengthEdit": DrillItemEditor(model: model, drill: drillWithLengths, itemID: drill.items[2].id)
            case "repNumbers": NavigationStack { DrillView(model: model, drillID: maths.id) }
            case "repNumbersEdit": DrillItemEditor(model: model, drill: maths, itemID: maths.items[1].id)
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
                             display_name: "plugghajen",
                             // A87 point 5 (Kelly P1, K65): the preview Angela Fable's section shows.
                             preview: [.init(question: "Vad är fotosyntes?", short: "Växter gör socker av ljus, vatten och koldioxid."),
                                       .init(question: "Var sker fotosyntesen?", short: "I kloroplasterna i bladens celler."),
                                       .init(question: "Vad behövs för cellandning?", short: "Socker och syre."),
                                       .init(question: "Vad är en ekosystemtjänst?", short: "Något naturen gör som vi har nytta av.")],
                             first_audio_url: "https://example.com/demo/forsta-fragan.mp3"), // shown only, never played
        DrillPublicationView(id: "p2", title: "Andra världskriget", subject: "Historia", school: school,
                             exam_date: DrillPublishing.dayString(Date().addingTimeInterval(12 * 86_400)), items: 15,
                             display_name: nil),
        DrillPublicationView(id: "p3", title: "Ekvationer", subject: "Matematik", school: school,
                             exam_date: DrillPublishing.dayString(Date().addingTimeInterval(-40 * 86_400)), items: 12,
                             display_name: nil),
    ]
    let empty: Bool
    /// A104: every call fails with this (no network, the server down).
    let failure: DrillCloudError?
    /// A104: the school search finds nothing.
    let noSchools: Bool

    init(empty: Bool, failure: DrillCloudError? = nil, noSchools: Bool = false) {
        self.empty = empty
        self.failure = failure
        self.noSchools = noSchools
    }

    static func failure(for scene: String) -> DrillCloudError? {
        switch scene {
        case "repSchoolsOffline": .offline("screenshots")
        case "repSchoolsFailed", "repSchoolSearchFailed", "repPublishFailed":
            .refused(status: 503, code: "unavailable", message: "Ingen kontakt med EarMind just nu. Försök igen om en stund.")
        default: nil
        }
    }

    func schools(matching query: String) async throws(DrillCloudError) -> [DrillSchool] {
        if let failure { throw failure }
        return noSchools ? [] : [Self.school]
    }
    func publish(drillID: String, school: DrillSchool, subject: String, examDate: Date,
                 displayName: String?) async throws(DrillCloudError) -> DrillPublicationView {
        if let failure { throw failure }
        return Self.results[0]
    }
    func unpublish(drillID: String) async throws(DrillCloudError) {}
    func search(school: DrillSchool?, subject: String?, mySchool: DrillSchool?) async throws(DrillCloudError) -> [DrillPublicationView] {
        if let failure { throw failure }
        return empty ? [] : Self.results
    }
    func importPublication(id: String) async throws(DrillCloudError) -> DrillCloudView {
        throw .offline("screenshots")
    }
    func report(publicationID: String, reason: DrillReportReason) async throws(DrillCloudError) {}
    func played(drillID: String) async {}
}
#endif
