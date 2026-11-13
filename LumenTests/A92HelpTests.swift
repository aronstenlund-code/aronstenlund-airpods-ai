import Foundation
import Testing
@testable import Lumen

/// A92 (D166, K57): the help AI's answers, places and refusals, with the mock (no network).
@MainActor
@Suite struct A92HelpTests {
    @Test func thePlaceIsReadFromTheQuestionAndAnswer() {
        #expect(HelpPlace.guess(question: "Hur fungerar trycken?", answer: "") == .controls)
        #expect(HelpPlace.guess(question: "Hur publicerar jag?", answer: "") == .publish)
        #expect(HelpPlace.guess(question: "Kan jag dela med en kompis?", answer: "") == .share)
        #expect(HelpPlace.guess(question: "Vad kan jag fota?", answer: "") == .newDrill)
        #expect(HelpPlace.guess(question: "Hur ändrar jag tempot?", answer: "") == .settings)
        #expect(HelpPlace.guess(question: "Vem är du?", answer: "Jag är Earminds hjälp.") == nil)
    }

    @Test func outsideTheAppIsSaidWithTheHint() async throws {
        let help = MockHelp()
        let answer = try await help.answer("Hur blir vädret?", history: [])
        #expect(!answer.inScope && answer.place == nil && answer.hint != nil)
        let presses = try await help.answer("Hur fungerar trycken på AirPods?", history: [])
        #expect(presses.text.hasPrefix("Medan frågan spelas: tryck 1 gång") && presses.place == .controls)
        let tried = try await help.tryText("Fotosyntes. Växter gör socker av koldioxid och vatten.")
        #expect(tried.items.count == 3)
    }

    @Test func theServersWordsAreShown() {
        let body = Data(#"{"error":{"code":"quota_exceeded","message":"Du har inga frågor kvar den här månaden."}}"#.utf8)
        #expect(HelpClient.refusal(status: 402, data: body) == .refused("Du har inga frågor kvar den här månaden."))
        #expect(HelpClient.refusal(status: 500, data: Data()) == .failed)
        #expect(HelpError.offline.userMessage == "Ingen internetanslutning.")
    }
}
