import Foundation
import os

/// Fixed-capacity ring buffer of Int16 samples (Phase 1 §3.3: last 60 s of 16 kHz audio).
///
/// Thread safety: all state lives behind an `OSAllocatedUnfairLock`, so the type is `Sendable` without
/// `@unchecked`. `write` is real-time safe: no allocation, the lock is held only for the copy.
final class Int16RingBuffer: Sendable {
    struct Storage: Sendable {
        var samples: [Int16]
        var writeIndex = 0
        var filled = 0
        var totalWritten: Int64 = 0
    }

    let capacity: Int
    private let storage: OSAllocatedUnfairLock<Storage>

    init(capacity: Int) {
        let safeCapacity = max(1, capacity)
        self.capacity = safeCapacity
        self.storage = OSAllocatedUnfairLock(initialState: Storage(samples: [Int16](repeating: 0, count: safeCapacity)))
    }

    convenience init(seconds: Double, sampleRate: Double) {
        self.init(capacity: Int(seconds * sampleRate))
    }

    /// Samples currently held (≤ capacity).
    var count: Int { storage.withLock { $0.filled } }

    /// Samples written since creation / last `clear()` (monotonic; used as a position mark).
    var totalWritten: Int64 { storage.withLock { $0.totalWritten } }

    /// Appends samples; when more than `capacity` arrive at once only the newest `capacity` are kept.
    func write(_ input: UnsafeBufferPointer<Int16>) {
        guard let source = input.baseAddress, input.count > 0 else { return }
        let n = input.count
        let capacity = self.capacity
        // withLockUnchecked: the closure captures a raw pointer (not Sendable); it is only read inside the
        // critical section and never escapes.
        storage.withLockUnchecked { state in
            let skip = n > capacity ? n - capacity : 0
            var write = state.writeIndex
            state.samples.withUnsafeMutableBufferPointer { destination in
                guard let dst = destination.baseAddress else { return }
                var i = skip
                while i < n {
                    let room = min(capacity - write, n - i)
                    (dst + write).update(from: source + i, count: room)
                    i += room
                    write += room
                    if write == capacity { write = 0 }
                }
            }
            state.writeIndex = write
            state.filled = min(capacity, state.filled + (n - skip))
            state.totalWritten += Int64(n)
        }
    }

    func write(_ samples: [Int16]) {
        samples.withUnsafeBufferPointer { write($0) }
    }

    /// The most recent `count` samples in chronological order (fewer if not that many were written).
    func snapshot(last count: Int) -> [Int16] {
        let capacity = self.capacity
        return storage.withLock { state in
            let n = min(max(0, count), state.filled)
            guard n > 0 else { return [] }
            var out = [Int16](repeating: 0, count: n)
            var start = state.writeIndex - n
            if start < 0 { start += capacity }
            out.withUnsafeMutableBufferPointer { destination in
                state.samples.withUnsafeBufferPointer { source in
                    guard let dst = destination.baseAddress, let src = source.baseAddress else { return }
                    let first = min(n, capacity - start)
                    dst.update(from: src + start, count: first)
                    if first < n {
                        (dst + first).update(from: src, count: n - first)
                    }
                }
            }
            return out
        }
    }

    func snapshot(lastSeconds seconds: Double, sampleRate: Double = LumenAudioFormat.sampleRate) -> [Int16] {
        snapshot(last: Int(seconds * sampleRate))
    }

    /// Everything written after `mark` (a previous `totalWritten` value), capped at `capacity`.
    func snapshot(since mark: Int64) -> [Int16] {
        let written = totalWritten
        let n = Int(min(Int64(capacity), max(0, written - mark)))
        return snapshot(last: n)
    }

    func clear() {
        storage.withLock { state in
            state.writeIndex = 0
            state.filled = 0
            state.totalWritten = 0
        }
    }
}
