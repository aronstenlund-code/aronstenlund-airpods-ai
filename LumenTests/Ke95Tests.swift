import Foundation
import Testing
@testable import Lumen

/// Kelly Ke95 (2026-11-27, her look at D271 and D273): the question is the heading in Historik, the AirPods card has
/// one way on (the footer's Lyssna igen), and the lines under the badge are shorter.
@MainActor
@Suite struct Ke95Tests {
    @Test func theQuestionIsTheHeadingAndTheAnswerUnderIt() {
        let asked = HistoryEntry(question: "Vad är pi?", answer: "Ungefär 3,14.", summary: "Pi")
        #expect(asked.rowLines.heading == "Vad är pi?")
        #expect(!asked.rowLines.answerIsHeading)
        #expect(asked.rowLines.under == "Ungefär 3,14.", "the answer grey under the question, not the summary first")
    }

    @Test func withoutAQuestionTheAnswerIsTheHeadingAfterSvar() {
        let heard = HistoryEntry(question: nil, answer: "Klorofyll är det gröna ämnet i bladen.", summary: "Klorofyll")
        #expect(heard.rowLines.heading == "Klorofyll är det gröna ämnet i bladen.")
        #expect(heard.rowLines.answerIsHeading, "a grey Svar before it")
        #expect(heard.rowLines.under == nil)
    }

    @Test func theAirPodsCardHasOneWayOn() {
        #expect(LumenProblem.airPodsLostPaused.actionTitle == nil)
        #expect(LumenProblem.airPodsLostPaused.text == "Sätt i dem igen, eller tryck Lyssna igen för att lyssna vidare i högtalaren.")
    }

    @Test func theLinesUnderTheBadgeAreShorter() {
        #expect(ListeningCondition.noAirPods.line == "Inga AirPods – svaren spelas i högtalaren.")
        #expect(ListeningCondition.offline(phoneModel: true).line == "Inget nät – telefonens egen modell svarar.")
    }
}
