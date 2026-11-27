import Testing
@testable import Lumen

/// Ke95: red first against main (existing API only).
@MainActor
@Suite struct Ke95RedTests {
    @Test func theAirPodsCardHasOneWayOn() {
        #expect(LumenProblem.airPodsLostPaused.actionTitle == nil)
        #expect(LumenProblem.airPodsLostPaused.text == "Sätt i dem igen, eller tryck Lyssna igen för att lyssna vidare i högtalaren.")
    }

    @Test func theLinesUnderTheBadgeAreShorter() {
        #expect(ListeningCondition.noAirPods.line == "Inga AirPods – svaren spelas i högtalaren.")
        #expect(ListeningCondition.offline(phoneModel: true).line == "Inget nät – telefonens egen modell svarar.")
    }
}
