import Testing
@testable import LumenScoring

@Suite struct SwedishNumbersTests {
    @Test(arguments: [
        ("noll", 0), ("två", 2), ("nio", 9), ("tio", 10), ("elva", 11), ("nitton", 19), ("tjugo", 20),
        ("tjugofem", 25), ("tjugoen", 21), ("tjugoett", 21), ("trettionio", 39), ("fyrtio", 40), ("förtio", 40),
        ("nittionio", 99), ("hundra", 100), ("etthundra", 100), ("tvåhundra", 200), ("hundratjugofem", 125),
        ("femhundrasjuttiotre", 573), ("nittonhundra", 1900), ("nittonhundratrettionio", 1939),
        ("tusen", 1000), ("ettusen", 1000), ("tvåtusen", 2000), ("tvåtusenfemhundra", 2500),
        ("tiotusen", 10000), ("hundratusen", 100000), ("tolvtusentrehundrafyrtiofem", 12345), ("1945", 1945),
    ])
    func parses(_ word: String, _ expected: Int) {
        #expect(SwedishNumbers.value(of: word) == expected, "\(word)")
    }

    @Test(arguments: ["en", "ett", "fotosyntes", "första", "", "tjugotio", "hundrahundra", "tjugoelva"])
    func rejects(_ word: String) {
        #expect(SwedishNumbers.value(of: word) == nil, "\(word)")
    }

    @Test func mergesAdjacentNumberWords() {
        #expect(SwedishNumbers.canonicalize(["tjugo", "fem"], mergeAdjacent: true) == ["25"])
        #expect(SwedishNumbers.canonicalize(["nittonhundra", "trettionio"], mergeAdjacent: true) == ["1939"])
        #expect(SwedishNumbers.canonicalize(["två", "tusen"], mergeAdjacent: true) == ["2000"])
        #expect(SwedishNumbers.canonicalize(["fem", "hundra"], mergeAdjacent: true) == ["500"])
        #expect(SwedishNumbers.canonicalize(["tusen", "femhundra"], mergeAdjacent: true) == ["1500"])
    }

    @Test func doesNotMergeUnrelatedNumbers() {
        // "fem plus två": not adjacent
        #expect(SwedishNumbers.canonicalize(["fem", "plus", "två"], mergeAdjacent: true) == ["5", "plus", "2"])
        // two digit tokens are never merged (they were written as digits on purpose)
        #expect(SwedishNumbers.canonicalize(["20", "5"], mergeAdjacent: true) == ["20", "5"])
        // "fem två" is not a valid compound
        #expect(SwedishNumbers.canonicalize(["fem", "två"], mergeAdjacent: true) == ["5", "2"])
        #expect(SwedishNumbers.canonicalize(["tjugo", "fem"], mergeAdjacent: false) == ["20", "5"])
    }
}
