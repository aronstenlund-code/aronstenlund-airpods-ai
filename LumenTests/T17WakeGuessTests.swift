import Foundation
import Testing
@testable import Lumen

/// Toby 1 T17 finding 1: a word one letter from the name ("Lusen", "Limen") wakes only when it clearly addresses
/// Lumen; the name and its non-word variants wake as before.
@MainActor
@Suite struct T17WakeGuessTests {
    @Test func aGuessInAnOrdinarySentenceDoesNotWake() {
        #expect(VoiceChannel.parse("Lusen kom tillbaka efter en vecka.").intent == nil)
        #expect(VoiceChannel.parse("Limen torkade fort").intent == nil)
        #expect(VoiceChannel.parse("Lusen kan sprida sig i klassen").intent == nil)
        #expect(VoiceChannel.parse("Lusen är jobbig").intent == nil)
    }

    @Test func aGuessThatAddressesLumenWakes() {
        #expect(VoiceChannel.parse("Lusen, vad är klockan?").intent == .instruction("vad är klockan"), "a pause after it")
        #expect(VoiceChannel.parse("Limen vad är fotosyntes").intent == .instruction("vad är fotosyntes"), "a question word")
        #expect(VoiceChannel.parse("Lusen sätt en timer på fem minuter").intent != nil, "an instruction")
        #expect(VoiceChannel.parse("Lusen kan du förklara cellandning").intent != nil, "kan du …")
        #expect(VoiceChannel.parse("Lusen").intent == nil && VoiceChannel.wakeWord(in: "Lusen") != nil, "alone: the name, no intent")
    }

    @Test func theNameAndItsVariantsWakeAsBefore() {
        #expect(VoiceChannel.parse("Lumen kom ihåg att jag har prov").intent == .remember("jag har prov"))
        #expect(VoiceChannel.parse("Lumin berätta om Gustav Vasa").intent != nil)
        #expect(WakeWord.isConfident("Lummen") && !WakeWord.isConfident("Lusen") && !WakeWord.isConfident("Limen"))
    }
}
