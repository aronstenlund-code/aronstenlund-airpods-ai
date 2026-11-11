import Foundation
import Testing
@testable import Lumen

/// A14: Toby's T6 findings on voice commands. Requirement: 0 false hits.
@Suite(.serialized) struct VoiceCommandT6Tests {
    @Test func theNameInsideASentenceIsNoAddress() {
        for sentence in ["Jag berättade om Lumen för min kompis igår.", "vi använde lumen i skolan idag", "har du testat Lumen pausa",
                         "min kompis sa lumen byt till provläge"] {
            #expect(VoiceChannel.parse(sentence).intent == nil, "\(sentence)")
        }
        #expect(VoiceChannel.parse("Ja precis. Lumen, mer skämt").intent == .instruction("mer skämt"))
        #expect(VoiceChannel.parse("Hej Lumen, pausa").intent == .pause)
        #expect(VoiceChannel.parse("Okej Lumen byt till frågor").intent == .switchTo(.standard))
    }

    @Test func misheardVerbFormsStillWork() {
        let table = CommandBook.shared.table
        #expect(table.action(forWhole: "skippar låten", named: false) == .nextTrack)
        #expect(table.action(forWhole: "pausar musiken", named: false) == .pauseMusic)
        #expect(table.action(forWhole: "Föra låten.", named: false) == .previousTrack)
        #expect(VoiceChannel.parse("Lumen, by till provläge").intent == .switchTo(.prov))
        #expect(VoiceChannel.parse("Lumen, skippar låten").intent == .music(.nextTrack))
    }

    @Test func shortWordsAreNeverStretched() {
        let table = CommandBook.shared.table
        #expect(table.action(forWhole: "högre", named: true) == .louder)
        #expect(table.action(forWhole: "kortare", named: true) == .shorter)
        #expect(table.action(forWhole: "kortar", named: true) == nil, "a single word must be exact")
        #expect(table.universal("hoppa där") == nil)
    }

    @Test func noFalseHitsFromTheLooseMatch() {
        let table = CommandBook.shared.table
        for sentence in ["hörde du låten", "spara den till sen", "nästa lektion", "pausen är slut", "förra veckan",
                         "jag gillar låten", "stoppa bollen", "det var kul", "vad sa hon", "spelar roll", "det var fem"] {
            #expect(table.action(forWhole: sentence, named: false) == nil, "\(sentence)")
        }
    }

    @Test func looseForms() {
        #expect(CommandTable.loose("skippar låten") == CommandTable.loose("skippa låten"))
        #expect(CommandTable.loose("by till") == "byt till")
        #expect(CommandTable.isClose("föra låten", "förr låten"))
        #expect(!CommandTable.isClose("högre", "högre"), "one word: only the exact match counts")
    }
}

@MainActor
@Suite struct LoneNameTests {
    @Test func lumenAloneJoinsTheNextSegment() async {
        let h = ControllerHarness()
        let suite = "lumen.tests.a14.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   modeSettings: ModeSettings(defaults: defaults))
        await model.startListening()
        model.receiveFinalTranscript("Lumen.")
        #expect(h.controller.eventLog.contains { $0.text.hasPrefix("Name alone:") }) // A75: "Ja?" and 8 s
        model.receiveFinalTranscript("Spara det.")
        #expect(h.controller.eventLog.contains { $0.text == "Voice: command saveAnswer" })
    }
}
