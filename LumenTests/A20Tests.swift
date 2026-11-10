import Foundation
import Testing
@testable import Lumen

/// A20.1: the voice's pace per context.
@Suite struct SpeechPaceTests {
    private let t0 = Date(timeIntervalSince1970: 5_000_000)

    @Test func stepsDownAndBack() {
        #expect(SpeechPace.slower(than: 1) == 0.9)
        #expect(SpeechPace.slower(than: 0.9) == 0.85)
        #expect(SpeechPace.slower(than: 0.85) == 0.85, "never slower than the last step")
        #expect(SpeechPace.faster(than: 0.85) == 0.9)
        #expect(SpeechPace.faster(than: 0.9) == 1)
        #expect(SpeechPace.faster(than: 1) == 1)
    }

    @Test func spokenRequests() {
        for text in ["långsammare", "Lumen, långsammare", "prata långsammare", "Kan du prata lite långsammare?", "lugnare tack"] {
            #expect(SpeechPace.request(text) == .slower, "\(text)")
        }
        for text in ["snabbare", "Lumen, snabbare", "prata fortare"] {
            #expect(SpeechPace.request(text) == .faster, "\(text)")
        }
        for text in ["varför går tåget långsammare i uppförsbacke", "hon sprang snabbare än han", "vad är långsammare"] {
            #expect(SpeechPace.request(text) == nil, "\(text)")
        }
    }

    @Test func twoRepeatsWithinTenMinutesSlowDown() {
        var signals = PaceSignals()
        #expect(!signals.repeated(at: t0))
        #expect(signals.repeated(at: t0.addingTimeInterval(120)))
        #expect(!signals.repeated(at: t0.addingTimeInterval(130)), "the counter starts over")
    }

    @Test func repeatsFarApartDoNot() {
        var signals = PaceSignals()
        #expect(!signals.repeated(at: t0))
        #expect(!signals.repeated(at: t0.addingTimeInterval(SpeechPace.repeatWindow + 1)))
    }

    @Test func threeNotePausesSlowDown() {
        var signals = PaceSignals()
        #expect(!signals.tookNotes())
        #expect(!signals.tookNotes())
        #expect(signals.tookNotes())
    }

    @Test func linesForMinne() {
        #expect(SpeechPace.line(factor: 0.85, mode: .prov, subject: "Biologi") == "Långsammare tal i Biologi")
        #expect(SpeechPace.line(factor: 0.9, mode: .standard, subject: nil) == "Lite långsammare tal i Frågor")
    }

    @MainActor
    @Test func theStoreKeepsOnePacePerContext() {
        let suite = "lumen.tests.a20.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SpeechPaceStore(defaults: defaults)
        store.set(0.9, mode: .prov, subject: "Biologi")
        store.set(0.85, mode: .prov, subject: "biologi ")
        #expect(store.entries.count == 1)
        #expect(store.factor(mode: .prov, subject: "Biologi") == 0.85)
        #expect(store.factor(mode: .prov, subject: "Historia") == 1)
        #expect(SpeechPaceStore(defaults: defaults).factor(mode: .prov, subject: "Biologi") == 0.85, "kept")
        store.set(1, mode: .prov, subject: "Biologi")
        #expect(store.entries.isEmpty, "1.0 is not stored")
    }
}

/// A20.2: the silent quiz's bookkeeping.
@Suite struct SilentQuizTests {
    @Test func questionsGradesAndSummary() {
        var quiz = SilentQuiz()
        quiz.lumenSaid("Är klorofyll grönt?")
        #expect(quiz.awaitingAnswer)
        #expect(quiz.asked == 1)
        quiz.answered()
        quiz.lumenSaid("Rätt, klorofyll reflekterar grönt ljus. Sker fotosyntesen i mitokondrierna?")
        #expect(quiz.asked == 2)
        quiz.answered()
        quiz.lumenSaid("Fel, den sker i kloroplasterna. Behöver växter koldioxid?")
        #expect(quiz.summary == "Tyst förhör klart. 1 av 2 rätt.")
    }

    @Test func twoMissesEndIt() {
        var quiz = SilentQuiz()
        quiz.lumenSaid("Är klorofyll grönt?")
        quiz.missed()
        #expect(!quiz.isFinished)
        quiz.missed()
        #expect(quiz.isFinished)
    }

    @Test func verdicts() {
        #expect(SilentQuiz.verdict("Rätt! Bra.") == true)
        #expect(SilentQuiz.verdict("Inte riktigt, det är kloroplasterna.") == false)
        #expect(SilentQuiz.verdict("Fotosyntes är …") == nil)
    }

    @Test func startCommands() {
        #expect(SilentQuiz.isStartCommand("Lumen, tyst förhör"))
        #expect(SilentQuiz.isStartCommand("förhör mig tyst"))
        #expect(!SilentQuiz.isStartCommand("vi hade ett tyst förhör i skolan idag"))
    }
}
