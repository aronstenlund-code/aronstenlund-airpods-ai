import Foundation
import Testing
@testable import Lumen

/// Deangelo 2026-11-27 04:10: Inställningar short and plain – the most important first, the rest under Avancerat, every
/// row with one sentence about what it does, nothing a student does not understand.
@Suite struct SettingsLayoutTests {
    @Test func theMostImportantComeFirstInThisOrder() {
        #expect(SettingsRow.top == [.language, .activationWords, .voice, .credits])
    }

    @Test func whatMustBeFoundIsNotUnderAdvanced() {
        for row in [SettingsRow.history, .privacy, .account] {
            #expect(SettingsRow.always.contains(row), "\(row) is always visible")
            #expect(!SettingsRow.advanced.contains(row))
        }
    }

    @Test func everyRowIsInOnePlace() {
        let all = SettingsRow.top + SettingsRow.always + SettingsRow.advanced
        #expect(Set(all).count == all.count, "no row twice")
        #expect(Set(all) == Set(SettingsRow.allCases), "no row forgotten")
    }

    @Test func everyRowSaysWhatItDoesInOneShortSentence() {
        for row in SettingsRow.allCases {
            #expect(!row.title.isEmpty)
            let detail = row.detail
            #expect(detail.hasSuffix("."), "\(row): a sentence")
            #expect(detail.dropLast().filter { $0 == "." }.isEmpty, "\(row): one sentence")
            #expect(detail.count <= 70, "\(row): short (\(detail.count))")
        }
    }

    @Test func nothingTechnicalOnTheRows() {
        // Whole words, as written ("dB" is not the "db" in "Feedback", "VAD" not the Swedish "Vad").
        let names: Set<String> = ["Scribe", "VAD", "dB", "API"]
        let stems = ["latens", "diagnostik", "transkription", "kalibrering"]
        for row in SettingsRow.allCases {
            let text = row.title + " " + row.detail
            let words = Set(text.split { !$0.isLetter }.map(String.init))
            #expect(words.isDisjoint(with: names), "\(row): \(words.intersection(names))")
            for stem in stems {
                #expect(!text.lowercased().contains(stem), "\(row) says \(stem)")
            }
        }
    }
}
