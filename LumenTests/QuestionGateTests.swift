import Foundation
import Testing
@testable import Lumen

/// Evaluation set: the 30 items of `testdata/scripts/sv-short-prompts.md` plus statements that must not trigger.
@Suite struct QuestionGateTests {
    /// Items that must fire at the default (medium) sensitivity: questions, maths, imperatives.
    static let promptsFiringAtMedium: [String] = [
        "roten ur hundra", "fem plus två", "tolv gånger åtta", "hundra delat med fyra", "vad är sju i kvadrat",
        "tjugofem procent av tvåhundra", "vad är pi", "derivatan av x i kvadrat",
        "vad är ljusvågor", "vad är en atom", "hur många kromosomer har en människa", "vad är ljudets hastighet",
        "vad är mitokondrier", "vad är ph-värde",
        "när började andra världskriget", "vem var gustav vasa", "när föll berlinmuren",
        "vem var sveriges första statsminister", "när blev sverige medlem i eu",
        "vad betyder ambivalent", "vad är ett adverb", "hur stavas man restaurang",
        "vad är huvudstaden i australien", "hur många invånare har sverige", "vilket är världens längsta flod",
        "förklara växthuseffekten", "kan någon förklara det igen",
    ]
    /// Bare topic fragments: answered on push-to-talk, and in auto mode only at high sensitivity.
    static let bareFragments: [String] = ["fotosyntes", "newtons andra lag", "franska revolutionen"]
    /// Classroom statements that must never trigger, at any sensitivity.
    static let statements: [String] = [
        "idag ska vi prata om fotosyntes", "vi tar en paus på tio minuter", "öppna boken på sidan fyrtiotvå",
        "det var allt för idag", "som jag sa förra veckan", "nu går vi vidare till nästa kapitel",
        "fotosyntesen är processen där växter omvandlar ljus till energi", "vi ska se hur det går",
        "det är vad jag menar", "idag ska vi prata om vad fotosyntes är",
        "the lecture starts at nine", "I think we should take a break", "let's look at page forty two",
        "so then we continue with the next chapter", "and that is why the war started",
    ]
    static let englishQuestions: [String] = [
        "what is the capital of australia", "five plus two", "explain photosynthesis", "square root of a hundred",
        "can someone explain that again", "how many chromosomes do humans have", "what is seven squared",
        "tell me about the french revolution",
    ]

    @Test(arguments: promptsFiringAtMedium)
    func firesAtMediumSensitivity(_ text: String) {
        let decision = QuestionGate(sensitivity: .medium).evaluate(text)
        #expect(decision.fires, "\(text): score \(decision.score) signals \(decision.signals)")
    }

    @Test(arguments: englishQuestions)
    func englishFiresAtMedium(_ text: String) {
        let decision = QuestionGate(sensitivity: .medium).evaluate(text)
        #expect(decision.fires, "\(text): score \(decision.score) signals \(decision.signals)")
    }

    @Test(arguments: bareFragments)
    func bareFragmentsFireOnlyAtHigh(_ text: String) {
        #expect(!QuestionGate(sensitivity: .medium).evaluate(text).fires, "\(text) must not fire at medium")
        #expect(QuestionGate(sensitivity: .high).evaluate(text).fires, "\(text) must fire at high")
        #expect(QuestionGate(sensitivity: .medium).evaluate(text).signals.contains(.shortFragment))
    }

    @Test(arguments: statements)
    func statementsNeverFire(_ text: String) {
        for sensitivity in GateSensitivity.allCases {
            let decision = QuestionGate(sensitivity: sensitivity).evaluate(text)
            #expect(!decision.fires, "\(text) @ \(sensitivity): score \(decision.score) signals \(decision.signals)")
        }
    }

    @Test func questionMarkAloneIsEnoughAtMedium() {
        let decision = QuestionGate().evaluate("Och sen då?")
        #expect(decision.signals.contains(.questionMark))
        #expect(decision.fires)
    }

    @Test func digitsAndNumberWordsScoreTheSame() {
        let words = QuestionGate().evaluate("fem plus två")
        let digits = QuestionGate().evaluate("5 plus 2")
        #expect(words.signals.contains(.mathPattern))
        #expect(digits.signals.contains(.mathPattern))
        #expect(words.score == digits.score)
    }

    @Test func lowSensitivityNeedsStrongEvidence() {
        #expect(QuestionGate(sensitivity: .low).evaluate("vad är sju i kvadrat?").fires, "question mark + interrogative + maths")
        #expect(QuestionGate(sensitivity: .low).evaluate("förklara växthuseffekten").fires, "imperative + short fragment = 0.85")
        #expect(!QuestionGate(sensitivity: .low).evaluate("hur många invånare har sverige").fires, "one cue alone (0.55) is not enough at low")
    }

    @Test func overlapWithOurPlaybackNeverFires() {
        let decision = QuestionGate(sensitivity: .high).evaluate("vad är fotosyntes?", overlapsPlayback: true)
        #expect(!decision.fires)
        #expect(decision.signals == [.overlapsPlayback])
    }

    @Test func emptyNeverFires() {
        let decision = QuestionGate(sensitivity: .high).evaluate("  ?? ")
        #expect(!decision.fires)
        #expect(decision.signals.contains(.empty))
    }

    @Test func longRamblingQuestionIsPenalised() {
        let text = "vad är det egentligen som händer med energin när ljuset träffar bladet och växten tar upp det där"
        let medium = QuestionGate().evaluate(text)
        #expect(medium.signals.contains(.tooLong))
        #expect(!medium.fires, "18 tokens with one cue: 0.55 - 0.25 = 0.3 < 0.5")
        #expect(QuestionGate(sensitivity: .high).evaluate(text).fires, "high sensitivity still takes it")
        #expect(QuestionGate().evaluate(text + "?").fires, "a question mark settles it")
    }
}
