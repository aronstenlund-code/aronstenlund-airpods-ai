import Foundation
import Testing
@testable import Lumen

/// A105 (D185): the reading mode's player with A78's silent mock files and hand-fired timer. No sound, 0 ElevenLabs
/// characters (D180).
@MainActor
@Suite struct A105ReadingTests {
    typealias MockSource = A78RepetitionTests.MockSource
    typealias MockTimer = A78RepetitionTests.MockTimer

    /// Two paragraphs: a heading of one sentence, then three sentences of 2 s each.
    static let text: [ReadingParagraph] = [
        ReadingParagraph(sentences: [ReadingSentence(text: "Fotosyntes", start: 0, end: 1)], isHeading: true),
        ReadingParagraph(sentences: [
            ReadingSentence(text: "Växter gör socker.", start: 0, end: 2),
            ReadingSentence(text: "De behöver ljus.", start: 2, end: 4),
            ReadingSentence(text: "Syre blir över.", start: 4, end: 6),
        ]),
    ]

    func make(startAt: Int = 0, missing: Set<Int> = []) -> (ReadingPlayer, MockSource, MockTimer) {
        let source = MockSource()
        let timer = MockTimer()
        let player = ReadingPlayer(paragraphs: Self.text,
                                   audio: { missing.contains($0) ? nil : URL(fileURLWithPath: "/tmp/p\($0).mp3") },
                                   source: source, timer: timer, startAt: startAt)
        return (player, source, timer)
    }

    @Test func readsParagraphsInOrderAndStopsAtTheEnd() {
        let (player, source, _) = make()
        player.start()
        #expect(player.phase == .reading)
        #expect(source.last.url.lastPathComponent == "p0.mp3")
        source.last.finish()
        #expect(source.last.url.lastPathComponent == "p1.mp3")
        #expect(player.sentenceIndex == 1)
        source.last.finish()
        #expect(player.isAtEnd)
        #expect(player.isRunning) // only Avsluta ends it
    }

    @Test func followsTheSoundSentenceBySentence() {
        let (player, source, _) = make(startAt: 1)
        var saved: [Int] = []
        player.onProgress = { saved.append($0) }
        player.start()
        source.last.advance(2.5)
        player.followSound()
        #expect(player.sentenceIndex == 2)
        #expect(player.currentSentence?.text == "De behöver ljus.")
        source.last.advance(2)
        player.followSound()
        #expect(player.sentenceIndex == 3)
        #expect(saved.suffix(2) == [2, 3])
    }

    @Test func onePressPausesAndGoesOnFromTheStartOfTheSentence() {
        let (player, source, _) = make(startAt: 1)
        player.start()
        source.last.advance(3.2) // in "De behöver ljus." (2–4 s)
        player.followSound()
        player.handle(.long)
        #expect(player.isPaused)
        #expect(source.last.isPlaying == false)
        player.handle(.long)
        #expect(!player.isPaused)
        #expect(source.last.currentTime == 2)
        #expect(source.last.isPlaying)
    }

    @Test func twoPressesNextSentenceThreePressesPrevious() {
        let (player, source, _) = make(startAt: 1)
        player.start()
        let file = source.last
        player.handle(.short)
        #expect(player.sentenceIndex == 2)
        #expect(file.currentTime == 2) // the same file, moved
        #expect(source.made.count == 1)
        player.handle(.pauseToggle)
        player.handle(.pauseToggle)
        #expect(player.sentenceIndex == 0) // back into the heading's file
        #expect(source.last.url.lastPathComponent == "p0.mp3")
        player.handle(.pauseToggle)
        #expect(player.sentenceIndex == 0) // never before the first
    }

    @Test func nextAfterTheLastSentenceIsTheEndAndOnePressStartsOver() {
        let (player, source, _) = make(startAt: 3)
        var saved: [Int] = []
        player.onProgress = { saved.append($0) }
        player.start()
        player.handle(.short)
        #expect(player.isAtEnd)
        #expect(saved.last == 0) // next time from the beginning
        player.handle(.short)
        #expect(player.isAtEnd)
        player.handle(.pauseToggle)
        #expect(player.sentenceIndex == 3)
        #expect(player.phase == .reading)
        player.handle(.short)
        player.handle(.long)
        #expect(player.sentenceIndex == 0)
        #expect(source.last.url.lastPathComponent == "p0.mp3")
    }

    @Test func movingWhilePausedStaysPausedAndStartsThere() {
        let (player, source, _) = make(startAt: 1)
        player.start()
        player.handle(.long)
        player.handle(.short)
        player.handle(.short)
        #expect(player.isPaused)
        #expect(player.sentenceIndex == 3)
        let before = source.made.count
        player.handle(.long)
        #expect(!player.isPaused)
        #expect(source.made.count == before + 1)
        #expect(source.last.currentTime == 4)
        #expect(source.last.isPlaying)
    }

    @Test func aTapOnASentenceReadsFromThere() {
        let (player, source, _) = make()
        player.start()
        player.handle(.long)
        player.jump(to: 2)
        #expect(!player.isPaused)
        #expect(player.sentenceIndex == 2)
        #expect(source.last.url.lastPathComponent == "p1.mp3")
        #expect(source.last.currentTime == 2)
    }

    @Test func iOSPauseGoesOnFromTheWord() {
        let (player, source, _) = make(startAt: 1)
        player.start()
        source.last.advance(3.2)
        player.systemPaused("call")
        #expect(player.pausedBySystem)
        player.systemResumed("call ended")
        #expect(source.last.currentTime == 3.2)
        #expect(source.last.isPlaying)
    }

    @Test func aParagraphWithoutSoundIsWaitedFor() {
        var missing: Set<Int> = [1]
        let source = MockSource()
        let timer = MockTimer()
        let player = ReadingPlayer(paragraphs: Self.text,
                                   audio: { missing.contains($0) ? nil : URL(fileURLWithPath: "/tmp/p\($0).mp3") },
                                   source: source, timer: timer, startAt: 1)
        player.start()
        #expect(player.phase == .waitingForAudio)
        #expect(timer.pending?.seconds == ReadingPlayer.audioRetrySeconds)
        missing = []
        timer.fire()
        #expect(player.phase == .reading)
        #expect(source.last.url.lastPathComponent == "p1.mp3")
    }

    @Test func aFileThatWillNotOpenIsSkipped() {
        let (player, source, timer) = make()
        source.missing = ["p0.mp3"]
        player.start()
        timer.fire()
        #expect(source.last.url.lastPathComponent == "p1.mp3")
        #expect(player.sentenceIndex == 1)
    }

    @Test func startAtIsKeptInsideTheText() {
        #expect(make(startAt: 99).0.sentenceIndex == 3)
        #expect(make(startAt: -2).0.sentenceIndex == 0)
    }
}
