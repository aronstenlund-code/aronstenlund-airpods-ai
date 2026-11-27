import Foundation
import Testing
@testable import Lumen

/// Ke91 (Kelly's word list): the English app shows English command words ("say next", "Lumen, continue",
/// "Lumen, quiz me"), so the commands must understand them too. Swedish keeps working.
@Suite(.serialized) struct Ke91WordsTests {
    private let nos = ["1", "2", "3", "4", "5", "6", "7"]

    @Test func thePracticeRunUnderstandsEnglish() {
        #expect(PracticeNav.decide("Next.", current: 2, nos: nos) == .next(3))
        #expect(PracticeNav.decide("next question please", current: 2, nos: nos) == .next(3))
        #expect(PracticeNav.decide("Previous", current: 2, nos: nos) == .previous(1))
        #expect(PracticeNav.decide("go back", current: 2, nos: nos) == .previous(1))
        #expect(PracticeNav.decide("Skip this one.", current: 2, nos: nos) == .skip(3))
        #expect(PracticeNav.decide("Repeat the question", current: 2, nos: nos) == .repeatQuestion(2))
        #expect(PracticeNav.decide("Say that again.", current: 2, nos: nos) == .repeatQuestion(2))
        #expect(PracticeNav.decide("I'm done.", current: 2, nos: nos) == .stop)
        #expect(PracticeNav.decide("How did I do?", current: 2, nos: nos) == .results)
        #expect(PracticeNav.decide("Question seven", current: 0, nos: nos) == .go(6))
        #expect(PracticeNav.decide("question 4", current: 0, nos: nos) == .go(3))
    }

    @Test func thePracticeRunStillUnderstandsSwedishAndAnswers() {
        #expect(PracticeNav.decide("nästa", current: 2, nos: nos) == .next(3))
        #expect(PracticeNav.decide("fråga sju", current: 0, nos: nos) == .go(6))
        #expect(PracticeNav.decide("avsluta provet", current: 0, nos: nos) == .stop)
        #expect(PracticeNav.decide("Plants make sugar from light.", current: 0, nos: nos) == .answer)
        #expect(PracticeNav.decide("The next step is respiration.", current: 0, nos: nos) == .answer, "a sentence is an answer")
    }

    @Test func lumenContinueResumesInBothLanguages() {
        #expect(VoiceChannel.parse("Lumen, continue").intent == .music(.backToLumen))
        #expect(VoiceChannel.parse("Lumen, fortsätt").intent == .music(.backToLumen), "what the paused screen says")
        #expect(VoiceChannel.parse("Lumen, back to EarMind").intent == .music(.backToLumen))
        #expect(VoiceChannel.parse("Lumen, tillbaka till Lumen").intent == .music(.backToLumen))
        #expect(VoiceChannel.parse("continue").intent != .music(.backToLumen), "only after the name")
        #expect(VoiceChannel.parse("fortsätt").intent != .music(.backToLumen))
    }

    @Test func quizMeIsOneCheckQuestionAsTheButton() {
        // "Förhör mig" is "Quiz me" on the button: one check question in both languages.
        #expect(MiniTest.isCheckQuestionRequest("quiz me"))
        #expect(MiniTest.isCheckQuestionRequest("Quiz me on photosynthesis"))
        #expect(MiniTest.isCheckQuestionRequest("förhör mig"))
        #expect(!MiniTest.isStartCommand("quiz me"))
        #expect(MiniTest.isStartCommand("mini quiz"))
        #expect(MiniTest.isStartCommand("minitest"))
        #expect(MiniTest.isStartCommand("test me"))
    }

    @Test func yesAndNoAreUnderstoodWhereTheScreenSaysThem() {
        // "Or say “yes” or “no”" (a question before a phone action) and "Say “yes” for more" (the Mer window).
        #expect(MoreOffer.verdict("yes") == true)
        #expect(MoreOffer.verdict("no") == false)
    }
}
