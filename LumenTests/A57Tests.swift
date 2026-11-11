import Foundation
import Testing
@testable import Lumen

/// A57 (Kelly Ke28 F4): red only when Lumen cannot answer.
@MainActor
@Suite struct A57Tests {
    @Test func onlyWhatStopsAnswersIsRed() {
        #expect(LumenProblem.offline.stopsAnswers)
        #expect(LumenProblem.overloaded.stopsAnswers)
        #expect(LumenProblem.microphoneDenied.stopsAnswers)
        #expect(LumenProblem.cannotHear.stopsAnswers)
        #expect(!LumenProblem.voiceUnavailable.stopsAnswers, "answers go on with the iPhone's voice")
        #expect(!LumenProblem.airPodsDisconnected.stopsAnswers, "answers go on in the phone's speaker")
    }
}
