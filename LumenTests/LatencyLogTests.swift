import Foundation
import Testing
@testable import Lumen

@MainActor
@Suite struct LatencyLogTests {
    private func request(_ query: String) -> ActivationRequest {
        ActivationRequest(query: query, trigger: .pushToTalk, language: .swedish)
    }

    @Test func recordsFirstTextAndFirstSpeechOncePerAnswer() {
        let log = LatencyLog()
        let t0 = ContinuousClock.now
        log.begin(request("roten ur hundra"), at: t0)
        log.markFirstText(provider: "cloud", at: t0 + .milliseconds(800))
        log.markFirstText(provider: "cloud", at: t0 + .milliseconds(900))
        log.markFirstSpeech(provider: "apple", at: t0 + .milliseconds(1400))
        log.markFirstSpeech(provider: "apple", at: t0 + .milliseconds(2000))

        let record = log.latest
        #expect(record?.question == "roten ur hundra")
        #expect(record?.firstTextMs.map { abs($0 - 800) < 1 } == true)
        #expect(record?.firstSpeechMs.map { abs($0 - 1400) < 1 } == true)
        #expect(record?.answerProvider == "cloud")
        #expect(record?.voiceProvider == "apple")
        #expect(record?.summary == "text 800 ms · voice 1400 ms")
    }

    @Test func marksAfterEndAreIgnoredAndRecordsAreCapped() {
        let log = LatencyLog()
        let t0 = ContinuousClock.now
        log.begin(request("a"), at: t0)
        log.end()
        log.markFirstText(provider: "cloud", at: t0 + .milliseconds(100))
        #expect(log.latest?.firstTextMs == nil)
        #expect(log.latest?.summary == "text — · voice —")

        for i in 0..<(LatencyLog.maxRecords + 3) {
            log.begin(request("q\(i)"), at: t0)
        }
        #expect(log.records.count == LatencyLog.maxRecords)
        #expect(log.records.first?.question == "q3")
        log.clear()
        #expect(log.records.isEmpty)
        #expect(log.current == nil)
    }

    @Test func percentilesUseNearestRank() {
        let log = LatencyLog()
        let t0 = ContinuousClock.now
        for ms in [500, 900, 700, 1500, 1100] {
            log.begin(request("q"), at: t0)
            log.markFirstText(provider: "cloud", at: t0 + .milliseconds(ms))
        }
        log.begin(request("no text yet"), at: t0)
        #expect(log.firstTextP50.map { Int($0) } == 900)
        #expect(log.firstTextP95.map { Int($0) } == 1500)
        #expect(log.firstSpeechP50 == nil)
    }
}
