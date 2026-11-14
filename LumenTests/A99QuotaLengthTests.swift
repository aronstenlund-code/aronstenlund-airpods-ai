import Foundation
import Testing
@testable import Lumen

/// A99 (D175, D176, K61): Nytt prov proposes at most what is left of the month, and the server's length class per
/// question reaches the phone.
@MainActor
@Suite struct A99QuotaLengthTests {
    @Test func theServersQuotaIsRead() throws {
        let json = #"{"used":13,"limit":15,"left":2,"suggest":2,"per":"month","resets":"2026-12-01"}"#
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(json.utf8))
        #expect(quota.left == 2 && quota.suggestedQuestions == 2 && !quota.isUsedUp)
        let old = try JSONDecoder().decode(DrillQuota.self, from: Data(#"{"used":3,"limit":15}"#.utf8))
        #expect(old.left == 12 && old.suggestedQuestions == 12, "list's quota without left/suggest")
        #expect(DrillQuota(used: 0, limit: 40).suggestedQuestions == 20, "never more than 20 (D146)")
        #expect(DrillQuota(used: 15, limit: 15, serverLeft: 0, suggest: 0).isUsedUp)
    }

    @Test func nyttProvProposesWhatIsLeft() throws {
        let (model, _) = try A84VoiceTempoTests().model()
        #expect(model.newDrillSettings.questions == 20, "no quota known: the standard")
        #expect(!model.quotaUsedUp)
        model.quota = DrillQuota(used: 12, limit: 15, serverLeft: 3, suggest: 3)
        #expect(model.newDrillSettings.questions == 3)
        #expect(model.newDrillQuestionRange == 1...3, "the server never makes more than is left")
        model.quota = DrillQuota(used: 15, limit: 15, serverLeft: 0, suggest: 0)
        #expect(model.quotaUsedUp, "said before Skapa frågor, not as a 402 afterwards")
    }

    @Test func theLengthClassComesWithTheItem() throws {
        let json = #"""
        {"drill":{"id":"d1","title":"Bio"},
         "items":[{"id":"i1","position":0,"question":"Varför?","short":"K.","long":"K. L.",
                   "audio":{"question":{"status":"done"},"long":{"status":"done"}},
                   "voice_chars":1200,"length_class":"longer"},
                  {"id":"i2","position":1,"question":"Hur?","short":"K.","long":"K. L.",
                   "audio":{"question":{"status":"done"},"long":{"status":"done"}}}],
         "audio":{"done":4,"total":4}}
        """#
        let view = try JSONDecoder().decode(DrillCloudView.self, from: Data(json.utf8))
        let drill = Drill.from(view)
        #expect(drill.items[0].lengthClass == .longer)
        #expect(drill.items[0].lengthClass?.label == "Lite längre än vanligt")
        #expect(drill.items[1].lengthClass == nil)
        #expect(DrillLengthClass(rawValue: "too_long") == .tooLong)
        #expect(DrillLengthClass.normal.label == nil, "a normal question says nothing")
    }
}
