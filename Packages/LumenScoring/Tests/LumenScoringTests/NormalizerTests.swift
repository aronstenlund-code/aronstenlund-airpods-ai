import Testing
@testable import LumenScoring

@Suite struct NormalizerTests {
    let n = TextNormalizer()

    @Test func lowercasesSwedishAndStripsPunctuation() {
        #expect(n.tokens("Roten ur Hundra!") == ["roten", "ur", "100"])
        #expect(n.tokens("  Vad   är  LJUSVÅGOR?") == ["vad", "är", "ljusvågor"])
        #expect(n.tokens("Åke, Örjan och Ärlig.") == ["åke", "örjan", "och", "ärlig"])
    }

    @Test func hyphenIsAWordBoundary() {
        #expect(n.tokens("ph-värde") == ["ph", "värde"])
        #expect(n.tokens("phvärde") == ["phvärde"])
        #expect(n.tokens("pq-formeln") == ["pq", "formeln"])
    }

    @Test func decimalsStayOneToken() {
        #expect(n.tokens("3,5 meter") == ["3,5", "meter"])
        #expect(n.tokens("3.5 meter") == ["3.5", "meter"])
        #expect(n.tokens("1. september") == ["1", "september"])
    }

    @Test func percentBecomesProcent() {
        #expect(n.tokens("25% av 200") == ["25", "procent", "av", "200"])
        #expect(n.tokens("tjugofem procent av tvåhundra") == ["25", "procent", "av", "200"])
    }

    @Test func bareEnAndEttAreNotNumbers() {
        #expect(n.tokens("en atom") == ["en", "atom"])
        #expect(n.tokens("ett adverb") == ["ett", "adverb"])
        #expect(n.tokens("tjugoen elever") == ["21", "elever"])
    }

    @Test func numbersOffWhenDisabled() {
        var o = TextNormalizer.Options()
        o.numbersToDigits = false
        let plain = TextNormalizer(options: o)
        #expect(plain.tokens("roten ur hundra") == ["roten", "ur", "hundra"])
    }

    @Test func normalizedString() {
        #expect(n.normalizedString("Fem  plus två.") == "fem plus 2")
    }
}
