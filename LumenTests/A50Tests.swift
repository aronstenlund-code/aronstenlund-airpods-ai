import Foundation
import Testing
@testable import Lumen

/// A50 (D124, D126): the new Start. "Lumen kan allt" shows three examples that move one at a time and wrap; Provläge
/// is described "För dina prov".
@MainActor
@Suite struct A50Tests {
    @Test func theExamplesStartWithAronsAndPromiseOnlyWhatWorks() {
        let first = LumenCanDoAll.window(at: 0)
        #expect(first.count == 3)
        #expect(first[0].contains("kalender"))
        #expect(first[1].contains("pannkakor"))
        // Ke29 S2: no Spotify playlist or call before K36 works in the app.
        #expect(!LumenCanDoAll.examples.contains { $0.contains("spellista") || $0.contains("ring ") })
    }

    @Test func theWindowMovesOneAtATimeAndWraps() {
        let count = LumenCanDoAll.examples.count
        #expect(LumenCanDoAll.window(at: 1)[0] == LumenCanDoAll.examples[1])
        #expect(LumenCanDoAll.window(at: 1)[2] == LumenCanDoAll.examples[3])
        #expect(LumenCanDoAll.window(at: count) == LumenCanDoAll.window(at: 0))
        let last = LumenCanDoAll.window(at: count - 1)
        #expect(last[1] == LumenCanDoAll.examples[0], "wraps to the start")
    }

    @Test func everyExampleIsSaidToLumenInSwedishQuotes() {
        for line in LumenCanDoAll.examples {
            #expect(line.hasPrefix("”Lumen, "), "\(line)")
            #expect(line.hasSuffix("”"), "\(line)")
        }
    }

    @Test func provlageIsForYourExams() {
        #expect(ConversationMode.prov.tagline == "För dina prov")
        #expect(ConversationMode.standard.shortName == "Standardläge")
    }
}
