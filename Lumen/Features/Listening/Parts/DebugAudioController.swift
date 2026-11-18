import Foundation
import Observation

// A142 (D218 point 4): the whole part is compiled only for us and our testers (Debug, Beta), never for the App Store.
#if LUMEN_TESTMODE

/// D221 (A138, G7 step 7d): what the test mode's debug audio uses of `ListeningModel`. The audio stream is the
/// model's: the part asks for a subscription to the capture's chunks and gives it back; it changes nothing in what is
/// recorded, routed or played.
@MainActor
protocol DebugAudioHost: AnyObject {
    /// The session's log and turn records, read for the piece's report.
    var controller: SessionController { get }
    var isListening: Bool { get }
    var mode: ConversationMode { get }
    var conversation: Conversation { get }
    func subscribeToAudio() -> (id: UUID, stream: AsyncStream<AudioChunk>)
    func unsubscribeFromAudio(_ id: UUID)
}

/// A76 (D140; A138, G7 step 7d): the test mode. While it is on and Lumen listens, the microphone's audio is kept in
/// pieces of a minute, each with what was heard, what the turns became and the log lines in it, and sent to us for
/// debugging. Moved unchanged out of `ListeningModel`. Only for testers who switched it on (or a test account, K43);
/// the indicator says "Testläge · ljud skickas" the whole time, and a piece the server refuses is deleted.
@MainActor
@Observable
final class DebugAudioController {
    @ObservationIgnored weak var host: (any DebugAudioHost)?
    /// The test mode switch (Inställningar, or on for a test account by K43's flag).
    var testMode: TestModeSettings?
    /// True while the microphone's audio is being kept for us (the indicator says "Testläge · ljud skickas").
    private(set) var isRecording = false
    @ObservationIgnored private var subscription: UUID?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var writer: DebugAudioWriter?
    @ObservationIgnored let store = DebugPieceStore()

    @ObservationIgnored var client: DebugAudioClient?
    @ObservationIgnored private var flagChecked = false
    @ObservationIgnored private var uploading = false

    /// Starts or stops keeping the audio to match the switch, the server and the listening.
    func update() {
        guard let host else { return }
        if !flagChecked, client != nil {
            flagChecked = true
            Task { await refreshFlag() }
        }
        let wanted = (testMode?.isEnabled ?? false) && !(testMode?.serverRefused ?? false) && host.isListening
        if wanted, subscription == nil {
            let store = self.store
            let writer = DebugAudioWriter(store: store) { [weak self] url, start, end in
                Task { @MainActor in self?.pieceFinished(url: url, start: start, end: end) }
            }
            let (id, stream) = host.subscribeToAudio()
            subscription = id
            self.writer = writer
            task = Task.detached {
                for await chunk in stream { await writer.append(chunk.samples) }
                await writer.close()
            }
            isRecording = true
            host.controller.log("Test mode: the audio is kept and sent for debugging (A76, D140)")
        } else if !wanted, subscription != nil {
            stop()
        }
    }

    #if DEBUG
    /// The screenshots (Kelly Ke48): Lyssnar as it looks while the audio is sent; nothing is recorded.
    func stageForScreenshot() { isRecording = true }
    #endif

    func stop() {
        guard let id = subscription else { return }
        subscription = nil
        host?.unsubscribeFromAudio(id) // ends the stream; the writer closes the last piece
        task = nil
        writer = nil
        isRecording = false
    }

    /// A finished minute: what was heard, what the turns became and the log lines in it, next to the audio.
    private func pieceFinished(url: URL, start: Date, end: Date) {
        guard let host else { return }
        let inside = { (date: Date) in date >= start.addingTimeInterval(-1) && date <= end.addingTimeInterval(1) }
        var piece = DebugPiece(id: url.deletingPathExtension().lastPathComponent, startedAt: start, endedAt: end,
                               audioFile: url.lastPathComponent, mode: host.mode.rawValue)
        piece.heard = host.conversation.finalSegments.filter { inside($0.startedAt) }.map { .init(at: $0.startedAt, text: $0.text) }
        piece.turns = host.controller.turns.records.filter { inside($0.at) }.map {
            .init(at: $0.at, heard: $0.fragment, outcome: $0.outcome.rawValue, reason: $0.reason, status: $0.status)
        }
        piece.log = host.controller.eventLog.filter { inside($0.time) }.suffix(200).map {
            String(format: "%.2f ", $0.time.timeIntervalSince(start)) + $0.text
        }
        piece.answers = host.conversation.answers.filter { inside($0.createdAt) }.map {
            .init(at: $0.createdAt, text: "\($0.question) → \($0.answer)")
        }
        store.save(piece)
        host.controller.log("Test mode: a piece of \(Int(end.timeIntervalSince(start))) s is waiting for upload (A76)")
        Task { await uploadPieces() }
    }

    /// K43's flag once per launch: a test account is switched on, an account the server refuses is told so.
    private func refreshFlag() async {
        guard let client, let testMode, let flag = await client.flag() else { return }
        testMode.applyServerFlag(flag)
        if flag { await uploadPieces() }
        update()
    }

    /// The switch in Settings: the tester's own choice goes to the server (K43 `opt_in`/`opt_out`).
    func switched() async {
        guard let testMode else { return }
        let on = testMode.isEnabled
        if !on {
            testMode.serverRefused = false
            update()
        }
        if let client, let flag = await client.setOptIn(on) {
            testMode.serverRefused = on && !flag
            if testMode.serverRefused {
                host?.controller.log("Test mode: the server does not take audio from this account (K43 needs an email sign-in)")
                for piece in store.pending() { store.delete(piece) } // never kept when it cannot be sent
            }
        }
        update()
    }

    /// Sends the waiting pieces one at a time, oldest first; a sent piece leaves the phone (D140 point 4).
    func uploadPieces() async {
        guard let client, !uploading else { return }
        uploading = true
        defer { uploading = false }
        for piece in store.pending() {
            switch await client.upload(DebugTurnBody(piece: piece, audio: store.audio(of: piece))) {
            case .sent:
                store.delete(piece)
            case .refused:
                testMode?.serverRefused = true
                for piece in store.pending() { store.delete(piece) }
                host?.controller.log("Test mode: the server refused the upload; the pieces are deleted and nothing more is kept (A76)")
                update()
                return
            case .failed:
                return // no network: the pieces wait (at most 120 or 48 h)
            }
        }
    }
}
#endif
