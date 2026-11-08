import Foundation
import Testing
@testable import Lumen

/// A fake voice model: quiet audio is one voice, loud audio another, so tests can play two people.
struct FakeEmbedding: SpeakerEmbedding {
    var quiet: [Float] = [0, 1, 0]
    var loud: [Float] = [0, 0, 1]

    func embedding(_ samples: [Float]) async throws -> [Float] {
        let peak = samples.map(abs).max() ?? 0
        return peak > 0.2 ? loud : quiet
    }
}

/// One second of a tone into the fake capture's ring buffer (its capacity), at `amplitude` of full scale.
func playTone(_ capture: FakeCaptureService, amplitude: Double) {
    let samples = (0..<16_000).map { i in Int16(amplitude * 32_767 * sin(Double(i) * 2 * .pi * 220 / 16_000)) }
    capture.ringBuffer.write(samples)
}

func tempDirectory(_ name: String) -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "lumen-\(name)-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite struct SpeakerLabelerTests {
    private let wearer = VoiceProfile(embedding: [1, 0, 0], createdAt: Date(), seconds: 10)

    @Test func theProfileTellsTheWearerFromOthers() {
        #expect(SpeakerLabeler.match([0.9, 0.1, 0], profile: wearer) == .wearer)
        #expect(SpeakerLabeler.match([0, 1, 0], profile: wearer) == .other(label: nil))
        #expect(SpeakerLabeler.match([0.4, 0.7, 0.6], profile: wearer) == .uncertain, "too close to call")
        #expect(SpeakerLabeler.match([1, 0, 0], profile: nil) == .uncertain, "no profile, no verdict")
    }

    @Test func otherVoicesGetNumbersThatStay() {
        var labeler = SpeakerLabeler()
        #expect(labeler.assign([1, 0, 0], profile: wearer) == .wearer)
        #expect(labeler.assign([0, 1, 0], profile: wearer) == .other(label: 1))
        #expect(labeler.assign([0, 0, 1], profile: wearer) == .other(label: 2))
        #expect(labeler.assign([0.05, 0.95, 0.05], profile: wearer) == .other(label: 1), "the same voice again")
        #expect(SpeakerLabeler.text(.wearer, swedish: true) == "Du")
        #expect(SpeakerLabeler.text(.other(label: 2), swedish: true) == "Talare 2")
        #expect(SpeakerLabeler.text(.uncertain, swedish: true) == nil)
    }

    @Test func theMeanIsNormalised() throws {
        let mean = try #require(VoiceMath.mean([[1, 0], [0, 1]]))
        #expect(abs(mean[0] - 0.7071) < 0.001)
        #expect(abs(VoiceMath.similarity(mean, [1, 1]) - 1) < 0.001)
    }

    @Test func theResourceLineReadsWell() {
        let start = ResourceSample(at: Date(timeIntervalSince1970: 0), cpuSeconds: 10, battery: 0.80)
        let end = ResourceSample(at: Date(timeIntervalSince1970: 600), cpuSeconds: 40, battery: 0.77)
        #expect(ResourceSample.line(from: start, to: end) == "CPU 5.0 % · battery -3 % · 10 min")
    }

    @Test func aLabelGoesOnTheSegmentItBelongsTo() {
        var conversation = Conversation()
        let t0 = Date()
        conversation.finalize("hej", at: t0)
        conversation.label("Talare 1", near: t0.addingTimeInterval(0.5))
        conversation.finalize("hallå", at: t0.addingTimeInterval(2))
        conversation.label("Du", near: t0.addingTimeInterval(2.4))
        #expect(conversation.finalSegments.map(\.speakerLabel) == ["Talare 1", "Du"])
    }
}

@MainActor
@Suite struct VoiceProfileStoreTests {
    @Test func theProfileIsSavedOnThePhoneAndDeleted() async {
        let file = tempDirectory("voice").appending(path: "profile.json")
        let loader = SpeakerEmbedderLoader()
        loader.use(FakeEmbedding())
        let identifier = SpeakerIdentifier(loader: loader, profiles: VoiceProfileStore(file: file), defaults: freshTestDefaults())
        let tone = (0..<160_000).map { i in Int16(3_000 * sin(Double(i) * 2 * .pi * 220 / 16_000)) }

        let result = await identifier.enroll(tone)

        #expect(result == .saved(seconds: 9.75), "four overlapping 3 s windows over 0–9.75 s")
        #expect(VoiceProfileStore(file: file).profile?.embedding == [0, 1, 0], "read back from disk")
        let values = try? file.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values?.isExcludedFromBackup == true, "never in a backup")
        identifier.deleteProfile()
        #expect(VoiceProfileStore(file: file).profile == nil)
    }

    @Test func silenceIsNoProfile() async {
        let loader = SpeakerEmbedderLoader()
        loader.use(FakeEmbedding())
        let identifier = SpeakerIdentifier(loader: loader, profiles: VoiceProfileStore(file: tempDirectory("voice").appending(path: "p.json")),
                                           defaults: freshTestDefaults())
        #expect(await identifier.enroll([Int16](repeating: 0, count: 160_000)) == .tooLittleSpeech)
        #expect(!identifier.profiles.isEnrolled)
    }

    @Test func bargeInChecksTheVoice() async {
        let loader = SpeakerEmbedderLoader()
        loader.use(FakeEmbedding())
        let profiles = VoiceProfileStore(file: tempDirectory("voice").appending(path: "p.json"))
        let identifier = SpeakerIdentifier(loader: loader, profiles: profiles, defaults: freshTestDefaults())
        let quiet = (0..<16_000).map { i in Int16(3_000 * sin(Double(i) / 10)) }
        #expect(await identifier.isWearer(quiet) == nil, "no profile: the level decides")
        profiles.save(VoiceProfile(embedding: [0, 1, 0], createdAt: Date(), seconds: 10))
        #expect(await identifier.isWearer(quiet) == true)
        let loud = (0..<16_000).map { i in Int16(20_000 * sin(Double(i) / 10)) }
        #expect(await identifier.isWearer(loud) == false)
    }
}

@MainActor
func freshTestDefaults() -> UserDefaults {
    let suite = "lumen.tests.d81.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@MainActor
@Suite struct SpeakerFlowTests {
    private struct Rig {
        let h: ControllerHarness
        let provider: FakeAnswerProvider
        let model: ListeningModel
        let apple: FakeTTSProvider
        let speakers: SpeakerIdentifier
        let cards: StudyCardStore
    }

    private func makeRig(profile: [Float]?, events: [AnswerEvent] = [.delta("Tio. "), .done(AnswerDone(answered: true))]) -> Rig {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: events)
        let apple = FakeTTSProvider(name: "apple")
        let defaults = freshTestDefaults()
        let loader = SpeakerEmbedderLoader()
        loader.use(FakeEmbedding())
        let profiles = VoiceProfileStore(file: tempDirectory("voice").appending(path: "p.json"))
        if let profile { profiles.save(VoiceProfile(embedding: profile, createdAt: Date(), seconds: 10)) }
        let speakers = SpeakerIdentifier(loader: loader, profiles: profiles, defaults: defaults)
        let cards = StudyCardStore(directory: tempDirectory("cards"))
        let settings = ModeSettings(defaults: defaults)
        settings.interviewSetup = "Säljare på Volvo"
        let studyProfile = StudyProfileStore(defaults: defaults)
        studyProfile.profile.onboarded = true
        studyProfile.profile.subject = "Biologi"
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   study: StudySessionController(settings: StudySettings(defaults: defaults), session: h.controller),
                                   memory: makeTestMemory(), modeSettings: settings, studyProfile: studyProfile,
                                   speakers: speakers, studyCards: cards)
        return Rig(h: h, provider: provider, model: model, apple: apple, speakers: speakers, cards: cards)
    }

    private func spoken(_ rig: Rig) -> [String] { rig.apple.calls.map(\.text) }

    /// Lumen has finished speaking and the recogniser is open again (D82: 0.7 s after the voice), so a turn now is
    /// the wearer's and is not cut off by speech that is still to start.
    private func waitForTheWearersTurn(_ rig: Rig) async -> Bool {
        guard await waitUntil({ !rig.model.speaker.isSpeaking && !rig.model.speaker.hasPendingSpeech }) else { return false }
        try? await Task.sleep(for: .milliseconds(900))
        return await waitUntil { rig.model.study.phase == .listening && !rig.model.speaker.isSpeaking }
    }

    /// One hands-free turn at `level`, ended a moment ago.
    private func speak(_ text: String, level: Double, rig: Rig) {
        var time = Date().addingTimeInterval(-3)
        for _ in 0..<15 {
            rig.model.study.level(level, at: time)
            time = time.addingTimeInterval(0.04)
        }
        rig.model.receiveFinalTranscript(text, at: time)
        for _ in 0..<45 {
            rig.model.study.level(-70, at: time)
            time = time.addingTimeInterval(0.04)
        }
    }

    @Test func autoNeverAnswersTheWearer() async {
        let rig = makeRig(profile: [0, 1, 0]) // the quiet voice is the wearer
        await rig.model.startListening()
        playTone(rig.h.capture, amplitude: 0.1)
        rig.speakers.identify(rig.h.capture.ringBuffer.snapshot(last: 16_000), at: Date())
        #expect(await waitUntil { rig.speakers.identity(near: Date()) == .wearer })

        rig.model.receiveFinalTranscript("vad är roten ur hundra", at: Date())

        try? await Task.sleep(for: .milliseconds(200))
        #expect(spoken(rig).isEmpty, "the wearer's own question is not answered in Auto")
        #expect(rig.model.conversation.answers.isEmpty)
    }

    @Test func autoAnswersSomeoneElse() async {
        let rig = makeRig(profile: [0, 1, 0])
        await rig.model.startListening()
        playTone(rig.h.capture, amplitude: 0.8) // the loud voice is not the wearer
        rig.speakers.identify(rig.h.capture.ringBuffer.snapshot(last: 16_000), at: Date())
        #expect(await waitUntil { rig.speakers.identity(near: Date())?.isOther == true })

        rig.model.receiveFinalTranscript("vad är roten ur hundra", at: Date())

        #expect(await waitUntil { spoken(rig) == ["Tio."] })
    }

    @Test func theTranscriptSaysWhoSpoke() async {
        let rig = makeRig(profile: [0, 1, 0])
        await rig.model.startListening()
        playTone(rig.h.capture, amplitude: 0.1)
        rig.model.receiveSentenceHeard("jag har läst kapitel tre", at: Date())
        #expect(await waitUntil { rig.speakers.identity(near: Date()) == .wearer })
        rig.model.receiveFinalTranscript("jag har läst kapitel tre", at: Date())

        playTone(rig.h.capture, amplitude: 0.8)
        rig.model.receiveSentenceHeard("bra jobbat med läxan", at: Date())
        #expect(await waitUntil { rig.speakers.identity(near: Date())?.isOther == true })
        rig.model.receiveFinalTranscript("bra jobbat med läxan", at: Date())

        #expect(rig.model.conversation.finalSegments.map(\.speakerLabel) == ["Du", "Talare 1"])
    }

    @Test func theInterviewGoesByTheVoiceOverTheLevel() async {
        let rig = makeRig(profile: [0, 1, 0])
        await rig.model.startHandsFree(.interview)
        rig.model.study.level(-70, at: Date())
        playTone(rig.h.capture, amplitude: 0.1)
        rig.speakers.identify(rig.h.capture.ringBuffer.snapshot(last: 16_000), at: Date())
        #expect(await waitUntil { rig.speakers.identity(near: Date()) == .wearer })

        speak("Jag har jobbat med försäljning i fem år", level: -45, rig: rig) // quiet: by level the interviewer

        try? await Task.sleep(for: .milliseconds(200))
        #expect(spoken(rig).isEmpty, "the wearer's own answer is never answered")
    }

    @Test func theWearerSaysWhatTheyStudy() async {
        let rig = makeRig(profile: nil)
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, jag går i åk 9 och ska snart ha prov i biologi", at: Date())

        #expect(await waitUntil { spoken(rig).contains("Biologi åk 9, sparat.") }, "D84: confirmed at once, by the phone")
        #expect(rig.model.studyProfile.profile.grade == .y9)
        #expect(rig.provider.requests.isEmpty, "a statement is never a question")
    }

    @Test func provlageAnswersBecomeStudyCards() async {
        let rig = makeRig(profile: nil, events: [.delta("Fotosyntes är när växter gör socker av ljus. "), .done(AnswerDone(answered: true))])
        await rig.model.startStudy()
        rig.model.study.level(-70, at: Date())
        speak("Vad är fotosyntes för något", level: -25, rig: rig)

        #expect(await waitUntil { rig.cards.cards.count == 1 })
        #expect(rig.cards.cards[0].question == "Vad är fotosyntes för något")
        #expect(rig.cards.cards[0].subject == "Biologi")
    }

    @Test func theMiniTestAsksGradesAndMovesOn() async {
        let rig = makeRig(profile: nil, events: [.delta("Rätt. Bra förklarat. "), .done(AnswerDone(answered: true))])
        rig.cards.add(question: "Vad är fotosyntes för något", answer: "Växter gör socker av ljus och koldioxid.", profile: StudyProfile())
        rig.cards.add(question: "Vad gör mitokondrien i cellen", answer: "Den gör energi åt cellen genom cellandning.", profile: StudyProfile())

        await rig.model.startMiniTest()

        #expect(rig.model.study.isActive)
        #expect(await waitUntil { spoken(rig).first?.hasPrefix("Fråga 1 av 2") == true })
        #expect(await waitForTheWearersTurn(rig), "the question was read and the microphone is open again")
        speak("växter gör socker av solljus", level: -25, rig: rig)

        #expect(await waitUntil { rig.provider.requests.count == 1 })
        guard rig.provider.requests.count == 1 else { return }
        #expect(rig.provider.requests[0].fragment.contains("Minitest"))
        #expect(rig.provider.requests[0].fragment.contains("växter gör socker av solljus"))
        #expect(await waitUntil { spoken(rig).contains { $0.hasPrefix("Fråga 2 av 2") } })
        #expect(rig.cards.cards.reduce(0) { $0 + $1.right } == 1)

        #expect(await waitForTheWearersTurn(rig))
        speak("vet inte", level: -25, rig: rig)

        #expect(await waitUntil { spoken(rig).contains("Klart. 1 av 2 rätt.") })
        #expect(rig.model.miniTest == nil)
        #expect(rig.provider.requests.count == 1, "a skipped question needs no call")
        #expect(rig.cards.cards.count == 2, "the grading is no new card")
    }
}

@Suite struct StudyCardTests {
    @Test func aCardKeepsTwoSentences() {
        #expect(StudyCard.shortAnswer("Ett. Två. Tre.") == "Ett. Två.")
        #expect(StudyCard.isWorthACard(question: "Vad är fotosyntes för något", answer: "Växter gör socker av ljus."))
        #expect(!StudyCard.isWorthACard(question: "Ja", answer: "Bra, då går vi vidare till nästa."))
    }

    @Test func cardsLastUntilTheExamIsOver() {
        let exam = Date(timeIntervalSince1970: 1_000_000)
        let card = StudyCard(question: "Vad är en cell", answer: "Livets minsta del.", subject: nil, examDate: exam)
        #expect(card.isCurrent(now: exam.addingTimeInterval(-3_600)))
        #expect(!card.isCurrent(now: exam.addingTimeInterval(2 * 86_400)))
    }

    @MainActor @Test func theMiniTestStartsWithTheLastSession() {
        let store = StudyCardStore(directory: tempDirectory("cards"))
        let old = Date().addingTimeInterval(-7_200)
        store.add(question: "Vad är en atom egentligen", answer: "Den minsta delen av ett grundämne.", profile: StudyProfile(), now: old)
        let start = Date().addingTimeInterval(-600)
        store.add(question: "Vad är en molekyl egentligen", answer: "Atomer som sitter ihop med bindningar.", profile: StudyProfile())
        store.add(question: "Vad är en molekyl egentligen?", answer: "Samma fråga igen, ska inte bli ett nytt kort.", profile: StudyProfile())
        #expect(store.cards.count == 2, "the same question once")
        #expect(store.miniTest(sessionStart: start).map(\.question) == ["Vad är en molekyl egentligen", "Vad är en atom egentligen"])
    }

    @Test func gradingAndCommands() {
        var test = MiniTest(cards: [StudyCard(question: "Vad är en cell", answer: "Livets minsta del.", subject: nil, examDate: nil)])
        #expect(test.question(swedish: true) == "Fråga 1 av 1: Vad är en cell")
        test.graded("Rätt, bra.")
        #expect(test.isFinished && test.rightCount == 1)
        #expect(MiniTest.isStartCommand("minitest"))
        #expect(!MiniTest.isStartCommand("förhör mig på biologin"), "D86: förhör mig is one check question")
        #expect(MiniTest.isCheckQuestionRequest("förhör mig på biologin"))
        #expect(MiniTest.isSkip("Vet inte."))
        #expect(!MiniTest.isSkip("vet inte riktigt men det är socker"))
    }
}

@Suite struct InterviewProfileTests {
    @Test func contactDetailsNeverLeaveThePhone() {
        let cv = "Anna Svensson, anna.svensson@mail.se, 070-123 45 67, 19900101-1234, Storgatan 12, 123 45 Malmö. Säljare på Ikea 2015-2020. Teamledare 2020–2024."
        let clean = InterviewProfile.withoutContactDetails(cv)
        #expect(!clean.contains("@"))
        #expect(!clean.contains("070"))
        #expect(!clean.contains("1234"))
        #expect(!clean.contains("Storgatan"))
        #expect(!clean.contains("Malmö"))
        #expect(clean.contains("2015-2020"), "years stay")
        #expect(clean.contains("Teamledare"))
    }

    @Test func theSetupFitsTheLimit() {
        let ad = String(repeating: "Vi söker en säljare. ", count: 80)
        let cv = String(repeating: "Jag har sålt bilar i tio år. ", count: 120)
        let setup = InterviewProfile.setup(jobAd: ad, cv: cv)
        #expect(setup.count <= InterviewProfile.setupLimit)
        #expect(setup.hasPrefix("Jobbannons: "))
        #expect(setup.contains("CV: Jag har sålt bilar"))
        #expect(InterviewProfile.setup(jobAd: "Säljare\npå Volvo", cv: "") == "Säljare\npå Volvo", "no CV: as before")
    }
}

/// Kevin's D81 contracts: labels to Socialt/Rizz, `interrupted`, `/study-cards`.
@Suite struct BackendD81ContractTests {
    @Test func anInterruptedAnswerKeepsWhatWasSaid() throws {
        var conversation = Conversation()
        conversation.beginAnswer(question: "Vad är fotosyntes", source: "cloud")
        conversation.appendAnswerText("Fotosyntes är när växter gör socker. Det sker i kloroplasterna.")
        conversation.interruptAnswer(said: "Fotosyntes är när växter gör socker. ")
        let qa = try #require(conversation.recentQA().last)
        #expect(qa.a == "Fotosyntes är när växter gör socker.")
        #expect(qa.interrupted == true)
        let json = String(data: try JSONEncoder().encode(AnswerContext.QA(q: "a", a: "b")), encoding: .utf8) ?? ""
        #expect(!json.contains("interrupted"), "only sent when true")
    }

    @Test func liveLinesCarryTheSpeakerLabel() {
        var session = RizzSession(style: .social)
        session.add(.other, text: "Ska du komma och heja på mig?", at: Date(), label: "Talare 1")
        session.add(.user, text: "Självklart", at: Date(), label: "Du")
        #expect(session.transcript.map(\.label) == ["Talare 1", nil], "the wearer's line needs no label")
        let persona = LiveRequest.suggestions(for: session, trigger: "other_spoke", interests: [], profile: "",
                                              calibration: nil, adultConfirmed: false)
        #expect(persona?.social?.speaker == "Talare 1")
    }

    @Test func theStudyCardRequestFitsTheLimits() throws {
        let turns = (0..<200).map { (question: "Fråga nummer \($0) om biologi", answer: String(repeating: "svar ", count: 20)) }
        let body = try #require(StudyCardsRequest.body(turns: turns, profile: "Prov i Biologi", swedish: true))
        #expect(body.summary.count <= StudyCardsRequest.summaryLimit)
        #expect(body.summary.contains("Fråga nummer 199"), "the newest turns are kept")
        #expect(body.cards == 12)
        #expect(StudyCardsRequest.body(turns: [], profile: nil, swedish: true) == nil)
    }

    @MainActor @Test func theBackendsTestIsUsedOnce() {
        let store = StudyCardStore(directory: tempDirectory("cards"))
        let reply = StudyCardsReply(cards: [.init(q: "Var sker fotosyntesen?", a: "I kloroplasterna.")],
                                    test: (1...5).map { .init(q: "Testfråga \($0)", a: "Svar \($0)") })
        store.addRemote(reply, profile: StudyProfile())
        #expect(store.cards.map(\.question) == ["Var sker fotosyntesen?"])
        #expect(store.takeTest(sessionStart: nil).map(\.question).first == "Testfråga 1")
        #expect(store.takeTest(sessionStart: nil).map(\.question) == ["Var sker fotosyntesen?"], "then the cards")
    }
}
