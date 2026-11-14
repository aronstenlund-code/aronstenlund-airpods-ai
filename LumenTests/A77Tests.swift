import Foundation
import Testing
@testable import Lumen

/// A77 (K44, D118): "Vad kan EarMind?" reads the one list (`Shared/capabilities.json`, the server's too), and every
/// /answer says which permissions are granted, so "kan du sätta en timer?" is answered like the screen.
@MainActor
@Suite struct A77Tests {
    @Test func theScreenIsTheSharedList() throws {
        let list = try #require(CapabilityList.load(), "Shared/capabilities.json is in the app bundle")
        #expect(LumenCapability.all.map(\.id) == list.capabilities.map(\.id), "every row of the list, in its order")
        #expect(LumenCapability.all.contains { $0.id == "translate" } && LumenCapability.all.contains { $0.id == "web" })
        let timer = try #require(LumenCapability.all.first { $0.id == "timer" })
        #expect(timer.setup == .permission(.alarms))
        #expect(timer.say == "”\(WakeWord.name), sätt en timer på 10 minuter”", "the wake word as it is now (A75)")
        #expect(LumenCapability.all.first { $0.id == "spotify" }?.setup == .soon, "status kommer")
        #expect(LumenCapability.all.first { $0.id == "interview" }?.setup == .place("Byt läge"))
        #expect(LumenCapability.all.allSatisfy { $0.symbol != "sparkles" }, "every id has its symbol")
    }

    @Test func aRowWithAnUnknownGroupIsLeftOut() {
        let item = CapabilityList.Item(id: "x", group: "okänd", name: "X", say: "Lumen, x", status: "finns", permission: nil)
        #expect(CapabilityList.row(item) == nil)
        #expect(CapabilityList.spoken("Tryck Sov på kvällen") == "Tryck Sov på kvällen", "what you do is not quoted")
    }

    @Test func thePermissionsGoInTheContext() throws {
        #expect(LumenCapability.Permission.allCases.map(\.key) == ["calendar", "reminders", "alarms", "contacts"])
        #expect(LumenCapability.Permission(key: "alarms") == .alarms)
        var context = AnswerContext()
        context.capabilities = ["calendar", "alarms"]
        #expect(context.clamped.capabilities == ["calendar", "alarms"], "A48's lesson: a new field must be in `clamped`")
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "kan du sätta en timer?", mode: "auto", language: "sv",
                                                                context: context.clamped))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inner = try #require(json["context"] as? [String: Any])
        #expect((inner["capabilities"] as? [String]) == ["calendar", "alarms"])
        let none = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "hej", mode: "auto", language: "sv", context: AnswerContext()))
        let noneJSON = try #require(try JSONSerialization.jsonObject(with: none) as? [String: Any])
        #expect((noneJSON["context"] as? [String: Any])?["capabilities"] == nil, "unknown: nothing is sent")
    }
}
