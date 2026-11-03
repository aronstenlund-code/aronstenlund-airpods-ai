import Foundation
import Testing
@testable import Lumen

@Suite struct RingBufferTests {
    @Test func writeAndSnapshotInOrder() {
        let ring = Int16RingBuffer(capacity: 10)
        ring.write([1, 2, 3, 4, 5, 6, 7])
        #expect(ring.count == 7)
        #expect(ring.totalWritten == 7)
        #expect(ring.snapshot(last: 5) == [3, 4, 5, 6, 7])
        #expect(ring.snapshot(last: 100) == [1, 2, 3, 4, 5, 6, 7])
        #expect(ring.snapshot(last: 0).isEmpty)
    }

    @Test func wrapsAround() {
        let ring = Int16RingBuffer(capacity: 10)
        ring.write([1, 2, 3, 4, 5, 6, 7])
        ring.write([8, 9, 10, 11, 12, 13, 14, 15])
        #expect(ring.count == 10)
        #expect(ring.totalWritten == 15)
        #expect(ring.snapshot(last: 10) == [6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
        #expect(ring.snapshot(last: 3) == [13, 14, 15])
    }

    @Test func oversizedWriteKeepsNewest() {
        let ring = Int16RingBuffer(capacity: 10)
        ring.write((1...25).map { Int16($0) })
        #expect(ring.count == 10)
        #expect(ring.snapshot(last: 10) == (16...25).map { Int16($0) })
        #expect(ring.totalWritten == 25)
    }

    @Test func snapshotSinceMark() {
        let ring = Int16RingBuffer(capacity: 100)
        ring.write([1, 2, 3, 4, 5])
        let mark = ring.totalWritten
        ring.write([6, 7, 8, 9, 10, 11, 12])
        #expect(ring.snapshot(since: mark) == [6, 7, 8, 9, 10, 11, 12])
        #expect(ring.snapshot(since: ring.totalWritten).isEmpty)
    }

    @Test func sixtySecondsAt16kHz() {
        let ring = Int16RingBuffer(seconds: 60, sampleRate: 16_000)
        #expect(ring.capacity == 960_000)
        let seconds = ring.snapshot(lastSeconds: 1.5)
        #expect(seconds.isEmpty) // nothing written yet
        ring.write([Int16](repeating: 7, count: 32_000))
        #expect(ring.snapshot(lastSeconds: 1).count == 16_000)
    }

    @Test func clearResetsCounters() {
        let ring = Int16RingBuffer(capacity: 8)
        ring.write([1, 2, 3])
        ring.clear()
        #expect(ring.count == 0)
        #expect(ring.totalWritten == 0)
        #expect(ring.snapshot(last: 8).isEmpty)
    }

    @Test func concurrentWritesAndReadsDoNotCorrupt() {
        let ring = Int16RingBuffer(capacity: 4_096)
        let iterations = 64
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if i % 2 == 0 {
                ring.write([Int16](repeating: Int16(i), count: 1_000))
            } else {
                _ = ring.snapshot(last: 500)
            }
        }
        #expect(ring.totalWritten == Int64(iterations / 2 * 1_000))
        #expect(ring.count == 4_096)
        let snapshot = ring.snapshot(last: 4_096)
        #expect(snapshot.count == 4_096)
        // Every value must be one of the written constants (no torn/garbage samples).
        let allowed = Set((0..<iterations).filter { $0 % 2 == 0 }.map { Int16($0) })
        #expect(snapshot.allSatisfy { allowed.contains($0) })
    }
}
