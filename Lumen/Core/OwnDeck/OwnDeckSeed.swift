import Foundation

#if LUMEN_TESTMODE
/// T58 (Toby) and the screenshots: `-SeedOwnDeck 1` at launch puts one own deck of three cards in an empty store, and
/// the phone's voice is then silent files (`SilentPhoneVoice`), so the editor and the player can be tried in the
/// Simulator without a microphone. Only in the test builds (Debug and Beta), never in Release.
enum OwnDeckSeed {
    static let argument = "SeedOwnDeck"

    static func isRequested(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: argument)
    }

    /// Adds the deck when there is none. True when it did.
    @MainActor
    @discardableResult
    static func seed(into store: OwnDeckStore, language: String = AppLanguage.current.code) -> Bool {
        guard store.decks.isEmpty else { return false }
        let swedish = language == "sv"
        let cards: [(String, String)] = swedish
            ? [("Vad heter Sveriges huvudstad?", "Stockholm."), ("Vad är fotosyntes?", "Växter gör socker och syre av ljus, vatten och koldioxid."),
               ("Vad är roten ur hundra?", "Tio.")]
            : [("What is the capital of Sweden?", "Stockholm."), ("What is photosynthesis?", "Plants make sugar and oxygen from light, water and carbon dioxide."),
               ("What is the square root of a hundred?", "Ten.")]
        store.save(OwnDeck(title: swedish ? "Glosor vecka 12" : "Vocabulary week 12",
                           cards: cards.map { OwnCard(question: $0.0, answer: $0.1) },
                           language: swedish ? "sv" : "en"))
        return true
    }
}
#endif
