import Foundation
import Testing
@testable import Lumen

/// A27 (Oscar O28) narrowed by A35 (D113, RESTRIKTIONER B5): only health, crisis and ID numbers stop a memory by
/// code. O28's other categories are kept now (A5), and its 20 study memories still pass.
@Suite struct SensitiveMemoryTests {
    static let stopped = [
        "Har epilepsi", "Har celiaki och äter glutenfritt", "Tar Concerta varje morgon", "Har dyslexi", "Har en ätstörning",
        "Väger 45 kilo och vill gå ner", "Har mens och ont i magen", "Skär sig ibland när det är jobbigt",
        "Har haft självmordstankar", "Bästa kompisen Elin har ADHD", "Har ADHD-diagnos",
        "Personnummer 090314-1234", "Mitt lösenord är sommar2009", "Kontonummer 8327-9, 123 456 789-0",
    ]

    /// D113: no longer stopped by code (the model's own judgement and the user's Minne apply).
    static let keptNow = [
        "Är gay", "Fastar under ramadan", "Går i kyrkan varje söndag", "Röstade på Vänsterpartiet i skolvalet",
        "Kommer från Syrien", "Har snattat", "Mamma heter Karin och jobbar på ICA", "Bor i Rinkeby", "Röstar på Moderaterna",
    ]

    static let ordinary = [
        "Har prov i biologi på fredag", "Gillar korta svar", "Går i årskurs 9", "Läser religionskunskap", "Spelar fotboll",
        "Vill bli läkare", "Pluggar till högskoleprovet", "Vill ha exempel med fotboll", "Har svårt med bråk",
        "Har lånat en bok om rymden", "Gillar sjukt mycket fotboll", "Skriver en uppsats om brottslighet i Sverige",
        "Läser om kristendomen i religion", "Har prov i historia om judeförföljelsen", "Vill ha svar på engelska",
        "Ska till Gotland i sommar", "Läser kursen sex och samlevnad", "Gillar att laga mat", "Har prov om partiklar",
        "Tränar på hälsning på spanska", "Biologiprov fredag 14 nov", "Går i trean på gymnasiet",
    ]

    @Test(arguments: stopped) func healthCrisisAndIDNumbersStop(_ text: String) {
        #expect(SensitiveFilter.isSensitive(text), "\(text)")
    }

    @Test(arguments: keptNow + ordinary) func everythingElseIsKept(_ text: String) {
        #expect(!SensitiveFilter.isSensitive(text), "\(text)")
    }

    @Test func aStudyWordDoesNotHideTheRest() {
        #expect(SensitiveFilter.isSensitive("Pluggar trots att jag är deprimerad"))
        #expect(!SensitiveFilter.isSensitive("Övningsprov: öva på procent och ekvationer"), "A16's own memory")
    }
}
