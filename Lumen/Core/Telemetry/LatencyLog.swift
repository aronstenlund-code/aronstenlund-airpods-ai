import Foundation
import Observation

/// One answer's latency budget (item 7): activation (≈ end of the user's speech) → first streamed text → first
/// speech scheduled into the engine. Rendering adds `PlaybackService`'s play-requested → first-buffer probe.
struct LatencyRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    var question: String
    var trigger: ActivationTrigger
    var startedAt: Date
    var firstTextMs: Double?
    var firstSpeechMs: Double?
    var answerProvider: String?
    var voiceProvider: String?

    var summary: String {
        var parts: [String] = []
        parts.append(firstTextMs.map { "text \(Int($0)) ms" } ?? "text —")
        parts.append(firstSpeechMs.map { "voice \(Int($0)) ms" } ?? "voice —")
        return parts.joined(separator: " · ")
    }
}

/// Keeps the last answers' latencies and simple percentiles. Time is injected (`ContinuousClock.Instant`) so it
/// is unit-tested without sleeping.
@MainActor
@Observable
final class LatencyLog {
    static let maxRecords = 50

    private(set) var records: [LatencyRecord] = []
    private var currentStart: ContinuousClock.Instant?
    private var currentID: UUID?

    var current: LatencyRecord? {
        guard let currentID else { return nil }
        return records.first { $0.id == currentID }
    }

    var latest: LatencyRecord? { records.last }

    func begin(_ request: ActivationRequest, at instant: ContinuousClock.Instant = .now) {
        let record = LatencyRecord(id: request.id, question: request.query, trigger: request.trigger,
                                   startedAt: request.createdAt, firstTextMs: nil, firstSpeechMs: nil,
                                   answerProvider: nil, voiceProvider: nil)
        records.append(record)
        if records.count > Self.maxRecords { records.removeFirst(records.count - Self.maxRecords) }
        currentStart = instant
        currentID = request.id
        Log.signposter.emitEvent("latency.begin")
    }

    func markFirstText(provider: String, at instant: ContinuousClock.Instant = .now) {
        update { record in
            guard record.firstTextMs == nil else { return }
            record.firstTextMs = self.milliseconds(to: instant)
            record.answerProvider = provider
            Log.answer.info("latency: first text after \(Int(record.firstTextMs ?? -1), privacy: .public) ms (\(provider, privacy: .public))")
        }
    }

    func markFirstSpeech(provider: String, at instant: ContinuousClock.Instant = .now) {
        update { record in
            guard record.firstSpeechMs == nil else { return }
            record.firstSpeechMs = self.milliseconds(to: instant)
            record.voiceProvider = provider
            Log.playback.info("latency: first speech after \(Int(record.firstSpeechMs ?? -1), privacy: .public) ms (\(provider, privacy: .public))")
            Log.signposter.emitEvent("latency.firstSpeech")
        }
    }

    /// Ends the current measurement (answer failed/skipped/cancelled): later marks are ignored.
    func end() {
        currentStart = nil
        currentID = nil
    }

    func clear() {
        records.removeAll()
        end()
    }

    /// Percentile over the records that have the value (p in 0…100), nearest-rank.
    func percentile(_ p: Double, of keyPath: KeyPath<LatencyRecord, Double?>) -> Double? {
        let values = records.compactMap { $0[keyPath: keyPath] }.sorted()
        guard !values.isEmpty else { return nil }
        let rank = Int((p / 100 * Double(values.count)).rounded(.up))
        return values[max(0, min(values.count - 1, rank - 1))]
    }

    var firstTextP50: Double? { percentile(50, of: \.firstTextMs) }
    var firstTextP95: Double? { percentile(95, of: \.firstTextMs) }
    var firstSpeechP50: Double? { percentile(50, of: \.firstSpeechMs) }
    var firstSpeechP95: Double? { percentile(95, of: \.firstSpeechMs) }

    private func update(_ change: (inout LatencyRecord) -> Void) {
        guard let currentID, let index = records.firstIndex(where: { $0.id == currentID }) else { return }
        change(&records[index])
    }

    private func milliseconds(to instant: ContinuousClock.Instant) -> Double {
        guard let currentStart else { return 0 }
        let components = currentStart.duration(to: instant).components
        return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
