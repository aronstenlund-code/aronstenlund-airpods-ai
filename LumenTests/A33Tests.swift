import Foundation
import Testing
@testable import Lumen

/// A33 (D109): the answer to "Har du prov snart? Säg vilket ämne och när.", asked aloud in the first start.
@Suite struct ExamAnswerTests {
    @Test func noDeclines() {
        for text in ["Nej.", "nej tack", "Inte nu", "jag har inget prov", "nä"] {
            #expect(ExamAnswer.isDecline(text), "\(text)")
        }
        for text in ["biologi på fredag", "nej, matte på tisdag", "ja, historia nästa vecka"] {
            #expect(!ExamAnswer.isDecline(text), "\(text)")
        }
    }

    @Test func aShortAnswerBecomesAStatement() throws {
        #expect(ExamAnswer.statement("Biologi på fredag.") == "jag har prov i biologi på fredag")
        #expect(ExamAnswer.statement("Ja, matte nästa tisdag") == "jag har prov i matte nästa tisdag")
        #expect(ExamAnswer.statement("Jag har prov i kemi på måndag") == "Jag har prov i kemi på måndag", "already a statement")
        let parsed = try #require(ProfileStatement.parse(ExamAnswer.statement("biologi på fredag")))
        #expect(parsed.subject != nil)
        #expect(parsed.examDate != nil)
    }
}
