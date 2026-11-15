import Foundation
import Testing
@testable import Lumen

/// A110 (D198): Dela and Publicera are offered only once the exam has been started (D190); before that they are
/// hidden and one line says what to do. 0 ElevenLabs (D180).
@MainActor
@Suite struct A110SharingAfterStartTests {
    private static func exam() -> Drill {
        Drill(title: "Fysikprovet", summary: DrillSummary(subject: "Fysik", grade: "åk 9", covers: ""),
              items: [DrillItem(question: "Vad är en kraft?", short: "Något som ändrar rörelse.", long: "Något som ändrar rörelse. Den mäts i newton.")])
    }

    @Test func anExamThatIsNotStartedIsNotOfferedForSharing() {
        var drill = Self.exam()
        drill.audioStarted = false
        #expect(!DrillShareGate.isOffered(drill))
    }

    @Test func aStartedExamIsOffered() {
        var drill = Self.exam()
        drill.audioStarted = nil // started (every exam before K71, and after Starta prov)
        #expect(DrillShareGate.isOffered(drill))
        drill.audioStarted = true
        #expect(DrillShareGate.isOffered(drill))
    }

    @Test func aTextReadAloudFollowsTheSameRule() {
        var text = Drill.text(title: "Biologiprovet", summary: DrillSummary(subject: "Biologi", grade: "åk 9", covers: ""),
                              parts: [DrillItem.textPart("Växter gör socker av ljus.", part: .para)])
        text.audioStarted = false
        #expect(!DrillShareGate.isOffered(text))
        text.audioStarted = nil
        #expect(DrillShareGate.isOffered(text))
    }

    @Test func theLineIsDeangelosWording() {
        #expect(DrillShareGate.startFirstLine == "Starta provet först så kan du dela det.")
    }
}
