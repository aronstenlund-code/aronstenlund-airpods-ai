import AVFAudio
import Foundation
import os
import Speech
import Testing
@testable import Lumen

/// The device crash of 2026-11-07: a block that iOS calls on its own queue was main-actor isolated, and Swift 6
/// trapped at run time (EXC_BREAKPOINT in `_dispatch_assert_queue_fail` on RealtimeMessenger.mServiceQueue).
/// Each test here calls the block the way the system does, from a background DispatchQueue. If a block is ever
/// isolated to the main actor again, the run-time check traps and the test run fails.
@Suite struct AudioCallbackIsolationTests {
    /// Runs `work` on a serial background queue, like Core Audio's real-time queue, and waits for it.
    private static func onBackgroundQueue(_ work: @escaping @Sendable () -> Void) async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue(label: "lumen.tests.realtime", qos: .userInteractive).async {
                work()
                done.resume()
            }
        }
    }

    private static func buffer(_ format: AVAudioFormat, frames: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 1)))
        buffer.frameLength = frames
        return buffer
    }

    @Test func theCaptureTapRunsOnAnotherQueue() async throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let ring = Int16RingBuffer(seconds: 1, sampleRate: LumenAudioFormat.sampleRate)
        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream()
        let context = try CaptureTapContext(inputFormat: format, ring: ring, continuation: continuation, maxInputFrames: 4_800)
        nonisolated(unsafe) let block = CaptureService.tapBlock(for: context)
        nonisolated(unsafe) let input = try Self.buffer(format, frames: 1_920)
        let time = AVAudioTime(hostTime: mach_absolute_time())

        await Self.onBackgroundQueue {
            for _ in 0..<3 { block(input, time) }
        }
        continuation.finish()

        var chunks = 0
        for await _ in stream { chunks += 1 }
        #expect(chunks >= 1, "the buffers were converted on the background queue")
    }

    @Test func thePlaybackProbeTapRunsOnAnotherQueue() async throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
        let probe = PlaybackLatencyProbe()
        probe.markRequested()
        nonisolated(unsafe) let block = PlaybackService.probeTapBlock(probe)
        nonisolated(unsafe) let input = try Self.buffer(format, frames: 256)
        let time = AVAudioTime(hostTime: mach_absolute_time())

        await Self.onBackgroundQueue { block(input, time) }
    }

    @Test func theSynthesizerCallbackRunsOnAnotherQueue() async throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1))
        let (stream, continuation) = AsyncStream<TTSChunk>.makeStream()
        let callback = PlaybackService.ttsBufferCallback(continuation)
        nonisolated(unsafe) let speech = try Self.buffer(format, frames: 512)
        nonisolated(unsafe) let end = try Self.buffer(format, frames: 0)

        await Self.onBackgroundQueue {
            callback(speech)
            callback(end) // an empty buffer ends the utterance
        }

        var chunks = 0
        for await _ in stream { chunks += 1 }
        #expect(chunks == 1)
    }

    @Test func thePlayedBackHandlerRunsOnAnotherQueue() async {
        let called = OSAllocatedUnfairLock(initialState: false)
        let handler = PlaybackService.playedBackHandler { called.withLock { $0 = true } }

        await Self.onBackgroundQueue { handler(.dataPlayedBack) }

        #expect(called.withLock { $0 })
    }

    @Test func theSpeechResultHandlerRunsOnAnotherQueue() async {
        let (stream, continuation) = AsyncStream<STTResult>.makeStream()
        let handler = LegacySpeechProvider.resultHandler(continuation)

        await Self.onBackgroundQueue { handler(nil, nil) }
        continuation.finish()

        var results = 0
        for await _ in stream { results += 1 }
        #expect(results == 0)
    }
}
