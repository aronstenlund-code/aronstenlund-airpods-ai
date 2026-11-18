import Foundation
import Testing
@testable import Lumen

/// D233 (A151): a quiet tone while an answer searches the web, when the first word takes more than 1.5 s. At most
/// once per answer, never in Provläge, and none when the first word comes first. No ElevenLabs: the tone is made in
/// the playback graph and the answers here are scripted.
@MainActor
@Suite struct A151SearchToneTests {
    @MainActor final class Host: SearchToneHost {
        var searchToneAllowed = true
        var tones = 0
        var lines: [String] = []
        func playSearchTone() { tones += 1 }
        func modeLog(_ line: String) { lines.append(line) }
    }

    /// The wait, by hand: it ends when the test opens it.
    @MainActor final class Gate {
        private(set) var asked: [Duration] = []
        private var isOpen = false
        private var waiting: [CheckedContinuation<Void, Never>] = []

        func sleep(_ duration: Duration) async {
            asked.append(duration)
            if isOpen { return }
            await withCheckedContinuation { waiting.append($0) }
        }

        func open() {
            isOpen = true
            for one in waiting { one.resume() }
            waiting = []
        }
    }

    private func part(_ host: Host, _ gate: Gate) -> SearchToneController {
        let part = SearchToneController()
        part.host = host
        part.sleep = { await gate.sleep($0) }
        return part
    }

    // MARK: - The server's event

    @Test func theServersSearchingEventIsRead() throws {
        let event = SSEEvent(name: "searching", data: #"{"tool":"web_search","ms":412}"#)
        #expect(try AnswerSSEDecoder.decode(event) == .searching(AnswerSearching(tool: "web_search", ms: 412)))
        // A payload this build cannot read is still the signal.
        #expect(try AnswerSSEDecoder.decode(SSEEvent(name: "searching", data: "")) == .searching(AnswerSearching()))
    }

    @Test func theEngineTellsTheSinkBeforeTheFirstWord() async {
        let provider = FakeAnswerProvider(events: [
            .searching(AnswerSearching(tool: "web_search", ms: 300)),
            .meta(AnswerMeta(isQuestion: true)), .delta("Nilen."), .done(AnswerDone(answered: true)),
        ])
        let engine = makeTestAnswerEngine(provider)
        let sink = FakeAnswerSink()
        engine.sink = sink
        engine.answer(ActivationRequest(query: "vilken är världens längsta flod", trigger: .text, language: .swedish), context: AnswerContext())
        #expect(await waitUntil { sink.completed.count == 1 })
        #expect(sink.searches == [0], "once, and before any word")
        #expect(sink.deltas == ["Nilen."])
    }

    // MARK: - The wait and the rules

    @Test func theToneComesWhenTheFirstWordTakesLongerThanTheWait() async {
        let host = Host(), gate = Gate()
        let part = part(host, gate)
        part.answerBegan()
        part.searching(since: Date())
        let wait = part.pending
        #expect(host.tones == 0, "nothing before the wait is over")
        gate.open()
        await wait?.value
        #expect(host.tones == 1 && part.played)
        #expect(gate.asked.count == 1)
        if let asked = gate.asked.first {
            #expect(asked > .milliseconds(1_400) && asked <= SearchToneController.wait, "1.5 s from the search")
        }
        #expect(SearchToneController.wait == .milliseconds(1_500))
    }

    @Test func noToneWhenTheFirstWordComesFirst() async {
        let host = Host(), gate = Gate()
        let part = part(host, gate)
        part.answerBegan()
        part.searching(since: Date())
        let wait = part.pending
        part.firstWord()
        #expect(part.pending == nil, "the wait is called off")
        gate.open()
        await wait?.value
        #expect(host.tones == 0 && !part.played)
    }

    @Test func atMostOncePerAnswer() async {
        let host = Host(), gate = Gate()
        gate.open()
        let part = part(host, gate)
        part.answerBegan()
        part.searching(since: Date())
        await part.pending?.value
        part.searching(since: Date()) // a second `searching` for the same answer
        await part.pending?.value
        #expect(host.tones == 1)

        part.answerBegan() // the next answer may have its own
        part.searching(since: Date())
        await part.pending?.value
        #expect(host.tones == 2)
    }

    @Test func noToneWhereItIsNotAllowedOrAfterTheAnswerEnded() async {
        let host = Host(), gate = Gate()
        gate.open()
        let part = part(host, gate)
        host.searchToneAllowed = false // Provläge, paused, the iPhone's own speaker …
        part.answerBegan()
        part.searching(since: Date())
        await part.pending?.value
        #expect(host.tones == 0 && !part.played)

        host.searchToneAllowed = true
        let closed = Gate()
        part.sleep = { await closed.sleep($0) }
        part.answerBegan()
        part.searching(since: Date())
        let wait = part.pending
        part.answerEnded()
        closed.open()
        await wait?.value
        #expect(host.tones == 0)
    }

    @Test func anAnswerMadeAheadCountsFromTheSearch() async {
        // D80: the search began 2 s before the pause was over. Nothing is left of the wait, and no clock is asked.
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        #expect(SearchToneController.left(since: now.addingTimeInterval(-2), now: now) == .zero)
        #expect(SearchToneController.left(since: now.addingTimeInterval(-1), now: now) == .milliseconds(500))
        #expect(SearchToneController.left(since: now, now: now) == .milliseconds(1_500))

        let host = Host(), gate = Gate()
        let part = part(host, gate)
        part.answerBegan()
        part.searching(since: now.addingTimeInterval(-2), now: now)
        await part.pending?.value
        #expect(host.tones == 1 && gate.asked.isEmpty)

        // … and when its words are already there, they come in the same breath: no tone.
        part.answerBegan()
        part.searching(since: now.addingTimeInterval(-2), now: now)
        let wait = part.pending
        part.firstWord()
        await wait?.value
        #expect(host.tones == 1)
    }

    @Test func neverInProvlägeAndOnlyWhereTheAnswerIsSpoken() {
        func allowed(listening: Bool = true, mode: ConversationMode = .standard, instructing: Bool = false,
                     answering: Bool = true, speaking: Bool = false, trigger: ActivationTrigger? = .auto,
                     builtInSpeaker: Bool = false) -> Bool {
            SearchToneController.allowed(listening: listening, mode: mode, instructing: instructing, answering: answering,
                                         speaking: speaking, trigger: trigger, builtInSpeaker: builtInSpeaker)
        }
        #expect(allowed() && allowed(trigger: .text) && allowed(mode: .interview, trigger: .overheard))
        #expect(!allowed(mode: .prov), "D233: never in Provläge")
        #expect(!allowed(mode: .prov, trigger: .tutor))
        #expect(!allowed(mode: .rizz) && !allowed(mode: .social) && !allowed(trigger: .rizz))
        #expect(!allowed(trigger: .interviewPrep), "shown, not spoken")
        #expect(!allowed(listening: false), "paused or stopped: the tone must not start the audio again")
        #expect(!allowed(answering: false), "the answer ended or was called off")
        #expect(!allowed(instructing: true))
        #expect(!allowed(speaking: true), "Lumen is still talking")
        #expect(!allowed(builtInSpeaker: true), "the microphone would hear it")
    }

    // MARK: - The tone

    /// Kelly's variant A (Ke81), as her script makes it: 0.36 s, peak −26 dBFS, zero at both ends.
    @Test func theToneIsKellysQuietOne() {
        let rate = 24_000.0
        let samples = ToneShape.searchTone(sampleRate: rate)
        #expect(samples.count == Int(rate * 0.36))
        let peak = Double(samples.map { abs($0) }.max() ?? 0)
        #expect(abs(20 * log10(peak) - (-26)) < 0.05, "peak −26 dBFS: about a sixth of the cues' level")
        #expect(samples.first == 0 && abs(samples.last ?? 1) < 0.000_1, "it starts and ends at zero: no click")
        // Soft in (90 ms) and out (200 ms): a tenth of the way in it is still far below the peak.
        #expect(abs(samples[Int(rate * 0.009)]) < Float(peak) * 0.1)
        #expect(samples[Int(rate * 0.345)...].allSatisfy { abs($0) < Float(peak) * 0.1 })
        // 392 Hz: 141 whole periods in 0.36 s, so about 282 zero crossings (the faint octave adds none).
        let crossings = zip(samples, samples.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
        #expect((270...295).contains(crossings))
        #expect(ToneShape.searchTone(sampleRate: 0).isEmpty)

        // The other tones sound as before (level 0.3, 10 ms linear fades).
        let cue = ToneShape.samples(frequency: 880, duration: 0.07, level: 0.3, fade: 0.01, sampleRate: rate)
        #expect(cue.count == Int(rate * 0.07) && (cue.map { abs($0) }.max() ?? 0) > 0.25)
        #expect(cue.first == 0)
        #expect(ToneShape.samples(frequency: 880, duration: 0, level: 0.3, fade: 0.01, sampleRate: rate).isEmpty)
    }

    // MARK: - With a scripted answer, through the model

    private func model(_ h: ControllerHarness, _ provider: FakeAnswerProvider) -> ListeningModel {
        ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                       activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                       voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
    }

    private var searched: [AnswerEvent] {
        [.searching(AnswerSearching(tool: "web_search", ms: 350)),
         .meta(AnswerMeta(reconstructedQuestion: "vilken är världens längsta flod", confidence: 0.9, isQuestion: true)),
         .delta("Nilen, 6 650 km."), .done(AnswerDone(answered: true))]
    }

    @Test func aSlowSearchedAnswerGetsOneToneBeforeItsWords() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: searched)
        provider.delay = .milliseconds(150) // the words come a while after `searching`
        let model = model(h, provider)
        #expect(model.searchTone.host === model)
        model.searchTone.sleep = { _ in } // the 1.5 s are over at once
        await model.startListening()
        model.submitText("vilken är världens längsta flod")
        #expect(await waitUntil { model.conversation.answers.last?.answer.hasSuffix("6 650 km.") == true })
        #expect(h.playback.searchTones == 1, "one tone, and only one")
        #expect(model.searchTone.played)
    }

    @Test func aQuickSearchedAnswerGetsNoTone() async {
        let h = ControllerHarness()
        let gate = Gate()
        let model = model(h, FakeAnswerProvider(name: "cloud", events: searched)) // the words come at once
        model.searchTone.sleep = { await gate.sleep($0) }
        await model.startListening()
        model.submitText("vilken är världens längsta flod")
        #expect(await waitUntil { model.conversation.answers.last?.answer.hasSuffix("6 650 km.") == true })
        #expect(model.searchTone.pending == nil, "the first word called the wait off")
        gate.open()
        try? await Task.sleep(for: .milliseconds(50)) // the called-off wait runs out
        #expect(h.playback.searchTones == 0 && !model.searchTone.played)
    }

    @Test func nothingSoundsWhenLumenIsNotListening() async {
        let h = ControllerHarness()
        let model = model(h, FakeAnswerProvider(name: "cloud", events: []))
        model.searchTone.sleep = { _ in }
        #expect(!model.searchToneAllowed)
        model.answerSearching() // a late event after the session ended
        await model.searchTone.pending?.value
        #expect(h.playback.searchTones == 0)
    }
}
