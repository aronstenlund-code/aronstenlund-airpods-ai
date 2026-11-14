import Foundation
import Testing
@testable import Lumen

/// A102 (K66 point 4): the screen shows numbers and formulas as in a textbook; the voice reads the spoken text.
@MainActor
struct A102ScreenTextTests {
    private func item() -> DrillItem {
        var item = DrillItem(question: "När började den industriella revolutionen i Sverige?",
                             short: "Runt artonhundrafemtio.",
                             long: "Runt artonhundrafemtio. Då kom de första ångsågarna.")
        item.screen = DrillScreenText(question: nil, short: "Runt 1850.", long: "Runt 1850. Då kom de första ångsågarna.")
        return item
    }

    @Test func shownTextFallsBackToTheSpokenOne() {
        let plain = DrillItem(question: "Vad är en syra?", short: "Ett ämne.", long: "Ett ämne. Den ger vätejoner.")
        #expect(plain.shownQuestion == "Vad är en syra?")
        #expect(plain.shownAnswer == "Ett ämne. Den ger vätejoner.")
        let numbers = item()
        #expect(numbers.shownQuestion == numbers.question)
        #expect(numbers.shownShort == "Runt 1850.")
        #expect(numbers.shownAnswer == "Runt 1850. Då kom de första ångsågarna.")
        #expect(numbers.short == "Runt artonhundrafemtio.", "the voice still reads the words")
    }

    @Test func anUnchangedFieldKeepsBothTexts() {
        let old = item()
        let same = old.edited(question: old.shownQuestion, answer: old.shownAnswer)
        #expect(same == old)
        let newQuestion = old.edited(question: "När kom industrialismen till Sverige?", answer: old.shownAnswer)
        #expect(newQuestion.question == "När kom industrialismen till Sverige?")
        #expect(newQuestion.short == old.short && newQuestion.screen?.short == "Runt 1850.", "the answer kept its texts")
    }

    @Test func aChangedAnswerIsSpokenAndShownAsWritten() {
        let old = item()
        let changed = old.edited(question: old.shownQuestion, answer: "Runt 1860. Järnvägen byggdes.")
        #expect(changed.short == "Runt 1860.")
        #expect(changed.long == "Runt 1860. Järnvägen byggdes.")
        #expect(changed.screen == nil, "no old screen text left")
        #expect(changed.shownShort == "Runt 1860.")
        #expect(!changed.sameText(as: old), "new sound for the changed text")
    }

    @Test func examReplyBuildsTheShownLongAnswer() {
        let both = DrillScreenText.made(question: "Vad är a² + b²?", short: "c².", long: nil,
                                        spokenShort: "c i kvadrat.", spokenLong: "c i kvadrat. Det är Pythagoras sats.")
        #expect(both?.question == "Vad är a² + b²?")
        #expect(both?.long == "c². Det är Pythagoras sats.")
        #expect(DrillScreenText.made(question: nil, short: " ", long: nil, spokenShort: "a", spokenLong: "b") == nil)
    }

    @Test func saveSendsOnlyTheShownFieldsAndGetReadsThemBack() throws {
        var drill = Drill(title: "Historia", summary: DrillSummary(subject: "Historia", grade: "åk 8", covers: ""), items: [item()])
        drill.items.append(DrillItem(question: "Vem var Gustav Vasa?", short: "En kung.", long: "En kung. Han enade Sverige."))
        let body = DrillCloudClient.saveBody(drill)
        let rows = try #require(body["items"] as? [[String: Any]])
        let shown = try #require(rows[0]["screen"] as? [String: String])
        #expect(shown == ["short": "Runt 1850.", "long": "Runt 1850. Då kom de första ångsågarna."])
        #expect(rows[1]["screen"] == nil)

        let json = #"""
        {"short":"Runt artonhundrafemtio.","long":"Runt artonhundrafemtio. Då kom de första ångsågarna.",
         "question":"När?","id":"i1","position":0,
         "audio":{"question":{"status":"done"},"long":{"status":"done"}},
         "screen":{"short":"Runt 1850."}}
        """#
        let remote = try JSONDecoder().decode(DrillCloudView.Item.self, from: Data(json.utf8))
        #expect(remote.screen?.short == "Runt 1850." && remote.screen?.question == nil)
    }
}

/// K67 (O64): the answers step may swap only questions `drill` made that nobody changed.
@MainActor
struct K67MayFixTests {
    @Test func onlyUnchangedGeneratedQuestions() {
        let a = DrillItem(question: "Varför är himlen blå?", short: "", long: "")
        let b = DrillItem(question: "Vad är ljus?", short: "", long: "")
        let made = [a.id: a.question, b.id: b.question]
        #expect(DrillClient.mayFix([a, b], generated: made))
        var changed = b
        changed.question = "Vad är ljus egentligen?"
        #expect(!DrillClient.mayFix([a, changed], generated: made), "a changed question")
        let own = DrillItem(question: "Min egen fråga?", short: "", long: "")
        #expect(!DrillClient.mayFix([own], generated: made), "the student's own")
        #expect(!DrillClient.mayFix([], generated: made))
    }
}
