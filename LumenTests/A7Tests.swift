import Foundation
import Testing
@testable import Lumen

/// A7: the preset commands in natural wordings, and no false hits inside ordinary sentences.
@Suite(.serialized) struct PresetCommandTests {
    @Test func noDefaultPhraseBelongsToTwoActions() {
        var owner: [String: CommandAction] = [:]
        for action in CommandAction.allCases {
            for phrase in action.defaultPhrases.map(CommandTable.normalized) {
                #expect(owner[phrase] == nil, "\(phrase): \(owner[phrase]?.rawValue ?? "") and \(action.rawValue)")
                owner[phrase] = action
            }
        }
    }

    @Test func levelOneVariantsRunOnThePhone() {
        let cases: [(CommandAction, [String])] = [
            (.repeatAnswer, ["upprepa", "säg det igen", "kan du upprepa", "vad sa du", "repetera"]),
            (.whisper, ["viska", "tystare", "prata tystare", "sänk volymen"]),
            (.louder, ["högre", "prata högre", "höj volymen"]),
            (.shorter, ["svara kortare", "kortare svar", "snabbare", "kortare"]),
            (.longer, ["svara längre", "längre svar", "utförligare svar"]),
            (.saveAnswer, ["spara det", "spara svaret", "spara det där"]),
            (.nextExam, ["vilket prov har jag härnäst", "när är nästa prov", "nästa prov"]),
        ]
        for (action, phrases) in cases {
            for phrase in phrases {
                #expect(VoiceChannel.parse("Lumen, \(phrase)").intent == .command(action), "\(phrase)")
            }
        }
    }

    @Test func levelTwoVariantsGoToTheBackendInOneWording() {
        let cases: [(String, [String])] = [
            ("utveckla", ["utveckla", "berätta mer", "mer om det", "utveckla svaret"]),
            ("förklara enklare", ["förklara enklare", "förklara", "enklare", "förklara det enklare"]),
            ("ge ett exempel", ["ge ett exempel", "ge mig ett exempel", "exempel"]),
            ("sammanfatta det viktigaste", ["sammanfatta", "summera", "sammanfatta det viktigaste"]),
            ("var säker", ["var säker", "dubbelkolla", "var noggrann"]),
            ("vad missade jag", ["vad missade jag", "vad har jag missat"]),
            ("tre alternativ", ["ge mig tre", "tre förslag", "tre alternativ"]),
            ("rädda mig", ["rädda mig", "hjälp mig ur det här"]),
        ]
        for (instruction, phrases) in cases {
            for phrase in phrases {
                #expect(VoiceChannel.parse("Lumen \(phrase)").intent == .instruction(instruction), "\(phrase)")
            }
        }
        #expect(VoiceChannel.parse("Lumen, testa mig på cellandning").intent == .instruction("förhör mig på cellandning"))
    }

    @Test func modeSwitchWordings() {
        for (words, mode) in [("byt till frågor", ConversationMode.standard), ("växla till provläge", .prov), ("gå till intervju", .interview),
                              ("starta socialt läge", .social), ("byta till rizzläge", .rizz), ("lyssna efter frågor", .standard)] {
            #expect(VoiceChannel.parse("Lumen, \(words)").intent == .switchTo(mode), "\(words)")
        }
    }

    /// The owner's examples and more: words inside a sentence are no command (0 false hits).
    @Test func ordinarySentencesAreNoCommands() {
        let sentences = [
            "jag vill byta till ett annat ämne", "kan du upprepa det för klassen", "hon sa viska",
            "vi måste prata högre i salen", "läraren sa att vi ska spara det till nästa lektion",
            "när är nästa prov i historia egentligen sa han", "det här är mer om det vi läste igår",
            "kan någon förklara enklare än boken", "ge ett exempel på en vulkan sa läraren", "jag var säker på svaret",
        ]
        for sentence in sentences {
            #expect(VoiceChannel.parse(sentence).intent == nil, "\(sentence)")
            #expect(CommandBook.shared.table.action(forWhole: sentence, named: false) == nil, "\(sentence)")
            #expect(CommandBook.shared.table.universal(sentence) == nil, "\(sentence)")
        }
    }

    @Test func universalWordsAreOnlyTheWholeUtterance() {
        let table = CommandBook.shared.table
        #expect(table.universal("Upprepa.") == .repeatAnswer)
        #expect(table.universal("viska") == .whisper)
        #expect(table.universal("snabbare") == .shorter)
        #expect(table.universal("utveckla") == .moreDetail)
        #expect(table.universal("upprepa efter mig") == nil)
        #expect(table.universal("utveckla teorin om evolution") == nil)
    }

    @Test func rememberVariantsAreMemoryNotForget() {
        #expect(VoiceChannel.parse("Lumen, glöm inte att provet är på fredag").intent == .remember("provet är på fredag"))
        #expect(VoiceChannel.parse("Lumen, glöm inte mitt prov").intent == .remember("mitt prov"))
        #expect(VoiceChannel.parse("Lumen, glöm att jag gillar fotboll").intent == .forget("jag gillar fotboll"))
    }
}

@Suite struct SessionLengthTests {
    @MainActor @Test func aSessionLengthOverridesTheSetting() async {
        let provider = FakeAnswerProvider(events: [.delta("Ja."), .done(AnswerDone(answered: true))])
        let engine = makeTestAnswerEngine(provider)
        engine.sessionLength = .short
        engine.answer(ActivationRequest(query: "vad är pi", trigger: .text, language: .swedish), context: AnswerContext())
        #expect(await waitUntil { provider.requests.count == 1 })
        #expect(provider.requests.first?.length == AnswerLength.short.rawValue)
    }
}
