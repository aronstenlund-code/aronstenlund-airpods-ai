import Foundation
import Testing
@testable import Lumen

/// A4: streamed speech through the jitter buffer, against a player that plays in real time. The network is
/// simulated (late chunks, bursts, a long stall); the measure is how often the player runs dry after the start.
@Suite struct VoiceSmoothnessTests {
    static let rate = 24_000.0
    static let chunk = 2_400 // 100 ms, as ElevenLabs is read

    /// Feeds chunks that arrive at `times` (seconds); returns how often the player ran dry with audio still to
    /// come, and when playing started.
    private func run(_ times: [Double], jitter: Bool) -> (gaps: Int, startedAt: Double?) {
        var buffer = JitterBuffer(startSamples: Int(Self.rate * ElevenLabsTTSProvider.startBufferSeconds))
        var queuedUntil = 0.0 // the time the player's queue runs out
        var gaps = 0
        var startedAt: Double?
        var playing = false
        let arrivals = times.sorted()
        for (index, t) in arrivals.enumerated() {
            let queued = max(0, queuedUntil - t)
            if playing, queued == 0 { gaps += 1 } // the player ran dry before this chunk came
            let samples = [Int16](repeating: 1, count: Self.chunk)
            var out = jitter ? buffer.push(samples, queuedSamples: Int(queued * Self.rate)) : samples
            if index == arrivals.count - 1, jitter { out += buffer.finish() } // the stream ends: what is left plays
            if !out.isEmpty {
                if startedAt == nil { startedAt = t }
                playing = true
                queuedUntil = max(queuedUntil, t) + Double(out.count) / Self.rate
            }
        }
        return (gaps, startedAt)
    }

    @Test func lateChunksNoLongerStutter() {
        // A chunk every 100 ms on average, but every other one 150 ms late (uneven 4G).
        let times = (0..<30).map { i in Double(i) * 0.1 + (i % 2 == 1 ? 0.15 : 0) }
        let naive = run(times, jitter: false)
        let buffered = run(times, jitter: true)
        #expect(naive.gaps > 5, "playing each chunk at once stutters")
        #expect(buffered.gaps == 0, "the start buffer absorbs the lateness")
    }

    @Test func burstsAfterAPauseNeedNoGap() {
        // ElevenLabs sends in bursts: 5 chunks, 400 ms nothing, 5 chunks.
        let times = (0..<5).map { _ in 0.0 } + (0..<5).map { _ in 0.4 }
        #expect(run(times, jitter: true).gaps == 0)
    }

    @Test func aLongStallBuffersAgainInsteadOfStuttering() {
        // 1 s of audio, then the network stops for 2 s, then real time again.
        let first = (0..<10).map { Double($0) * 0.1 }
        let after = (0..<10).map { 3.0 + Double($0) * 0.1 }
        var buffer = JitterBuffer(startSamples: Int(Self.rate * ElevenLabsTTSProvider.startBufferSeconds))
        var queuedUntil = 0.0
        for t in first + after {
            let out = buffer.push([Int16](repeating: 1, count: Self.chunk), queuedSamples: Int(max(0, queuedUntil - t) * Self.rate))
            if !out.isEmpty {
                queuedUntil = max(queuedUntil, t) + Double(out.count) / Self.rate
            }
        }
        #expect(buffer.underruns == 1, "one stall is one pause, not a stutter per chunk")
    }

    @Test func aShortSentenceIsNeverHeldBack() {
        var buffer = JitterBuffer(startSamples: 7_200)
        #expect(buffer.push([Int16](repeating: 1, count: 2_400), queuedSamples: 0).isEmpty, "collecting")
        #expect(buffer.finish().count == 2_400, "the stream ended: it plays")
        #expect(buffer.underruns == 0)
    }

    @Test func theStatsAddUpAndReadInSwedish() {
        var total = VoiceStreamStats()
        total.add(VoiceStreamStats(sentences: 2, underruns: 1, silenceMs: 240, startWaitMs: 180, prefetched: 1))
        total.add(VoiceStreamStats(sentences: 1))
        #expect(total.sentences == 3)
        #expect(total.summary == "3 meningar, 1 avbrott, 240 ms tystnad, startbuffert 180 ms, 1 förhämtade")
    }
}

@MainActor
@Suite struct NextSentencePrefetchTests {
    @Test func theNextSentenceIsFetchedWhileTheFirstPlays() async {
        let playback = FakePlaybackService()
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.delay = .milliseconds(150)
        let settings = freshVoiceSettings()
        settings.voice = VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Test")
        let speaker = Speaker(settings: settings, apple: apple, premium: premium, playback: playback)

        speaker.enqueue("Första meningen.", language: .swedish)
        speaker.enqueue("Andra meningen.", language: .swedish)

        #expect(await waitUntil { premium.calls.count == 2 && !speaker.hasPendingSpeech })
        #expect(premium.synthesizeCalls == ["Andra meningen."], "fetched while the first was being spoken")
        #expect(speaker.lastAnswerStats?.sentences == 2)
    }
}
