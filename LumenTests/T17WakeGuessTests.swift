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

/// Toby 1 T17 finding 8: in chatter the name comes in the middle, before the question.
struct T17NameInTheMiddleTests {
    @Test func theQuestionAfterTheNameIsAsked() {
        let first = VoiceChannel.parse("Du pratade länge om Lumen, vem styr handlet?")
        #expect(first.intent == .instruction("vem styr handlet"))
        #expect(first.before == nil, "the chatter before the name is not asked")
        #expect(VoiceChannel.parse("Du vet att det är Lumen och hur länge har han ju funnits?").intent
            == .instruction("hur länge har han ju funnits"))
        #expect(VoiceChannel.parse("ja alltså Lumen, när är provet").intent == .instruction("när är provet"))
    }

    @Test func theNameInAnOrdinarySentenceStaysQuiet() {
        for sentence in ["Jag berättade om Lumen för min kompis igår.", "har du testat Lumen pausa",
                         "min kompis sa lumen byt till provläge", "jag tyckte Lumen var bra", "vi använde Lumen när vi pluggade",
                         "Jag frågade Lumen vad det betyder", "Har du hört om Lumen och appen?",
                         "min kompis pratade om Lusen, vad heter den"] {
            #expect(VoiceChannel.parse(sentence).intent == nil, "\(sentence)")
        }
    }
}
