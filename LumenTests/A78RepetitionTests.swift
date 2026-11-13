import Foundation
import Testing
@testable import Lumen

/// A78 (D142): the repetition player as a state machine, with silent mock files of known length, a timer the test
/// fires by hand and presses as `RepetitionEvent`s. No sound, no microphone, 0 ElevenLabs characters.
@MainActor
@Suite struct A78RepetitionTests {
    // MARK: Mocks

    @MainActor final class MockPlayer: RepetitionAudioPlayer {
        let url: URL
        var onFinish: (@MainActor () -> Void)?
        var currentTime: TimeInterval = 0
        var duration: TimeInterval = 4
        var rate: Float = 1
        var until: TimeInterval?
        var isPlaying = false
        var stopped = false
        var plays = 0

        init(url: URL) { self.url = url }

        func play(until: TimeInterval?) { self.until = until; isPlaying = true; plays += 1 }
        func pause() { isPlaying = false }
        func stop() { stopped = true; isPlaying = false; onFinish = nil }

        /// The file plays `seconds` further.
        func advance(_ seconds: TimeInterval) {
            guard isPlaying else { return }
            currentTime += seconds
        }

        func finish() {
            isPlaying = false
            let done = onFinish
            onFinish = nil
            done?()
        }
    }

    @MainActor final class MockSource: RepetitionAudioSource {
        var made: [MockPlayer] = []
        var missing: Set<String> = []
        struct Missing: Error {}

        func player(for url: URL) throws -> any RepetitionAudioPlayer {
            if missing.contains(url.lastPathComponent) { throw Missing() }
            let player = MockPlayer(url: url)
            made.append(player)
            return player
        }

        var last: MockPlayer { made[made.count - 1] }
    }

    @MainActor final class MockTimer: RepetitionTimer {
        var pending: (seconds: Double, fire: @MainActor () -> Void)?
        func start(seconds: Double, _ fire: @escaping @MainActor () -> Void) { pending = (seconds, fire) }
        func cancel() { pending = nil }
        func fire() {
            let fire = pending?.fire
            pending = nil
            fire?()
        }
    }

    static func url(_ name: String) -> URL { URL(fileURLWithPath: "/tmp/\(name).mp3") }

    static func tracks(_ n: Int, shortEnd: TimeInterval = 2.5) -> [RepetitionTrack] {
        (0..<n).map { RepetitionTrack(question: url("q\($0)"), long: url("l\($0)"), short: .prefix(ofLongUntil: shortEnd)) }
    }

    func make(_ n: Int = 3) -> (RepetitionPlayer, MockSource, MockTimer) {
        let source = MockSource()
        let timer = MockTimer()
        let player = RepetitionPlayer(tracks: Self.tracks(n), source: source, timer: timer, thinkingSeconds: 6)
        return (player, source, timer)
    }

    // MARK: Flow

    @Test func questionThinkingNextQuestion() {
        let (player, source, timer) = make()
        player.start()
        #expect(player.phase == .question(0))
        #expect(source.last.url.lastPathComponent == "q0.mp3")
        source.last.finish()
        #expect(player.phase == .thinking(0))
        #expect(timer.pending?.seconds == 6)
        timer.fire()
        #expect(player.phase == .question(1))
        #expect(source.last.url.lastPathComponent == "q1.mp3")
    }

    @Test func onePressPlaysTheLongAnswerThenTheNextQuestion() {
        let (player, source, timer) = make()
        player.start()
        let question = source.last
        player.handle(.long)
        #expect(question.stopped, "the question stops when the answer starts")
        #expect(player.phase == .answer(0, .long))
        #expect(source.last.url.lastPathComponent == "l0.mp3")
        #expect(source.last.until == nil)
        source.last.finish()
        #expect(player.phase == .question(1))
        #expect(timer.pending == nil, "no thinking time after an answer")
    }

    @Test func twoPressesPlayTheLongFileUpToItsFirstSentence() {
        // D145: the short answer is the long answer's first sentence, from the same file.
        let (player, source, _) = make()
        player.start()
        source.last.finish()
        player.handle(.short) // during the thinking time
        #expect(player.phase == .answer(0, .short))
        #expect(source.last.url.lastPathComponent == "l0.mp3")
        #expect(source.last.until == 2.5)
        source.last.finish()
        #expect(player.phase == .question(1))
    }

    @Test func aShortAnswerFileIsUsedWithoutTimestamps() {
        let source = MockSource()
        let tracks = [RepetitionTrack(question: Self.url("q0"), long: Self.url("l0"), short: .file(Self.url("s0")))]
        let player = RepetitionPlayer(tracks: tracks, source: source, timer: MockTimer(), thinkingSeconds: 6)
        player.start()
        player.handle(.short)
        #expect(source.last.url.lastPathComponent == "s0.mp3")
        #expect(source.last.until == nil)
    }

    @Test func aPressDuringAnAnswerStartsThatKindAgain() {
        let (player, source, _) = make()
        player.start()
        player.handle(.long)
        let long = source.last
        player.handle(.short)
        #expect(long.stopped)
        #expect(player.phase == .answer(0, .short))
        #expect(source.last.until == 2.5)
    }

    // MARK: Pause

    @Test func pauseGoesOnFromTheSameWordWithAnyPress() {
        for resumeWith in RepetitionEvent.allCases {
            let (player, source, _) = make()
            player.start()
            player.handle(.long)
            let long = source.last
            long.advance(7.3)
            player.handle(.pauseToggle)
            #expect(player.isPaused)
            #expect(!long.isPlaying)
            player.handle(resumeWith)
            #expect(!player.isPaused, "\(resumeWith)")
            #expect(long.isPlaying, "the same file goes on (\(resumeWith))")
            #expect(long.currentTime == 7.3, "from the same position (\(resumeWith))")
            #expect(source.made.count == 2, "no new file was opened (\(resumeWith))")
            #expect(player.phase == .answer(0, .long), "\(resumeWith)")
        }
    }

    @Test func aPausedShortAnswerStillStopsAtItsEnd() {
        let (player, source, _) = make()
        player.start()
        player.handle(.short)
        player.handle(.pauseToggle)
        player.handle(.pauseToggle)
        #expect(source.last.until == 2.5)
    }

    @Test func pauseDuringTheThinkingTimeHoldsTheNextQuestion() {
        let (player, source, timer) = make()
        player.start()
        source.last.finish()
        player.handle(.pauseToggle)
        #expect(timer.pending == nil, "no next question while paused")
        player.handle(.long)
        #expect(!player.isPaused)
        #expect(player.phase == .thinking(0), "a press while paused only goes on, it does not choose an answer")
        #expect(timer.pending?.seconds == 6)
        timer.fire()
        #expect(player.phase == .question(1))
    }

    // MARK: Never ends (R5d, R8)

    @Test func theListStartsAgainInTheSameOrder() {
        let (player, source, timer) = make(3)
        var order: [String] = []
        player.start()
        for _ in 0..<9 {
            order.append(source.last.url.lastPathComponent)
            source.last.finish()
            timer.fire()
        }
        #expect(order == ["q0.mp3", "q1.mp3", "q2.mp3", "q0.mp3", "q1.mp3", "q2.mp3", "q0.mp3", "q1.mp3", "q2.mp3"])
        #expect(player.lap == 3)
        #expect(player.isRunning)
    }

    @Test func onlyStopEnds() {
        let (player, source, timer) = make(1)
        player.start()
        for _ in 0..<5 { source.last.finish(); timer.fire() }
        #expect(player.isRunning)
        let playing = source.last
        player.stop()
        #expect(!player.isRunning)
        #expect(playing.stopped)
        player.handle(.long)
        #expect(source.made.count == 6, "a press after Avsluta does nothing")
    }

    @Test func iOSPausesAndOnlyItsOwnPauseComesBack() {
        let (player, source, _) = make()
        player.start()
        player.handle(.long)
        player.systemPaused("call")
        #expect(player.isPaused && player.pausedBySystem)
        player.systemResumed("call ended")
        #expect(!player.isPaused)
        #expect(source.last.isPlaying)

        player.handle(.pauseToggle)
        player.systemResumed("Siri ended")
        #expect(player.isPaused, "the user's own pause waits for a press")
    }

    @Test func aMissingFileIsSkippedNotTheEnd() {
        let (player, source, timer) = make(3)
        source.missing = ["q1.mp3"]
        player.start()
        source.last.finish()
        timer.fire() // → question 2 is missing
        #expect(player.phase == .question(1))
        #expect(timer.pending?.seconds == 1)
        timer.fire() // its "end" after 1 s → thinking
        #expect(player.phase == .thinking(1))
        timer.fire()
        #expect(player.phase == .question(2))
        #expect(player.isRunning)
    }

    @Test func progressIsSavedAfterEveryQuestion() {
        let (player, source, timer) = make(3)
        var saved: [Int] = []
        player.onProgress = { saved.append($0) }
        player.start()
        for _ in 0..<3 { source.last.finish(); timer.fire() }
        #expect(saved == [1, 2, 0])
    }

    @Test func startsWhereItWas() {
        let source = MockSource()
        let player = RepetitionPlayer(tracks: Self.tracks(5), source: source, timer: MockTimer(), thinkingSeconds: 6, startAt: 3)
        player.start()
        #expect(player.phase == .question(3))
        #expect(source.last.url.lastPathComponent == "q3.mp3")
    }

    // MARK: Rules

    @Test func thinkingTime() {
        #expect(ThinkingTime.seconds(questionCount: 5) == 6)
        #expect(ThinkingTime.seconds(questionCount: 20) == 6)
        #expect(ThinkingTime.seconds(questionCount: 30) == 5)
        #expect(ThinkingTime.seconds(questionCount: 40) == 4)
        #expect(ThinkingTime.seconds(questionCount: 90) == 4)
    }

    @Test func pressesMeanTheSameWhateverIOSThinks() {
        #expect(RemoteCommand.play.repetitionEvent == .long)
        #expect(RemoteCommand.pause.repetitionEvent == .long)
        #expect(RemoteCommand.toggle.repetitionEvent == .long)
        #expect(RemoteCommand.next.repetitionEvent == .short)
        #expect(RemoteCommand.previous.repetitionEvent == .pauseToggle)
    }

    @Test func theHubGivesEveryCommandToTheRepetition() async {
        let hub = RemoteCommandHub()
        var toggled = 0
        hub.onToggle = { toggled += 1 }
        var got: [RemoteCommand] = []
        hub.takeOver { got.append($0) }
        for command in [RemoteCommand.toggle, .play, .pause, .next, .previous] { await hub.route(command) }
        #expect(got == [.toggle, .play, .pause, .next, .previous])
        #expect(toggled == 0, "the listening modes get nothing while the repetition runs")
        hub.release()
        await hub.route(.toggle)
        #expect(toggled == 1)
        #expect(!hub.isTakenOver)
    }

    @Test func theShortAnswerLeadsTheLongOne() {
        #expect(DrillItem.long("Klorofyll fångar ljuset. Det behövs för fotosyntesen.", startingWith: "Klorofyll fångar ljuset.")
                == "Klorofyll fångar ljuset. Det behövs för fotosyntesen.")
        #expect(DrillItem.long("Det behövs för fotosyntesen.", startingWith: "Klorofyll fångar ljuset.")
                == "Klorofyll fångar ljuset. Det behövs för fotosyntesen.")
    }

    @Test func theSessionSavesProgressAndOffersToGoOn() throws {
        let defaults = try #require(UserDefaults(suiteName: "A78-\(UUID().uuidString)"))
        let source = MockSource()
        let timer = MockTimer()
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { timer },
                                        defaults: defaults, activatesAudioSession: false)
        let drill = Drill(title: "Fotosyntes", summary: DrillSummary(subject: "Biologi", grade: "åk 8", covers: "fotosyntes"),
                          items: (0..<3).map { DrillItem(question: "F\($0)", short: "K\($0).", long: "K\($0). L\($0).") })
        session.start(drill, tracks: Self.tracks(3))
        source.last.finish()
        timer.fire()
        #expect(session.savedIndex(for: drill) == 1)
        session.stop()
        #expect(!session.isActive)
        #expect(session.savedIndex(for: drill) == 1, "kept after Avsluta, for 'Fortsätt där du var?'")
    }

    @Test func theSessionPausesWhenTheOutputIsGone() throws {
        let defaults = try #require(UserDefaults(suiteName: "A78-\(UUID().uuidString)"))
        let source = MockSource()
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { MockTimer() },
                                        defaults: defaults, activatesAudioSession: false)
        let drill = Drill(title: "T", summary: DrillSummary(subject: "", grade: "", covers: ""),
                          items: [DrillItem(question: "F", short: "K.", long: "K. L.")])
        session.start(drill, tracks: Self.tracks(1))
        session.routeChanged(reasonRaw: 2) // oldDeviceUnavailable
        #expect(session.player?.isPaused == true)
        #expect(session.isActive, "paused, never ended")
        session.interruption(typeRaw: 0, optionsRaw: 1) // ended + shouldResume: only iOS's own pause comes back
        #expect(session.player?.isPaused == false)
    }

    // MARK: Angela: sound that arrives while the list plays (K46), AirPods 1/2

    /// A value the test changes while the player's track provider (a sendable closure) reads it.
    @MainActor final class Ref<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }

    @Test func aQuestionWithoutSoundYetIsWaitedFor() {
        // K46 makes the files in play order: question 2 may not be downloaded when question 1 ends.
        let source = MockSource()
        let timer = MockTimer()
        let all = Self.tracks(2)
        let ready = Ref(1)
        let player = RepetitionPlayer(count: 2, track: { $0 < ready.value ? all[$0] : nil }, source: source, timer: timer,
                                      thinkingSeconds: 6)
        player.start()
        source.last.finish()
        timer.fire() // the thinking time ends
        #expect(player.phase == .waitingForAudio(1))
        #expect(timer.pending?.seconds == RepetitionPlayer.audioRetrySeconds)
        player.handle(.long)
        #expect(player.phase == .waitingForAudio(1), "nothing to answer yet")
        timer.fire()
        #expect(player.phase == .waitingForAudio(1))
        ready.value = 2
        timer.fire()
        #expect(player.phase == .question(1))
        #expect(source.last.url.lastPathComponent == "q1.mp3")
    }

    @Test func aPauseWhileWaitingGoesOnWhenTheSoundIsThere() {
        let source = MockSource()
        let timer = MockTimer()
        let all = Self.tracks(1)
        let ready = Ref(false)
        let player = RepetitionPlayer(count: 1, track: { _ in ready.value ? all[0] : nil }, source: source, timer: timer,
                                      thinkingSeconds: 6)
        player.start()
        #expect(player.phase == .waitingForAudio(0))
        player.handle(.pauseToggle)
        #expect(player.isPaused && timer.pending == nil)
        ready.value = true
        player.handle(.short) // D143: any press goes on
        #expect(!player.isPaused)
        #expect(player.phase == .question(0))
    }

    @Test func earbudLayoutOnePressPausesAnAnswer() {
        // Spec §3, AirPods 1/2: right earbud play/pause = the long answer, and pause while an answer plays.
        let (player, source, _) = make()
        player.onePressPausesAnswer = true
        player.start()
        player.handle(.long)
        #expect(player.phase == .answer(0, .long))
        let answer = source.last
        player.handle(.long)
        #expect(player.isPaused, "1 press during an answer pauses")
        #expect(!answer.isPlaying)
        player.handle(.long)
        #expect(!player.isPaused && answer.isPlaying, "and goes on from the same word")
        #expect(player.phase == .answer(0, .long))
    }

    @Test func anInfiniteShortEndPlaysTheWholeFile() {
        // No short_end_ms from the server: the short answer is the whole long file rather than nothing.
        let source = MockSource()
        let tracks = [RepetitionTrack(question: Self.url("q0"), long: Self.url("l0"), short: .prefix(ofLongUntil: .infinity))]
        let player = RepetitionPlayer(tracks: tracks, source: source, timer: MockTimer(), thinkingSeconds: 6)
        player.start()
        player.handle(.short)
        #expect(source.last.until == nil)
    }

    @Test func theSessionStartsWithATrackProvider() {
        let source = MockSource()
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { MockTimer() },
                                        defaults: UserDefaults(suiteName: "A78p-\(UUID().uuidString)") ?? .standard,
                                        activatesAudioSession: false)
        let drill = Drill(title: "T", summary: DrillSummary(subject: "", grade: "", covers: ""),
                          items: [DrillItem(question: "F?", short: "K.", long: "K. L.")])
        let tracks = Self.tracks(1)
        session.start(drill, count: 1, onePressPausesAnswer: true) { tracks[$0] }
        #expect(session.isActive)
        #expect(session.player?.onePressPausesAnswer == true)
        #expect(session.player?.count == 1)
        session.stop()
        #expect(!session.isActive)
    }

    @Test func aNewUserHearsTheCueOnceAfterTheFirstThinkingTime() {
        // Kelly N1: in the first lap of the first exam, "Tryck en gång för svaret." once, then the next question.
        let (player, source, timer) = make(3)
        player.isFirstLap = true
        player.cue = Self.url("cue")
        player.start()
        source.last.finish() // question 1
        timer.fire() // thinking time over, no press
        #expect(source.last.url.lastPathComponent == "cue.mp3")
        #expect(player.phase == .thinking(0))
        source.last.finish()
        #expect(player.phase == .question(1))
        source.last.finish()
        timer.fire()
        #expect(player.phase == .question(2), "the cue plays only once")
    }

    @Test func aSlowTempoPlaysTheVoiceAt070AndAddsTheRestAsSilence() {
        // A84 (D151, D152): 0.50 = the voice at 0.70, then 4/0.5 − 4/0.7 ≈ 2.29 s of silence after a 4 s file.
        let (player, source, timer) = make(2)
        player.tempo = 0.5
        player.start()
        #expect(source.last.rate == 0.7)
        source.last.finish()
        #expect(player.phase == .question(0), "still the question while the rest of its time passes")
        let pause = timer.pending?.seconds ?? 0
        #expect(abs(pause - (4 / 0.5 - 4 / 0.7)) < 0.01)
        timer.fire()
        #expect(player.phase == .thinking(0))
        #expect(RepetitionPlayer.extraPause(seconds: 4, tempo: 0.9) == 0)
        #expect(RepetitionPlayer.extraPause(seconds: 4, tempo: 1.5) == 0)
    }

    @Test func aFastTempoIsTheVoicesRate() {
        let (player, source, _) = make(1)
        player.tempo = 1.5
        player.start()
        #expect(source.last.rate == 1.5)
    }
}
