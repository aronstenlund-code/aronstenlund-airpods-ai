import Foundation
import Testing
@testable import Lumen

@Suite struct CommandMatcherTests {
    private let matcher = CommandMatcher()
    private let fission = UserCommand(keyword: "fission", instruction: "förklara fission och jämför med fusion")
    private let proCon = UserCommand(keyword: "för och emot", instruction: "ge argument för och emot")
    private let short = UserCommand(keyword: "om", instruction: "x")

    @Test func exactAndNormalisedMatches() {
        #expect(matcher.matches(in: "Fission!", commands: [fission]) == [fission])
        #expect(matcher.matches(in: "vad är fission egentligen", commands: [fission]) == [fission])
        #expect(matcher.matches(in: "kärnkraft för och emot", commands: [proCon, fission]) == [proCon])
        #expect(matcher.matches(in: "berätta om fusion", commands: [fission]).isEmpty, "fusion is not fission (distance 2 > 1)")
    }

    @Test func toleratesSmallSTTErrorsOnLongerWordsOnly() {
        #expect(matcher.matches(in: "förklara fisson", commands: [fission]) == [fission], "one edit on a 7-letter word")
        #expect(matcher.matches(in: "förklara fisjon", commands: [fission]).isEmpty, "two edits are too many below 9 letters")
        #expect(matcher.matches(in: "förklara fissionen", commands: [fission]).isEmpty, "two extra letters on a 7-letter word is too far")
        #expect(matcher.matches(in: "vi pratar on kärnkraft", commands: [short]).isEmpty, "short keywords need an exact match")
        #expect(matcher.matches(in: "berätta om kärnkraft", commands: [short]) == [short])
        #expect(CommandMatcher.tolerance(forTokenLength: 4) == 0)
        #expect(CommandMatcher.tolerance(forTokenLength: 5) == 1)
        #expect(CommandMatcher.tolerance(forTokenLength: 9) == 2)
    }

    @Test func multiWordKeywordsMatchInSequenceAndResultsFollowTextOrder() {
        #expect(matcher.matches(in: "emot och för", commands: [proCon]).isEmpty)
        let both = matcher.matches(in: "för och emot fission", commands: [fission, proCon])
        #expect(both == [proCon, fission], "ordered by where they occur in the text")
    }

    @Test func parsesSpokenSaveCommands() {
        let colon = CommandMatcher.parseSaveCommand("Spara kommando fission: förklara fission och jämför med fusion.")
        #expect(colon?.keyword == "fission")
        #expect(colon?.instruction == "förklara fission och jämför med fusion")

        let comma = CommandMatcher.parseSaveCommand("spara kommandot för och emot, ge argument för och emot")
        #expect(comma?.keyword == "för och emot")
        #expect(comma?.instruction == "ge argument för och emot")

        let bare = CommandMatcher.parseSaveCommand("spara kommando fusion förklara enkelt")
        #expect(bare?.keyword == "fusion")
        #expect(bare?.instruction == "förklara enkelt")

        let english = CommandMatcher.parseSaveCommand("Save command photosynthesis: explain step by step")
        #expect(english?.keyword == "photosynthesis")
        #expect(english?.instruction == "explain step by step")

        #expect(CommandMatcher.parseSaveCommand("spara kommando") == nil)
        #expect(CommandMatcher.parseSaveCommand("spara kommando fusion") == nil, "needs an instruction")
        #expect(CommandMatcher.parseSaveCommand("vad är fission") == nil)
    }
}

@MainActor
@Suite struct CommandStoreTests {
    @Test func savesReplacesDeletesAndPersists() {
        let directory = temporaryDirectory()
        let store = CommandStore(directory: directory)
        #expect(store.save(keyword: " ", instruction: "x") == nil)
        #expect(store.save(keyword: "fission", instruction: "förklara fission") != nil)
        #expect(store.save(keyword: "Fusion", instruction: "förklara fusion") != nil)
        #expect(store.commands.map(\.keyword) == ["Fusion", "fission"], "newest first")

        let replaced = store.save(keyword: "FISSION", instruction: "jämför med fusion")
        #expect(replaced?.instruction == "jämför med fusion")
        #expect(store.commands.count == 2, "same keyword replaces")
        #expect(store.commands.first { $0.keyword.lowercased() == "fission" }?.keyword == "FISSION")

        let long = String(repeating: "x", count: 400)
        #expect(store.save(keyword: "lång", instruction: long)?.instruction.count == CommandStore.instructionLimit)

        let reloaded = CommandStore(directory: directory)
        #expect(reloaded.commands.map(\.keyword) == store.commands.map(\.keyword))
        #expect(reloaded.matches(in: "vad är fission").map(\.keyword) == ["FISSION"])

        reloaded.delete(reloaded.commands[0])
        #expect(CommandStore(directory: directory).commands.count == 2)
    }

    @Test func matchesAreCappedAtTen() {
        let store = CommandStore(directory: temporaryDirectory())
        let words = ["alfa", "beta", "gamma", "delta", "epsilon", "zeta", "theta", "jota", "kappa", "lambda", "sigma", "omega"]
        for word in words { store.save(keyword: word, instruction: word) }
        let text = words.joined(separator: " ")
        #expect(store.matches(in: text).count == CommandStore.maxSent)
    }
}

@MainActor
@Suite struct GoalsStoreTests {
    @Test func storesCompactsTogglesAndPersists() {
        let directory = temporaryDirectory()
        let store = GoalsStore(directory: directory)
        #expect(store.compact == nil)

        store.set(text: "Kursen behandlar fotosyntes och cellandning.\nEleven ska kunna förklara klorofyll.")
        #expect(store.isEnabled)
        #expect(store.compact?.hasPrefix("Kursen behandlar fotosyntes och cellandning. Eleven ska kunna förklara klorofyll.") == true)
        #expect(store.compact?.contains("Nyckelord:") == true)
        #expect(store.terms.contains("fotosyntes"))

        store.setEnabled(false)
        #expect(store.compact == nil)
        let reloaded = GoalsStore(directory: directory)
        #expect(!reloaded.isEnabled)
        #expect(reloaded.text == store.text)

        reloaded.clear()
        #expect(GoalsStore(directory: directory).stored == nil)
    }

    @Test func longGoalsAreCutAtSentencesWithinTheLimit() {
        let sentence = "Eleven ska kunna förklara hur fotosyntes och cellandning hänger ihop i ekosystemet."
        let text = Array(repeating: sentence, count: 60).joined(separator: " ")
        let compact = GoalsStore.compact(text, terms: ["fotosyntes", "cellandning", "ekosystemet"], limit: GoalsStore.compactLimit)
        #expect(compact.count <= GoalsStore.compactLimit)
        #expect(compact.hasPrefix(sentence))
        #expect(compact.contains("\nNyckelord: fotosyntes, cellandning, ekosystemet"))
        #expect(!compact.contains(". E\n"), "cut between sentences")
        #expect(GoalsStore.compact("kort text", terms: [], limit: 100) == "kort text")
    }
}

@MainActor
@Suite struct ListeningCommandsAndGoalsTests {
    private func makeModel(provider: FakeAnswerProvider) -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   goals: GoalsStore(directory: temporaryDirectory()),
                                   commands: CommandStore(directory: temporaryDirectory()))
        return (h, model)
    }

    @Test func matchedCommandsAndGoalsTravelWithTheQuestion() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Svar."), .done(AnswerDone(answered: true))])
        let (_, model) = makeModel(provider: provider)
        model.commands.save(keyword: "fission", instruction: "jämför med fusion")
        model.goals.set(text: "Kursen handlar om kärnfysik och energi.")

        model.submitText("förklara fisson")
        #expect(await waitUntil { provider.requests.count == 1 })
        let context = provider.requests[0].context
        #expect(context.commands == [AnswerContext.Command(keyword: "fission", instruction: "jämför med fusion")])
        #expect(context.goals?.hasPrefix("Kursen handlar om kärnfysik och energi.") == true)

        model.goals.setEnabled(false)
        model.submitText("vad är pi")
        #expect(await waitUntil { provider.requests.count == 2 })
        #expect(provider.requests[1].context.goals == nil)
        #expect(provider.requests[1].context.commands.isEmpty)
    }

    @Test func spokenSaveCommandIsStoredConfirmedAndNotSent() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Svar."), .done(AnswerDone(answered: true))])
        let (_, model) = makeModel(provider: provider)
        model.activation.settings.mode = .auto
        await model.startListening()

        model.receiveFinalTranscript("Spara kommando fotosyntes: förklara steg för steg?")

        #expect(model.commands.commands.first?.keyword == "fotosyntes")
        #expect(model.commands.commands.first?.instruction == "förklara steg för steg")
        #expect(model.commandNotice == "Saved command \"fotosyntes\"")
        try? await Task.sleep(for: .milliseconds(100))
        #expect(provider.requests.isEmpty, "never sent as a question, even in auto mode")
        #expect(model.conversation.finalSegments.count == 1, "it stays in the transcript")
    }

    @Test func requestBodyCarriesGoalsAndCommands() {
        let context = AnswerContext(transcript: "", recentQA: [], prepTerms: [], goals: "Kursmål",
                                    commands: [AnswerContext.Command(keyword: "fission", instruction: "jämför")])
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "fission", mode: "push_to_talk", language: "sv", context: context))
        let json = String(decoding: data, as: UTF8.self)
        #expect(json == "{\"context\":{\"commands\":[{\"instruction\":\"jämför\",\"keyword\":\"fission\"}],\"goals\":\"Kursmål\"},\"fragment\":\"fission\",\"language\":\"sv\",\"mode\":\"push_to_talk\"}")

        let clamped = AnswerContext(goals: String(repeating: "g", count: 2_000),
                                    commands: (0..<12).map { AnswerContext.Command(keyword: "k\($0)", instruction: String(repeating: "i", count: 400)) }).clamped
        #expect(clamped.goals?.count == AnswerContext.goalsLimit)
        #expect(clamped.commands.count == AnswerContext.commandLimit)
        #expect(clamped.commands.first?.instruction.count == AnswerContext.commandFieldLimit)
        #expect(AnswerContext(goals: "").clamped.goals == nil)
    }
}
