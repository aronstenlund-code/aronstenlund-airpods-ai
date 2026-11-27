import Testing
@testable import Lumen

/// Ke93 (4): red first against main – the busy card says why once ("Vår server är upptagen."), the button says Försök igen.
@MainActor
@Suite struct Ke93RedTests {
    @Test func theBusyCardSaysWhyOnceAndTheButtonSaysTryAgain() {
        #expect(LumenProblem.overloaded.text == "Vår server är upptagen.")
        #expect(LumenProblem.overloaded.actionTitle == "Försök igen")
    }
}
