import Foundation
import Testing
@testable import Lumen

/// A27 (Oscar O28): the app's net for sensitive memories, with O28's 27 sensitive and 20 ordinary cases
/// (`scripts/qa/o28_memory_sensitive_offline.mjs`).
@Suite struct SensitiveMemoryTests {
    static let sensitive = [
        "Har epilepsi", "Har celiaki och äter glutenfritt", "Tar Concerta varje morgon", "Har dyslexi", "Har en ätstörning",
        "Väger 45 kilo och vill gå ner", "Har mens och ont i magen", "Skär sig ibland när det är jobbigt",
        "Har haft självmordstankar", "Är gay", "Är bi", "Har en pojkvän som heter Ali", "Fastar under ramadan",
        "Går i kyrkan varje söndag", "Röstade på Vänsterpartiet i skolvalet", "Är med i Ungsocialisterna",
        "Kommer från Syrien", "Är romsk", "Har snattat", "Pappa sitter i fängelse", "Mamma heter Karin och jobbar på ICA",
        "Bästa kompisen Elin har ADHD", "Telefonnummer 070 123 45 67", "Mejl elin.k@gmail.com", "Instagram lisa_2009",
        "Har 2000 kr på kortet", "Bor i Rinkeby",
    ]

    static let ordinary = [
        "Har prov i biologi på fredag", "Gillar korta svar", "Går i årskurs 9", "Läser religionskunskap", "Spelar fotboll",
        "Vill bli läkare", "Pluggar till högskoleprovet", "Vill ha exempel med fotboll", "Har svårt med bråk",
        "Har lånat en bok om rymden", "Gillar sjukt mycket fotboll", "Skriver en uppsats om brottslighet i Sverige",
        "Läser om kristendomen i religion", "Har prov i historia om judeförföljelsen", "Vill ha svar på engelska",
        "Ska till Gotland i sommar", "Läser kursen sex och samlevnad", "Gillar att laga mat", "Har prov om partiklar",
        "Tränar på hälsning på spanska",
    ]

    @Test(arguments: sensitive) func sensitiveMemoriesStop(_ text: String) {
        #expect(SensitiveFilter.isSensitive(text), "\(text)")
    }

    @Test(arguments: ordinary) func studyMemoriesStay(_ text: String) {
        #expect(!SensitiveFilter.isSensitive(text), "\(text)")
    }

    @Test func aStudyWordDoesNotHideTheRest() {
        #expect(SensitiveFilter.isSensitive("Pluggar trots att jag är deprimerad"))
        #expect(!SensitiveFilter.isSensitive("Övningsprov: öva på procent och ekvationer"), "A16's own memory")
    }
}
