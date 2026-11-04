import Foundation
import Testing
@testable import Lumen

@Suite struct SSELineParserTests {
    @Test func parsesNamedEventsSeparatedByBlankLines() {
        var parser = SSELineParser()
        var events: [SSEEvent] = []
        for line in Fixtures.answerSSE.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let event = parser.feed(line) { events.append(event) }
        }
        if let last = parser.flush() { events.append(last) }
        #expect(events.map(\.name) == ["meta", "delta", "delta", "done"])
        #expect(events[1].data == "{\"text\":\"Roten ur hundra \"}")
    }

    @Test func handlesCRLFCommentsAndMultiLineData() {
        var parser = SSELineParser()
        #expect(parser.feed(": keep-alive\r") == nil)
        #expect(parser.feed("event: delta\r") == nil)
        #expect(parser.feed("data: {\"text\":") == nil)
        #expect(parser.feed("data:\"x\"}") == nil)
        let event = parser.feed("\r")
        #expect(event == SSEEvent(name: "delta", data: "{\"text\":\n\"x\"}"))
        #expect(parser.flush() == nil)
    }

    @Test func eventWithoutNameAndFlushAtEnd() {
        var parser = SSELineParser()
        #expect(parser.feed("data: hello") == nil)
        #expect(parser.flush() == SSEEvent(name: nil, data: "hello"))
        #expect(parser.flush() == nil)
    }
}

@Suite struct AnswerSSEDecoderTests {
    private func events(_ sse: String) throws -> [AnswerEvent] {
        var parser = SSELineParser()
        var out: [AnswerEvent] = []
        for line in sse.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let event = parser.feed(line), let decoded = try AnswerSSEDecoder.decode(event) { out.append(decoded) }
        }
        return out
    }

    @Test func decodesTheReadmeExample() throws {
        let decoded = try events(Fixtures.answerSSE)
        #expect(decoded.count == 4)
        #expect(decoded[0] == .meta(AnswerMeta(reconstructedQuestion: "Vad är roten ur hundra?", confidence: 0.96, isQuestion: true, needsConfirmation: false)))
        #expect(decoded[1] == .delta("Roten ur hundra "))
        #expect(decoded[2] == .delta("är tio."))
        guard case .done(let done) = decoded[3] else { Issue.record("expected done"); return }
        #expect(done.answered)
        #expect(done.timing?.ttftMs == 410)
        #expect(done.usage?.model == "claude-haiku-5-5")
        #expect(done.usage?.inputTokens == 1010)
    }

    @Test func decodesNotAQuestionAndStreamError() throws {
        let skipped = try events(Fixtures.notAQuestionSSE)
        guard case .meta(let meta) = skipped[0] else { Issue.record("expected meta"); return }
        #expect(!meta.isQuestion)
        #expect(skipped[1] == .done(AnswerDone(answered: false, timing: nil, usage: nil)))

        let failed = try events(Fixtures.streamErrorSSE)
        #expect(failed.last == .error(AnswerFailure(code: "provider_error", message: "upstream closed", fallback: true)))
    }

    @Test func unknownEventsAreIgnoredAndBadJSONThrows() throws {
        #expect(try AnswerSSEDecoder.decode(SSEEvent(name: "ping", data: "{}")) == nil)
        #expect(throws: AnswerError.self) {
            try AnswerSSEDecoder.decode(SSEEvent(name: "delta", data: "not json"))
        }
    }

    @Test func decodesErrorBodies() {
        let backend = AnswerSSEDecoder.decodeErrorBody(Data("{\"error\":{\"code\":\"provider_quota\",\"message\":\"credits\",\"fallback\":true}}".utf8), status: 503)
        #expect(backend == AnswerFailure(code: "provider_quota", message: "credits", fallback: true))

        let auth = AnswerSSEDecoder.decodeErrorBody(Data("{\"code\":422,\"error_code\":\"anonymous_provider_disabled\",\"msg\":\"Anonymous sign-ins are disabled\"}".utf8), status: 422)
        #expect(auth.code == "anonymous_provider_disabled")
        #expect(auth.message == "Anonymous sign-ins are disabled")

        let plain = AnswerSSEDecoder.decodeErrorBody(Data("Bad Gateway".utf8), status: 502)
        #expect(plain.code == "http_502")
        #expect(plain.fallback == true)
    }
}

@Suite struct SentenceSplitterTests {
    private func split(_ chunks: [String]) -> [String] {
        var splitter = SentenceSplitter()
        var out: [String] = []
        for chunk in chunks { out += splitter.feed(chunk) }
        if let rest = splitter.flush() { out.append(rest) }
        return out
    }

    @Test func splitsOnTerminatorsFollowedBySpace() {
        #expect(split(["Roten ur hundra är tio. ", "Det är ", "enkelt! Eller hur? Ja."]) ==
                ["Roten ur hundra är tio.", "Det är enkelt!", "Eller hur?", "Ja."])
    }

    @Test func keepsDecimalsAbbreviationsAndInitials() {
        #expect(split(["Pi är ungefär 3.14 eller 3,14. Växter, t.ex. tall, är gröna. J. Smith sa det."]) ==
                ["Pi är ungefär 3.14 eller 3,14.", "Växter, t.ex. tall, är gröna.", "J. Smith sa det."])
        #expect(split(["Kriget började 1939. Det slutade 1945."]) == ["Kriget började 1939.", "Det slutade 1945."])
        #expect(split(["See e.g. the manual. Done."]) == ["See e.g. the manual.", "Done."])
    }

    @Test func waitsForWhitespaceAfterTerminatorAndFlushesTheRest() {
        var splitter = SentenceSplitter()
        #expect(splitter.feed("Vad är pi?") == ["Vad är pi?"], "a finished sentence goes to TTS at once")
        #expect(splitter.feed(" Ungefär 3.").isEmpty, "a decimal may continue in the next delta")
        #expect(splitter.feed("14.").isEmpty)
        #expect(splitter.flush() == "Ungefär 3.14.")
        #expect(splitter.flush() == nil)
    }

    @Test func releasesTheFirstSentenceOnTheDeltaThatEndsIt() {
        var splitter = SentenceSplitter()
        #expect(splitter.feed("Ro").isEmpty)
        #expect(splitter.feed("ten ur hundra är t").isEmpty)
        #expect(splitter.feed("io.") == ["Roten ur hundra är tio."], "deltas as the live backend sent them")
        #expect(splitter.flush() == nil)
    }

    @Test func abbreviationsStreamedInPiecesStayTogether() {
        var splitter = SentenceSplitter()
        #expect(splitter.feed("Djur bl.").isEmpty)
        #expect(splitter.feed("a. katter. ") == ["Djur bl.a. katter."])
    }

    @Test func aStrayTerminatorInTheNextDeltaIsNotSpoken() {
        var splitter = SentenceSplitter()
        #expect(splitter.feed("Vad?") == ["Vad?"])
        #expect(splitter.feed("! Okej. ") == ["Okej."])
    }

    @Test func multipleTerminatorsAndQuotes() {
        #expect(split(["Vad?! Jaså. \"Hej.\" Okej."]) == ["Vad?!", "Jaså.", "\"Hej.\"", "Okej."])
    }
}

@Suite struct ConversationAnswerTests {
    @Test func streamingAnswerMovesIntoHistoryWhenComplete() {
        var c = Conversation()
        c.beginAnswer(question: "roten ur hundra", source: "cloud")
        #expect(!c.isEmpty)
        c.setAnswerQuestion("Vad är roten ur hundra?")
        c.appendAnswerText("Roten ur hundra ")
        c.appendAnswerText("är tio. ")
        #expect(c.streamingAnswer?.answer == "Roten ur hundra är tio. ")
        c.completeAnswer(latencyMs: 812)
        #expect(c.streamingAnswer == nil)
        #expect(c.answers.count == 1)
        #expect(c.answers[0].question == "Vad är roten ur hundra?")
        #expect(c.answers[0].answer == "Roten ur hundra är tio.")
        #expect(c.answers[0].latencyMs == 812)
        #expect(c.answers[0].source == "cloud")
    }

    @Test func emptyAnswersAreDroppedAndNewAnswerReplacesStreaming() {
        var c = Conversation()
        c.beginAnswer(question: "a", source: "mock")
        c.completeAnswer()
        #expect(c.answers.isEmpty)

        c.beginAnswer(question: "first", source: "mock")
        c.appendAnswerText("half")
        c.beginAnswer(question: "second", source: "mock")
        #expect(c.streamingAnswer?.question == "second")
        #expect(c.streamingAnswer?.answer == "")
        c.cancelAnswer()
        #expect(c.streamingAnswer == nil)
    }

    @Test func recentQAIsOldestFirstAndLimited() {
        var c = Conversation()
        for i in 0..<5 {
            c.append(AnswerTurn(question: "q\(i)", answer: "a\(i)", source: "mock"))
        }
        #expect(c.recentQA(limit: 3) == [AnswerContext.QA(q: "q2", a: "a2"), AnswerContext.QA(q: "q3", a: "a3"), AnswerContext.QA(q: "q4", a: "a4")])
    }

    @Test func requestClampsToBackendLimits() {
        let long = String(repeating: "x", count: 7000)
        let context = AnswerContext(transcript: long,
                                    recentQA: (0..<8).map { AnswerContext.QA(q: "q\($0)", a: String(repeating: "a", count: 500)) },
                                    prepTerms: (0..<40).map { "term\($0)" })
        let request = AnswerRequest(fragment: String(repeating: "f", count: 1200), mode: "text", language: "sv", context: context)
        #expect(request.fragment.count == AnswerRequest.fragmentLimit)
        #expect(request.context.transcript.count == AnswerContext.transcriptLimit)
        #expect(request.context.recentQA.count == AnswerContext.qaLimit)
        #expect(request.context.recentQA.first?.q == "q2", "the newest pairs are kept")
        #expect(request.context.recentQA.first?.a.count == AnswerContext.qaFieldLimit)
        #expect(request.context.prepTerms.count == AnswerContext.prepTermLimit)
    }

    @Test func requestFromActivationUsesBackendModeAndLanguage() {
        let activation = ActivationRequest(query: "vad är pi", trigger: .answerLast, language: .swedish)
        let request = AnswerRequest(activation: activation)
        #expect(request.mode == "push_to_talk")
        #expect(request.language == "sv")
        #expect(request.fragment == "vad är pi")
        let english = AnswerRequest(activation: ActivationRequest(query: "what is pi", trigger: .auto, language: .english))
        #expect(english.mode == "auto")
        #expect(english.language == "en")
    }
}
