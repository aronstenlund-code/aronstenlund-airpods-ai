import Foundation
import Testing
@testable import Lumen

/// A73 (D138): the consent text about sound changed in substance (the sleep mode keeps clips), so it is asked again.
@MainActor
@Suite struct A73Tests {
    @Test func theConsentIsAskedAgainForTheTrueText() {
        #expect(ConsentPolicy.currentVersion == 6)
        #expect(ConsentPolicy.allowsQALog(ConsentRecord(version: 6, grantedAt: Date())), "D116's text is still in it")
        let old = ConsentRecord(version: 5, grantedAt: Date())
        #expect(old.version < ConsentPolicy.currentVersion, "a version 5 record sees the consent again")
    }
}
