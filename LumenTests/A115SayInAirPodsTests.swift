import Foundation
import Testing
@testable import Lumen

/// A115 (D203): "Säg i AirPods". The text is read exactly as written, counted per started 800 characters, and
/// "Upprepa i 5, 10, 20 min" goes round until the time is out and then stops. Mock sound, 0 ElevenLabs (D180).
@MainActor
@Suite struct A115SayInAirPodsTests {
    typealias MockSource = A78RepetitionTests.MockSource
    typealias MockTimer = A78RepetitionTests.MockTimer

    @MainActor final class Clock { var date = Date(timeIntervalSince1970: 1_800_000_000) }

    // MARK: The text

    @Test func theTextIsReadAsWrittenOnePartPerParagraph() {
        let parts = SaidText.parts("  Första raden. Den har två meningar.\n\n\nAndra stycket.  \n")
        #expect(parts == ["Första raden. Den har två meningar.", "Andra stycket."])
        #expect(SaidText.parts("   \n \n").isEmpty)
    }

    @Test func itCountsOneQuestionPerStarted800Characters() {
        #expect(SaidText.countsAs("") == 0)
        #expect(SaidText.countsAs("Hej.") == 1)
        #expect(SaidText.countsAs(String(repeating: "a", count: 800)) == 1)
        #expect(SaidText.countsAs(String(repeating: "a", count: 801)) == 2)
        #expect(SaidText.countsAs(String(repeating: "a", count: 2000)) == 3)
    }

    @Test func itIsNamedAfterItsFirstWords() {
        #expect(SaidText.title("Fotosyntes") == "Fotosyntes")
        #expect(SaidText.title("Ett två tre fyra fem sex sju") == "Ett två tre fyra fem …")
        #expect(SaidText.title("") == "Text")
        #expect(SaidText.title(String(repeating: "abcdefghij", count: 6)).count <= 34)
    }

    @Test func theLineUnderTheFieldSaysTheCostBeforeAnythingIsMade() {
        #expect(SayText.costLine(counts: 1, left: 12, readingAloudOff: false) == "Räknas som 1 fråga. Upprepningar kostar inget.")
        #expect(SayText.costLine(counts: 3, left: nil, readingAloudOff: false) == "Räknas som 3 frågor. Upprepningar kostar inget.")
        #expect(SayText.costLine(counts: 3, left: 1, readingAloudOff: false).hasPrefix("Texten räknas som 3 frågor, och du har 1 kvar."))
        #expect(SayText.costLine(counts: 1, left: 12, readingAloudOff: true) == "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt.")
    }

    @Test func theButtonsSayHowLongAndTheTempo() {
        #expect(SayText.howLong(0) == "En gång")
        #expect(SayText.howLong(10) == "10 min")
        #expect(SayText.tempo(1) == "1,0×")
        #expect(SayText.tempo(0.75) == "0,75×")
        #expect(SayText.tempo(0.5) == "0,5×")
        #expect(SayText.clock(432) == "7:12")
        #expect(SayText.tempos.allSatisfy { RepetitionModel.tempos.contains($0) }, "every tempo on offer is one the player takes")
    }

    // MARK: Repeating

    func session(_ source: MockSource, _ clock: Clock) -> RepetitionSession {
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { MockTimer() },
                                        defaults: UserDefaults(suiteName: "a115-\(UUID().uuidString)")!,
                                        activatesAudioSession: false)
        session.now = { clock.date }
        return session
    }

    static let text = Drill.text(title: "T", summary: DrillSummary(subject: "", grade: "", covers: ""),
                                 parts: [DrillItem.textPart("En mening.", part: .para)])
    static let audio = ReadingAudio(url: URL(fileURLWithPath: "/tmp/said.mp3"), times: [0...1])

    @Test func upprepaGoesRoundUntilTheTimeIsOutAndThenStops() {
        let source = MockSource()
        let clock = Clock()
        let session = session(source, clock)
        session.startReading(Self.text, saying: .init(repeatMinutes: 5)) { _ in Self.audio }
        #expect(session.readingLap == 1)
        #expect(session.repeatSecondsLeft == 300)
        clock.date += 60
        source.last.finish() // the text is read to its end: time is left, so it starts over
        #expect(session.readingLap == 2)
        #expect(session.reader?.isAtEnd == false)
        #expect(session.repeatSecondsLeft == 240)
        clock.date += 241 // the time runs out during the second lap: it is read to its end, then it stops
        #expect(session.repeatSecondsLeft == 0)
        source.last.finish()
        #expect(session.reader?.isAtEnd == true)
        #expect(session.readingLap == 2)
    }

    @Test func enGangReadsOnceAndStops() {
        let source = MockSource()
        let session = session(source, Clock())
        session.startReading(Self.text, saying: .init(repeatMinutes: nil)) { _ in Self.audio }
        #expect(session.repeatSecondsLeft == 0)
        source.last.finish()
        #expect(session.reader?.isAtEnd == true)
        #expect(session.readingLap == 1)
    }

    @Test func anOrdinaryTextNeverGoesRoundByItself() {
        let source = MockSource()
        let session = session(source, Clock())
        session.startReading(Self.text) { _ in Self.audio }
        #expect(session.saying == nil)
        source.last.finish()
        #expect(session.reader?.isAtEnd == true)
    }

    @Test func avslutaEndsTheRepetitionAtOnce() {
        let source = MockSource()
        let session = session(source, Clock())
        session.startReading(Self.text, saying: .init(repeatMinutes: 20)) { _ in Self.audio }
        session.stop()
        #expect(session.saying == nil)
        #expect(session.repeatSecondsLeft == 0)
        #expect(session.reader == nil)
    }
}
