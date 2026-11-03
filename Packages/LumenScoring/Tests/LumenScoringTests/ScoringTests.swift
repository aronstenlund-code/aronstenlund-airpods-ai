import Testing
@testable import LumenScoring

@Suite struct EditDistanceTests {
    @Test func handComputedCounts() {
        let c = EditDistance.counts(reference: ["a", "b", "c", "d"], hypothesis: ["a", "x", "d"])
        // b->x substitution, c deleted
        #expect(c == EditCounts(substitutions: 1, deletions: 1, insertions: 0))
        #expect(EditDistance.distance(["kitten"], ["sitting"]) == 1)
        #expect(EditDistance.distance(Array("kitten"), Array("sitting")) == 3)
        #expect(EditDistance.counts(reference: [String](), hypothesis: ["a", "b"]) == EditCounts(insertions: 2))
        #expect(EditDistance.counts(reference: ["a", "b"], hypothesis: [String]()) == EditCounts(deletions: 2))
        #expect(EditDistance.counts(reference: ["a"], hypothesis: ["a"]) == EditCounts())
    }
}

@Suite struct ScoringTests {
    let scorer = Scorer()

    @Test func exactMatchAfterNormalisation() {
        let r = scorer.score(reference: "roten ur hundra", hypothesis: "Roten ur 100.")
        #expect(r.exactMatch)
        #expect(r.wer == 0)
        #expect(r.cer == 0)
    }

    @Test func oneSubstitutionInFourWords() {
        let r = scorer.score(reference: "när började andra världskriget", hypothesis: "när började andra världskrig")
        #expect(r.wer == 0.25)
        #expect(r.wordEdits == EditCounts(substitutions: 1, deletions: 0, insertions: 0))
        #expect(!r.exactMatch)
        // characters: "när började andra världskriget" (30) vs "...världskrig" (28): 2 deletions
        #expect(r.characterEdits.total == 2)
        #expect(r.referenceCharacterCount == 30)
    }

    @Test func cerHandComputed() {
        // normalised: "5 plus 2" (8 chars) vs "5 plus 3": one substitution -> 1/8
        let r = scorer.score(reference: "fem plus två", hypothesis: "fem plus tre")
        #expect(r.referenceCharacterCount == 8)
        #expect(r.cer == 0.125)
        #expect(r.wer == 1.0 / 3.0)
    }

    @Test func insertionsAndDeletionsCount() {
        let r = scorer.score(reference: "vad är en atom", hypothesis: "vad är det en atom")
        #expect(r.wordEdits == EditCounts(substitutions: 0, deletions: 0, insertions: 1))
        #expect(r.wer == 0.25)
        let d = scorer.score(reference: "vad är en atom", hypothesis: "vad atom")
        #expect(d.wordEdits == EditCounts(substitutions: 0, deletions: 2, insertions: 0))
        #expect(d.wer == 0.5)
    }

    @Test func emptyCases() {
        #expect(scorer.score(reference: "", hypothesis: "").wer == 0)
        #expect(scorer.score(reference: "", hypothesis: "hej").wer == 1)
        #expect(scorer.score(reference: "hej", hypothesis: "").wer == 1)
    }

    @Test func shortPromptItemsFromTestdata() {
        // Items from testdata/scripts/sv-short-prompts.md with typical transcriber variants.
        #expect(scorer.score(reference: "fem plus två", hypothesis: "5 + 2").exactMatch == false) // "+" is dropped -> ["5","2"]
        #expect(scorer.score(reference: "fem plus två", hypothesis: "5 plus 2").exactMatch)
        #expect(scorer.score(reference: "tjugofem procent av tvåhundra", hypothesis: "25 % av 200").exactMatch)
        #expect(scorer.score(reference: "när började andra världskriget", hypothesis: "När började andra världskriget?").exactMatch)
        #expect(scorer.score(reference: "vad är ph-värde", hypothesis: "Vad är pH-värde").exactMatch)
        #expect(scorer.score(reference: "vad är ph-värde", hypothesis: "Vad är phvärde").exactMatch == false)
    }

    @Test func paragraphNumbersFromTestdata() {
        let ref = "började den första september 1939 när Tyskland anföll Polen"
        let hyp = "började den första september nittonhundratrettionio när Tyskland anföll Polen"
        #expect(scorer.score(reference: ref, hypothesis: hyp).exactMatch)
    }

    @Test func aggregateIsCorpusLevel() {
        let a = scorer.score(reference: "a b c d", hypothesis: "a b c d")      // 0/4
        let b = scorer.score(reference: "a b", hypothesis: "x y")              // 2/2
        let agg = scorer.aggregate([a, b])
        #expect(agg.items == 2)
        #expect(agg.referenceWords == 6)
        #expect(agg.wordEdits.total == 2)
        #expect(abs(agg.wer - 2.0 / 6.0) < 1e-12)
        #expect(agg.exactMatchRate == 0.5)
    }

    @Test func csvRowQuotesFields() {
        let row = STTResultRow(provider: "apple-speechtranscriber", airpodsModel: "AirPods Pro 2", airpodsFirmware: "7E101",
                               strategy: "C-HFP-default", mode: "default", inputPort: "BluetoothHFP", hqSupported: false,
                               hqEnabled: false, sampleRateHz: 16000, region: "SE", osVersion: "26.1", distanceMeters: 2,
                               noise: "quiet", material: "short-prompt", item: "S01", referenceText: "roten ur hundra",
                               hypothesisText: "roten ur \"hundra\", sa han", wer: 0.5, cer: 0.1234, exactMatch: false,
                               firstPartialLatencyMs: 150, finalLatencyMs: nil, realTimeFactor: nil, notes: "")
        let line = row.csvLine
        #expect(line.hasPrefix("apple-speechtranscriber,AirPods Pro 2,7E101,C-HFP-default,default,BluetoothHFP,false,false,16000,SE,26.1,2,quiet,short-prompt,S01,roten ur hundra,"))
        #expect(line.contains("\"roten ur \"\"hundra\"\", sa han\""))
        #expect(line.hasSuffix(",0.5000,0.1234,false,150.0000,,,"))
    }
}
