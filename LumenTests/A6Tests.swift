import Foundation
import Testing
@testable import Lumen

/// A6.4: the command table, the user's phrases and the warnings.
@Suite struct CommandTableTests {
    @Test func defaultsMatchTheWholeUtteranceOnly() {
        let table = CommandTable.standard
        #expect(table.action(forWhole: "Spela musik.", named: false) == .musicHandOff)
        #expect(table.action(forWhole: "nästa låt", named: false) == .nextTrack)
        #expect(table.action(forWhole: "Förra låten!", named: false) == .previousTrack)
        #expect(table.action(forWhole: "pausa musiken", named: false) == .pauseMusic)
        #expect(table.action(forWhole: "det där var fel", named: false) == .wrong)
        #expect(table.action(forWhole: "sluta lyssna", named: false) == nil, "stop needs the name")
        #expect(table.action(forWhole: "sluta lyssna", named: true) == .stop)
    }

    @Test func wordsInsideASentenceNeverMatch() {
        let table = CommandTable.standard
        for text in ["jag vill spela musik på festen", "vad heter nästa låt på skivan", "kan du pausa musiken lite senare idag",
                     "det där var fel sa läraren om provet", "han sa förra låten var bäst"] {
            #expect(table.action(forWhole: text, named: false) == nil, "\(text)")
        }
    }

    @Test func prefixActionsKeepTheRest() {
        let table = CommandTable.standard
        #expect(table.prefix(in: "byt till provläge")?.action == .switchMode)
        #expect(table.prefix(in: "byt till provläge")?.rest == "provläge")
        #expect(table.prefix(in: "byta till intervju")?.rest == "intervju", "the longer phrase first")
        #expect(table.prefix(in: "förhör mig på fotosyntes")?.rest == "på fotosyntes")
        #expect(table.prefix(in: "vad är fotosyntes") == nil)
    }

    @Test func userPhrasesAddAndDefaultsCanBeRemoved() {
        var added: [CommandAction: [String]] = [.nextTrack: ["Byt låt"]]
        let removed: [CommandAction: Set<String>] = [.nextTrack: ["skip song"]]
        var table = CommandTable(added: added, removed: removed)
        #expect(table.action(forWhole: "byt låt", named: false) == .nextTrack)
        #expect(table.action(forWhole: "skip song", named: false) == nil)
        added[.quizMe] = ["testa mig"]
        table = CommandTable(added: added, removed: removed)
        #expect(table.prefix(in: "testa mig på cellandning")?.action == .quizMe)
    }
}

@MainActor
@Suite struct CommandPhraseStoreTests {
    private func makeStore() -> (CommandPhraseStore, CommandBook, UserDefaults) {
        let suite = "lumen.tests.phrases.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let book = CommandBook()
        return (CommandPhraseStore(defaults: defaults, book: book), book, defaults)
    }

    @Test func aPhraseIsSavedSharedAndRemembered() {
        let (store, book, defaults) = makeStore()
        #expect(store.add("Byt låt", to: .nextTrack).isEmpty)
        #expect(book.table.action(forWhole: "byt låt", named: false) == .nextTrack, "the parsers see it at once")
        #expect(store.userPhrases == ["byt låt"], "and Scribe gets it as a keyterm")
        let again = CommandPhraseStore(defaults: defaults, book: CommandBook())
        #expect(again.phrases(for: .nextTrack).contains("byt låt"))
        store.remove("byt låt", from: .nextTrack)
        #expect(!store.phrases(for: .nextTrack).contains("byt låt"))
    }

    @Test func aDefaultCanBeRemovedAndReset() {
        let (store, _, _) = makeStore()
        store.remove("spela musik", from: .musicHandOff)
        #expect(!store.phrases(for: .musicHandOff).contains("spela musik"))
        store.reset(.musicHandOff)
        #expect(store.phrases(for: .musicHandOff).contains("spela musik"))
    }

    @Test func conflictsBlockAndCommonWordsWarn() {
        let (store, _, _) = makeStore()
        #expect(store.add("pausa", to: .nextTrack) == [.usedBy(.musicHandOff)], "a phrase belongs to one action")
        #expect(!store.phrases(for: .nextTrack).contains("pausa"))
        #expect(store.warnings(for: "ja tack", action: .nextTrack) == [.commonWords])
        #expect(store.warnings(for: "vad händer nu", action: .pauseMusic).contains(.soundsLikeAQuestion))
        #expect(store.warnings(for: "ja tack", action: .stop).isEmpty, "after \"Lumen\" common words are safe")
        #expect(store.warnings(for: "  ", action: .stop) == [.empty])
        #expect(store.warnings(for: String(repeating: "a", count: 41), action: .stop) == [.tooLong])
    }
}

/// A6: the parsers read the shared table.
@Suite(.serialized) struct VoiceChannelMusicTests {
    @Test func musicAfterTheName() {
        #expect(VoiceChannel.parse("Lumen, nästa låt").intent == .music(.nextTrack))
        #expect(VoiceChannel.parse("Lumen förra låten").intent == .music(.previousTrack))
        #expect(VoiceChannel.parse("Lumen, pausa musiken").intent == .music(.pauseMusic))
        #expect(VoiceChannel.parse("Lumen, tillbaka till Lumen").intent == .music(.backToLumen))
        #expect(VoiceChannel.parse("Lumen, det där var fel").intent == .complaint)
        #expect(VoiceChannel.parse("Lumen, paus").intent == .pause)
        #expect(VoiceChannel.parse("Lumen, spela musik").intent == .pause)
        #expect(VoiceChannel.parse("Lumen, byt till provläge").intent == .switchTo(.prov))
        #expect(VoiceChannel.parse("Lumen, provläge").intent == .switchTo(.prov))
        #expect(VoiceChannel.parse("Lumen, förhör mig på fotosyntes").intent == .instruction("förhör mig på fotosyntes"))
    }

    @Test func musicWithoutTheName() {
        #expect(VoiceCommand.musicAction("Nästa låt.") == .nextTrack)
        #expect(VoiceCommand.musicAction("vad heter nästa låt") == nil)
        #expect(VoiceCommand.isMusicHandOff("spela musik"))
        #expect(VoiceCommand.isComplaint("det var fel"))
    }
}
