import Foundation
import Testing
@testable import Lumen

/// D83: Provläge's first-start profile, voice changes, nod/shake, the subscription flag.
@Suite struct StudyProfileTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }
    /// Sunday 8 November 2026, noon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))! }

    @Test func quickAnswersBecomeAbsoluteDates() {
        let tomorrow = StudyProfile.examDate(for: .tomorrow, now: now, calendar: calendar)!
        #expect(calendar.component(.day, from: tomorrow) == 9)
        let week = StudyProfile.examDate(for: .withinWeek, now: now, calendar: calendar)!
        #expect(calendar.component(.day, from: week) == 15)
        #expect(StudyProfile.examDate(for: .none, now: now, calendar: calendar) == nil)
    }

    @Test func theSetupTextCarriesEverythingAnswered() throws {
        var profile = StudyProfile()
        profile.examDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13))
        profile.subject = "Biologi"
        profile.grade = .gy2
        profile.course = "Biologi 1"
        profile.checkQuestions = .yesNo
        profile.explanations = .short
        let text = try #require(profile.setupText(now: now, calendar: calendar))
        #expect(text.contains("Prov i Biologi fredag 13 november 2026 (om 5 dagar)."))
        #expect(text.contains("Årskurs: Gymnasiet 2, kurs Biologi 1."))
        #expect(text.contains("Ja–nej-frågor"))
        #expect(text.contains("korta förklaringar"))
        #expect(profile.memoryFacts(calendar: calendar).first == "Provprofil: prov i Biologi fredag 13 november 2026")
        #expect(StudyProfile().setupText(now: now, calendar: calendar) == nil, "nothing answered, nothing sent")
    }

    @Test func voiceChangesTheProfile() {
        var profile = StudyProfile()
        #expect(StudyProfileVoice.apply("korta förklaringar", to: &profile, now: now, calendar: calendar))
        #expect(profile.explanations == .short)
        #expect(StudyProfileVoice.apply("inga kontrollfrågor", to: &profile, now: now, calendar: calendar))
        #expect(profile.checkQuestions == StudyProfile.CheckQuestions.none)
        #expect(StudyProfileVoice.apply("ämnet är kemi", to: &profile, now: now, calendar: calendar))
        #expect(profile.subject == "Kemi")
        #expect(StudyProfileVoice.apply("provet är på fredag", to: &profile, now: now, calendar: calendar))
        #expect(calendar.component(.day, from: profile.examDate!) == 13, "the next Friday")
        #expect(StudyProfileVoice.apply("provet är den 20 november", to: &profile, now: now, calendar: calendar))
        #expect(calendar.component(.day, from: profile.examDate!) == 20)
        #expect(!StudyProfileVoice.apply("vad är fotosyntes", to: &profile, now: now, calendar: calendar), "a question stays a question")
    }

    @Test func aNodIsYesAShakeIsNo() {
        var detector = HeadGestureDetector()
        let t0 = Date(timeIntervalSince1970: 1_000)
        var gesture: HeadGestureDetector.Gesture?
        for (i, pitch) in [0.0, 0.1, 0.25, 0.1, 0.0].enumerated() {
            gesture = detector.add(pitch: pitch, yaw: 0, at: t0.addingTimeInterval(Double(i) * 0.15)) ?? gesture
        }
        #expect(gesture == .nod)

        detector.reset()
        gesture = nil
        for (i, yaw) in [0.0, -0.15, -0.3, -0.1, 0.0].enumerated() {
            gesture = detector.add(pitch: 0, yaw: yaw, at: t0.addingTimeInterval(10 + Double(i) * 0.15)) ?? gesture
        }
        #expect(gesture == .shake)
    }

    @Test func justTurningTheHeadIsNoAnswer() {
        var detector = HeadGestureDetector()
        let t0 = Date(timeIntervalSince1970: 2_000)
        var gesture: HeadGestureDetector.Gesture?
        for (i, yaw) in [0.0, 0.1, 0.2, 0.3, 0.35].enumerated() {
            gesture = detector.add(pitch: 0, yaw: yaw, at: t0.addingTimeInterval(Double(i) * 0.15)) ?? gesture
        }
        #expect(gesture == nil, "a turn without coming back")
    }

    @Test func theSubscriptionFlagIsPreparedButOff() {
        #expect(!ModeAccess.liveModesNeedSubscription)
        #expect(ModeAccess.isOpen(.rizz))
        #expect(ModeAccess.isOpen(.social))
    }
}

@MainActor
@Suite struct StudyOnboardingFlowTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.d83.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Ke35 (Toby T8b finding 6): no five questions first; without an exam one question ("Har du prov snart?"), and
    /// "Inte nu" starts Provläge anyway. The profile set in Inställningar goes with every call.
    @Test func provlageAsksAtMostOneThingThenSendsTheProfile() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Bra fråga. "), .done(AnswerDone(answered: true))])
        let defaults = freshDefaults()
        let memory = makeTestMemory()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   study: StudySessionController(settings: StudySettings(defaults: defaults), session: h.controller),
                                   memory: memory, modeSettings: ModeSettings(defaults: defaults),
                                   studyProfile: StudyProfileStore(defaults: defaults))

        var answers = StudyProfile()
        answers.subject = "Biologi"
        answers.examDate = Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date()))
        answers.explanations = .short
        model.studyProfile.profile = answers
        model.studyProfileChanged()

        await model.startProvFromCard()
        #expect(!model.isShowingStudyOnboarding, "Ke35: no five questions")
        #expect(model.isShowingAddExam, "Ke35: one question, only without an exam")
        #expect(!model.study.isActive)
        model.isShowingAddExam = false
        await model.startProvAfterExamStep() // "Inte nu"

        #expect(model.study.isActive, "Inte nu starts Provläge anyway")
        #expect(model.studyProfile.profile.onboarded)
        #expect(memory.facts.contains { $0.text.hasPrefix("Provprofil: prov i Biologi") })

        model.study.level(-70, at: Date())
        var time = Date().addingTimeInterval(-4)
        for _ in 0..<15 { model.study.level(-25, at: time); time = time.addingTimeInterval(0.04) }
        model.receiveFinalTranscript("Vad är fotosyntes", at: time)
        for _ in 0..<45 { model.study.level(-70, at: time); time = time.addingTimeInterval(0.04) }

        #expect(await waitUntil { provider.requests.count == 1 })
        #expect(provider.requests[0].persona?.persona == "tutor")
        #expect(provider.requests[0].persona?.setup?.contains("Biologi") == true)
        #expect(provider.requests[0].persona?.setup?.contains("korta förklaringar") == true)

        model.endStudy(bySilence: false)
        await model.startProvFromCard()
        #expect(model.study.isActive, "the exam question only once")
    }
}
