import Foundation

/// "Copy results as Markdown" (Phase 1 §3.6 / §3.12). Everything the report needs, in one paste.
@MainActor
enum ResultsMarkdown {
    static func render(_ model: DiagnosticsModel) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var out: [String] = []

        out.append("# Earmind diagnostics — \(f.string(from: Date()))")
        out.append("")
        out.append("- Device: \(DeviceInfo.summary)")
        out.append("- Selected config: \(model.selectedConfig.rawValue)")
        out.append("- Session state: \(model.state.label)")
        out.append("- Active capture banner: \(model.banner)")
        if let error = model.lastError { out.append("- Last error: \(error)") }
        out.append("")

        out.append("## Session snapshot (§3.11)")
        out.append("")
        out.append(model.snapshot?.markdown ?? "_no snapshot_")
        out.append("")

        out.append("## Capture")
        out.append("")
        out.append("- Engine input format: \(model.capture.inputFormatDescription ?? "-")")
        out.append("- Chunks received: \(model.chunkCount) (last chunk \(model.lastChunkFrames) frames)")
        out.append("- Ring buffer: \(model.capture.ringBuffer.count) samples (\(String(format: "%.1f", Double(model.capture.ringBuffer.count) / LumenAudioFormat.sampleRate)) s), total written \(model.capture.ringBuffer.totalWritten)")
        out.append("- Conversion errors: \(model.capture.conversionErrorCount)")
        if !model.formatChanges.isEmpty { out.append("- Input format changes: \(model.formatChanges.joined(separator: "; "))") }
        if let url = model.lastExportURL { out.append("- Last WAV export: \(url.lastPathComponent)") }
        out.append("")

        out.append("## Speaker-distance runs")
        out.append("")
        if model.distanceRuns.isEmpty {
            out.append("_none_")
        } else {
            out.append(DistanceTestRun.markdownHeader)
            for run in model.distanceRuns { out.append(run.markdownRow) }
        }
        out.append("")

        out.append("## Mic-source sanity check")
        out.append("")
        out.append(model.micSourceResult?.summary ?? "_not run_")
        out.append("")
        out.append("## Microphone comparison (D55)")
        out.append("")
        out.append(model.micComparison?.markdown ?? "_not run_")
        out.append("")

        out.append("## Playback")
        out.append("")
        out.append("- Rate: \(String(format: "%.2f", model.speakRate))×")
        let samples = model.latencySamplesMs
        if samples.isEmpty {
            out.append("- play requested → first buffer rendered: _no measurements_")
        } else {
            let sorted = samples.sorted()
            let median = sorted[sorted.count / 2]
            out.append("- play requested → first buffer rendered: n=\(samples.count), median \(String(format: "%.1f", median)) ms, min \(String(format: "%.1f", sorted.first ?? 0)) ms, max \(String(format: "%.1f", sorted.last ?? 0)) ms")
            out.append("- samples (ms): \(samples.map { String(format: "%.1f", $0) }.joined(separator: ", "))")
            if let snapshot = model.snapshot {
                out.append("- session outputLatency: \(String(format: "%.1f", snapshot.outputLatency * 1000)) ms (add to the above for time-to-ear)")
            }
        }
        out.append("")

        out.append("## SpeechTranscriber / DictationTranscriber locales")
        out.append("")
        out.append("```")
        out.append(model.localeReport ?? "not run")
        out.append("```")
        out.append("")

        out.append("## Turns (A8: fragment, is_question, status, what the user got)")
        out.append("")
        out.append(model.turns.markdown)
        out.append("")

        out.append("## Event log (newest first)")
        out.append("")
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm:ss.SSS"
        for entry in model.eventLog {
            out.append("- \(tf.string(from: entry.time)) \(entry.text)")
        }
        return out.joined(separator: "\n")
    }
}
