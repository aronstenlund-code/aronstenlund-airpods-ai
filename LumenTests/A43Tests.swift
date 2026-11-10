import Foundation
import Testing
@testable import Lumen

/// A43 (N1, K33): what the student knows for an exam, and K33's reasons as shown.
@MainActor
@Suite struct A43Tests {
    @Test func knownIsRightTheLastTwoTimes() {
        let ok = StudyHistory.Entry(date: "2026-11-09", ok: true)
        let wrong = StudyHistory.Entry(date: "2026-11-10", ok: false)
        let history = ["mitos": [wrong, ok, ok], "Cellandning": [ok, ok], "osmos": [ok, wrong], "klorofyll": [ok]]
        #expect(ListeningModel.known(history) == ["Cellandning", "mitos"])
        let many = Dictionary(uniqueKeysWithValues: (0..<10).map { ("begrepp \($0)", [ok, ok]) })
        #expect(ListeningModel.known(many).count == 6)
    }

    @Test func theReasonStartsWithACapital() {
        #expect(ReadinessView.reason("fel senast") == "Fel senast")
        #expect(ReadinessView.reason("") == "")
    }
}
