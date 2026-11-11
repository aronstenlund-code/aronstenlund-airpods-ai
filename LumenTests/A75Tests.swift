import Foundation
import Testing
@testable import Lumen

/// A75 (Aron 20:41): the name wakes Lumen as it is misheard too, only where it addresses Lumen, and real words one
/// letter away do not.
@MainActor
@Suite struct A75Tests {
    @Test func misheardNamesWake() {
        for heard in ["Lumen", "Lumin", "Lummen", "Lomen", "Lymen", "Limen", "Loomen", "Lumens", "Lumén", "Luman"] {
            #expect(VoiceChannel.parse("\(heard), vad är fotosyntes?").intent == .instruction("vad är fotosyntes"), "\(heard)")
        }
        #expect(VoiceChannel.parse("Lu men, vad är klockan?").intent == .instruction("vad är klockan"), "two words")
    }

    @Test func realWordsAndMidSentenceDoNot() {
        #expect(VoiceChannel.parse("Lumpen var tuff").intent == nil)
        #expect(VoiceChannel.parse("Luren ringer igen").intent == nil)
        #expect(VoiceChannel.parse("Jag berättade om Lumin för min kompis").intent == nil, "not where it addresses")
        #expect(VoiceChannel.parse("Lampan är trasig").intent == nil)
        #expect(VoiceChannel.parse("Ludvig, kom hit").intent == nil)
    }

    @Test func aNearMissIsLogged() {
        #expect(VoiceChannel.nearMissName(in: "Lurman, vad är klockan?") == "Lurman")
        #expect(VoiceChannel.nearMissName(in: "Lumen, vad är klockan?") == nil, "taken, not a miss")
        #expect(VoiceChannel.nearMissName(in: "Vad är klockan?") == nil)
    }

    @Test func theNameIsOneRowPerName() {
        #expect(WakeWord.variants.contains("lumin"))
        #expect(WakeWord.variantsByName["earmind"]?.isEmpty == false)
    }
}
