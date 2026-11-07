import SwiftUI

/// Functional diagnostics screen (Phase 1 §3.6). Not pretty on purpose.
/// Mikrofonjämförelsen (D55): read the sentence, tap Done, the word error rate is added to the results.
private struct MicComparisonSection: View {
    @Bindable var model: MicComparisonModel

    var body: some View {
        Section("Microphone comparison") {
            Picker("Microphone", selection: $model.source) {
                Text("AirPods").tag(MicrophoneSource.airPods)
                Text("iPhone").tag(MicrophoneSource.iPhone)
            }
            Picker("Speaker", selection: $model.speaker) {
                Text("Own voice").tag(MicComparisonModel.Speaker.wearer)
                Text("Other person at 1.5 m").tag(MicComparisonModel.Speaker.otherPerson)
            }
            Text(verbatim: model.sentence).font(.headline)
            Button(model.isRecording ? "Done, next sentence" : "Start reading") {
                Task {
                    if model.isRecording { await model.finish() } else { await model.start() }
                }
            }
            .disabled(!model.canRecord)
            ForEach(model.summaryLines, id: \.self) { line in
                Text(verbatim: line).font(.caption.monospaced())
            }
        }
    }
}

/// D78: two minutes of audio + what was heard, to compare Scribe and the iPhone on the same sound.
private struct SpeechRecordingSection: View {
    let model: SpeechRecordingModel

    var body: some View {
        Section("Jämför taligenkänning (2 min)") {
            Text("Lyssna i det läge du vill testa, tryck Spela in och prata som vanligt. Skicka sedan båda filerna till oss.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(model.isRecording ? "Stoppa inspelningen" : "Spela in 2 minuter") {
                if model.isRecording { model.stop() } else { model.start() }
            }
            .disabled(!model.isRecording && !model.canRecord)
            if model.isRecording {
                ProgressView(value: min(1, model.elapsed / SpeechRecordingModel.seconds)) {
                    Text(verbatim: String(format: "%.0f / %.0f s", model.elapsed, SpeechRecordingModel.seconds))
                }
            }
            if !model.files.isEmpty {
                ShareLink(items: model.files) {
                    Label("Dela WAV + transkript", systemImage: "square.and.arrow.up")
                }
                Button(model.isTranscribingOnDevice ? "iPhone-igenkänningen arbetar…" : "Kör iPhone-igenkänning på inspelningen") {
                    Task { await model.transcribeOnDevice() }
                }
                .disabled(model.isTranscribingOnDevice)
            }
            if let notice = model.notice {
                Text(verbatim: notice).font(.caption)
            }
        }
    }
}

struct DiagnosticsView: View {
    @Bindable var model: DiagnosticsModel

    var body: some View {
        Form {
            captureSection
            routeSection
            playbackSection
            distanceSection
            micSourceSection
            if let comparison = model.micComparison {
                MicComparisonSection(model: comparison)
            }
            if let recording = model.speechRecording {
                SpeechRecordingSection(model: recording)
            }
            speechSection
            resultsSection
            eventLogSection
        }
        .navigationTitle("Lumen diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var captureSection: some View {
        Section("Capture") {
            Picker("Config", selection: $model.selectedConfig) {
                ForEach(CaptureConfig.allCases) { config in
                    Text(config.rawValue).tag(config)
                }
            }
            .disabled(model.isCapturing)
            Text(model.selectedConfig.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                if model.isCapturing {
                    Button("Stop capture", role: .destructive) { Task { await model.stopCapture() } }
                } else {
                    Button("Start capture") { Task { await model.startCapture() } }
                }
                Spacer()
                if model.canResume {
                    Button("Tap to resume") { Task { await model.resume() } }
                }
            }

            LabeledContent("State", value: model.state.label)
            Text(model.banner)
                .font(.footnote.monospaced())
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(model.isCapturing ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if let error = model.lastError {
                Text(error).foregroundStyle(.red).font(.footnote)
            }

            levelMeter
            LabeledContent("Chunks", value: "\(model.chunkCount) · last \(model.lastChunkFrames) frames · conv. errors \(model.capture.conversionErrorCount)")
        }
    }

    private var levelMeter: some View {
        VStack(alignment: .leading, spacing: 4) {
            let rms = model.level.rmsDBFS
            let peak = model.level.peakDBFS
            ProgressView(value: Self.meterValue(rms))
                .tint(peak > -3 ? .red : .green)
            Text(String(format: "RMS %.1f dBFS · peak %.1f dBFS", rms, peak))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    static func meterValue(_ dBFS: Double) -> Double {
        min(1, max(0, (dBFS + 60) / 60))
    }

    private var routeSection: some View {
        Section("Route (§3.11)") {
            if let snapshot = model.snapshot {
                LabeledContent("Inputs", value: snapshot.inputs.map(\.oneLine).joined(separator: "; "))
                LabeledContent("Outputs", value: snapshot.outputs.map(\.oneLine).joined(separator: "; "))
                LabeledContent("Category / mode", value: "\(snapshot.categoryShort) / \(snapshot.modeShort)")
                LabeledContent("Options", value: snapshot.options.joined(separator: ", "))
                LabeledContent("Sample rate", value: "\(Int(snapshot.sampleRate.rounded())) Hz")
                LabeledContent("IO buffer", value: String(format: "%.1f ms", snapshot.ioBufferDuration * 1000))
                LabeledContent("Channels in / out", value: "\(snapshot.inputChannels) / \(snapshot.outputChannels)")
                LabeledContent("Latency in / out", value: String(format: "%.1f / %.1f ms", snapshot.inputLatency * 1000, snapshot.outputLatency * 1000))
                LabeledContent("HQ", value: snapshot.hq.summary)
                LabeledContent("setPreferredInput", value: snapshot.preferredInputSucceeded.map { $0 ? "succeeded" : "FAILED" } ?? "not attempted")
                LabeledContent("Engine input", value: snapshot.engineInputFormat ?? model.capture.inputFormatDescription ?? "-")
                LabeledContent("Region / OS", value: "\(snapshot.region) / \(snapshot.osVersion)")
            } else {
                Text("No session yet. Start capture (or play a tone) to configure the session.")
                    .foregroundStyle(.secondary)
            }
            Text(DeviceInfo.summary).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var playbackSection: some View {
        Section("Playback (through AirPods while capturing)") {
            HStack {
                Button("Play test tone") { Task { await model.playTestTone() } }
                Spacer()
                Button("Speak 🇸🇪") { Task { await model.speakTestPhrase(.swedish) } }
                Button("Speak 🇬🇧") { Task { await model.speakTestPhrase(.english) } }
            }
            .buttonStyle(.bordered)
            HStack {
                Text(String(format: "Rate %.2f×", model.speakRate))
                Slider(value: $model.speakRate, in: 0.5...2.0, step: 0.05)
            }
            HStack {
                Button("Stop playback") { model.stopPlayback() }
                Spacer()
                Button("Clear latency") { model.clearLatencySamples() }
            }
            .font(.footnote)
            LabeledContent("Play → first buffer") {
                if let median = model.medianLatencyMs {
                    Text(String(format: "median %.1f ms (n=%d)", median, model.latencySamplesMs.count))
                } else {
                    Text("no measurements")
                }
            }
            if model.playback.isSpeaking {
                Text("Speaking…").foregroundStyle(.secondary)
            }
        }
    }

    private var distanceSection: some View {
        Section("Speaker-distance test") {
            Text("Another person reads a paragraph from testdata/scripts/sv-paragraphs.md at the chosen distance. Run every config × 1/2/4 m × quiet/noisy. Also record the wearer reading, whispering and speaking quietly (Track D1).")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Picker("Distance", selection: $model.distanceMeters) {
                Text("1 m").tag(1)
                Text("2 m").tag(2)
                Text("4 m").tag(4)
            }
            .pickerStyle(.segmented)
            Picker("Noise", selection: $model.noiseCondition) {
                ForEach(NoiseCondition.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Speaker", selection: $model.speakerRole) {
                ForEach(SpeakerRole.allCases) { Text($0.rawValue).tag($0) }
            }

            if model.distanceRecording != nil {
                Button("Stop run and save", role: .destructive) { model.stopDistanceRecording() }
            } else {
                Button("Start run") { model.startDistanceRecording() }
                    .disabled(!model.isCapturing)
            }
            Button("Export last 60 s as WAV") { model.exportLast60s() }
                .font(.footnote)

            ForEach(model.distanceRuns) { run in
                Text(run.summaryLine).font(.caption.monospaced())
            }
            if let url = model.lastExportURL {
                Text("Last file: \(url.lastPathComponent)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var micSourceSection: some View {
        Section("Mic-source sanity check") {
            Text(MicSourceTest.instructions).font(.footnote).foregroundStyle(.secondary)
            Button(model.micSourceRunning ? "Listening for taps (5 s)…" : "Run mic-source check") {
                Task { await model.runMicSourceCheck() }
            }
            .disabled(!model.isCapturing || model.micSourceRunning)
            if let result = model.micSourceResult {
                Text(result.summary).font(.caption.monospaced())
            }
        }
    }

    private var speechSection: some View {
        Section("Speech locales") {
            Button(model.localeCheckRunning ? "Checking…" : "Check SpeechTranscriber locales") {
                Task { await model.checkSpeechLocales() }
            }
            .disabled(model.localeCheckRunning)
            if let report = model.localeReport {
                Text(report).font(.caption2.monospaced()).textSelection(.enabled)
            }
        }
    }

    private var resultsSection: some View {
        Section("Results") {
            Button("Copy results as Markdown") { model.copyResultsMarkdown() }
            if let copied = model.copiedAt {
                Text("Copied \(copied.formatted(date: .omitted, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var eventLogSection: some View {
        Section("Event log (newest first)") {
            ForEach(model.eventLog) { entry in
                Text("\(entry.time.formatted(date: .omitted, time: .standard))  \(entry.text)")
                    .font(.caption2.monospaced())
            }
        }
    }
}
