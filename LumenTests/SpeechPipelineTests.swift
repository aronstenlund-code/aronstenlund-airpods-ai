import Foundation
import Testing
@testable import Lumen

/// D78: whole utterances, Scribe's pause detection per mode, the local VAD gate.
@Suite struct SentenceBufferTests {
    private func sentences(_ text: String) -> (done: [String], rest: String?) {
        var buffer = SentenceBuffer()
        let done = buffer.append(text)
        return (done, buffer.flush())
    }

    @Test func questionAndExclamationEndASentence() {
        #expect(sentences("Vad är pi? Hej! Och sen").done == ["Vad är pi?", "Hej!"])
        #expect(sentences("Vad är pi? ").rest == nil)
    }

    @Test func aPeriodEndsASentenceOnlyBeforeACapital() {
        #expect(sentences("Det regnar. Ta paraply.").done == ["Det regnar."])
        #expect(sentences("Det regnar. ta paraply").done.isEmpty)
    }

    @Test func swedishAbbreviationsAndNumbersAreNotSentenceEnds() {
        #expect(sentences("Ta t.ex. Stockholm som exempel. Sen").done == ["Ta t.ex. Stockholm som exempel."])
        #expect(sentences("Det kostar ca. Tio kronor").done.isEmpty)
        #expect(sentences("Mötet är kl. Tre idag").done.isEmpty)
        #expect(sentences("Kapitel 1. Inledning").done.isEmpty)
        #expect(sentences("Pi är 3.14 ungefär. Bra").done == ["Pi är 3.14 ungefär."])
    }

    @Test func longTextIsCutAtAWord() {
        var buffer = SentenceBuffer(maxChars: 20)
        let done = buffer.append("ett två tre fyra fem sex sju åtta nio")
        #expect(done.count == 1)
        #expect((done.first?.count ?? 99) <= 20)
    }
}

@Suite struct UtteranceAssemblerTests {
    @Test func aronsCutSentenceBecomesOneUtterance() {
        // Aron's test 2026-11-07 17:46: "Det är en annan . Ja, obrutet." arrived as two finals.
        var assembler = UtteranceAssembler()
        #expect(assembler.final("Det är en annan .").isEmpty)
        #expect(assembler.final("Ja, obrutet.").isEmpty, "a period at the end of a commit waits")
        #expect(assembler.flush() == "Det är en annan Ja, obrutet.")
        #expect(assembler.pending == nil)
    }

    @Test func aQuestionIsPassedOnAtOnce() {
        var assembler = UtteranceAssembler()
        #expect(assembler.final("Vad är skillnaden mellan") == [])
        #expect(assembler.final("mitos och meios?") == ["Vad är skillnaden mellan mitos och meios?"])
        #expect(assembler.pending == nil)
    }

    @Test func thePartialShowsThePendingWords() {
        var assembler = UtteranceAssembler()
        _ = assembler.final("Det är en annan")
        #expect(assembler.display(partial: "fråga") == "Det är en annan fråga")
        #expect(UtteranceAssembler().display(partial: "hej") == "hej")
    }

    @Test func aLonePeriodIsNothing() {
        var assembler = UtteranceAssembler()
        #expect(assembler.final(" . ").isEmpty)
        #expect(assembler.flush() == nil)
    }
}

@Suite struct ScribeTuningTests {
    @Test func scribeCommitsBeforeTheUsersPauseIsOver() {
        // D80: the pause per mode (1.0 / 1.2 / 1.5 / 0.8 s) minus the 0.4 s lead, never below 0.3 s.
        #expect(abs(ScribeTuning.forMode(.standard).silenceSeconds - 0.6) < 0.001)
        #expect(abs(ScribeTuning.forMode(.prov).silenceSeconds - 0.8) < 0.001)
        #expect(abs(ScribeTuning.forMode(.interview).silenceSeconds - 1.1) < 0.001)
        #expect(abs(ScribeTuning.forMode(.social).silenceSeconds - 0.4) < 0.001)
        #expect(abs(ScribeTuning.forMode(.prov, pause: 2.0).silenceSeconds - 1.6) < 0.001, "follows the user's setting")
        #expect(ScribeTuning.forMode(.rizz, pause: 0.5).silenceSeconds == 0.3)
    }

    @Test func theSocketURLCarriesThemExplicitlyAndNoTimestamps() throws {
        let token = ScribeToken(token: "t1", model_id: "scribe_v2_realtime", ws_url: "wss://api.elevenlabs.io/v1/speech-to-text/realtime",
                                language_code: "swe", extra_query: "enable_logging=false&filter_background_audio=true")
        let url = try #require(token.url(language: .swedish, keyterms: [], tuning: .forMode(.interview)))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        #expect(value("vad_silence_threshold_secs") == "1.10")
        #expect(value("vad_threshold") == "0.15")
        #expect(value("min_speech_duration_ms") == "100")
        #expect(value("filter_background_audio") == "true")
        #expect(value("include_timestamps") == nil, "cannot be combined with filter_background_audio")
        #expect(items.filter { $0.name == "filter_background_audio" }.count == 1)
    }
}

@Suite struct SpeechGateTests {
    private func window(_ value: Int16) -> [Int16] { [Int16](repeating: value, count: SpeechGate.windowSamples) }

    @Test func silenceIsHeldBackAndSpeechGetsItsPreRoll() {
        var gate = SpeechGate(scribeSilence: 1.0)
        #expect(gate.decide(window(1), probability: 0.1).isEmpty)
        #expect(gate.decide(window(2), probability: 0.1).isEmpty)
        #expect(gate.decide(window(3), probability: 0.1).isEmpty)
        let opened = gate.decide(window(4), probability: 0.9)
        #expect(gate.isOpen)
        #expect(opened.count == 3 * SpeechGate.windowSamples, "two windows of pre-roll and the speech")
        #expect(opened.first == 2, "the oldest silence is dropped")
    }

    @Test func pausesLongEnoughForScribeStayOpenThenItCloses() {
        var gate = SpeechGate(scribeSilence: 1.0)
        let hangover = SpeechGate.hangover(for: 1.0)
        #expect(hangover == 6, "1.0 + 0.3 s = six 256 ms windows")
        _ = gate.decide(window(1), probability: 0.9)
        for _ in 0..<hangover {
            #expect(!gate.decide(window(0), probability: 0.1).isEmpty, "Scribe hears the pause and commits")
        }
        #expect(gate.decide(window(0), probability: 0.1).isEmpty)
        #expect(!gate.isOpen)
    }

    @Test func chunksAreCollectedIntoWindows() {
        var gate = SpeechGate(scribeSilence: 1.0)
        let chunk = [Int16](repeating: 0, count: 640)
        var windows = 0
        for _ in 0..<13 { windows += gate.collect(chunk).count }
        #expect(windows == 2, "13 × 640 = 8320 samples = two whole windows")
    }
}

@MainActor
@Suite struct UtterancesThroughTheCoordinatorTests {
    @Test func twoFinalsBecomeOneUtteranceAfterTheHold() async {
        let h = CoordinatorHarness()
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })

        h.provider?.emit.yield(STTResult(text: "Det är en annan .", isFinal: true))
        h.provider?.emit.yield(STTResult(text: "Ja, obrutet.", isFinal: true))

        #expect(await waitUntil { h.sink.finals.count == 1 })
        #expect(h.sink.finals == ["Det är en annan Ja, obrutet."])
    }
}
