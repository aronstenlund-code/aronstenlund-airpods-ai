import Foundation
import Testing
@testable import Lumen

/// A48 (D122, K35): phone tools: the `tool_call` event, `tools_available` and `tool_round` in the request, yes/no,
/// and the server's times.
@MainActor
@Suite struct PhoneToolsTests {
    @Test func theToolCallEventDecodesWithItsInputAsItCame() throws {
        let data = #"{"id":"toolu_1","name":"calendar_add","input":{"title":"Tandläkaren","start":"2026-11-12T15:00","all_day":false},"confirm":"Ska jag lägga in Tandläkaren torsdag den 12 november klockan 15:00 i kalendern?","kind":"write"}"#
        guard case .toolCall(let call)? = try AnswerSSEDecoder.decode(SSEEvent(name: "tool_call", data: data)) else {
            Issue.record("not a tool call")
            return
        }
        #expect(call.tool == .calendarAdd)
        #expect(call.input["title"]?.string == "Tandläkaren" && call.input["all_day"]?.bool == false)
        #expect(call.confirm?.hasPrefix("Ska jag lägga in") == true)
        let timer = #"{"id":"toolu_2","name":"timer_start","input":{"seconds":300},"confirm":null,"kind":"run"}"#
        guard case .toolCall(let run)? = try AnswerSSEDecoder.decode(SSEEvent(name: "tool_call", data: timer)) else {
            Issue.record("not a tool call")
            return
        }
        #expect(run.confirm == nil && run.input["seconds"]?.number == 300)
    }

    @Test func toolsAndTheRoundGoInTheRequestThroughClamped() throws {
        var context = AnswerContext()
        context.toolsAvailable = PhoneTool.allCases.map(\.rawValue)
        let call = PhoneToolCall(id: "toolu_1", name: "alarm_set", input: .object(["time": .string("06:30")]), confirm: "Ska jag ställa ett larm?", kind: "write")
        context.toolRound = ToolRound(call: call, status: .ok, result: .object(["alarm_id": .string("A")]))
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "väck mig halv sju", mode: "push_to_talk", language: "sv", context: context))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((json["tools_available"] as? [String])?.count == PhoneTool.allCases.count) // A58: 8 with call_contact and music_open
        let round = try #require(json["tool_round"] as? [String: Any])
        #expect(round["status"] as? String == "ok")
        let sentCall = try #require(round["call"] as? [String: Any])
        #expect(sentCall["id"] as? String == "toolu_1" && (sentCall["input"] as? [String: Any])?["time"] as? String == "06:30")
        #expect((round["result"] as? [String: Any])?["alarm_id"] as? String == "A")
        let plain = try #require(try JSONSerialization.jsonObject(with: CloudAnswerProvider.encodeBody(
            AnswerRequest(fragment: "x", mode: "auto", language: "sv"))) as? [String: Any])
        #expect(plain["tools_available"] == nil && plain["tool_round"] == nil)
    }

    @Test func yesNoOrSomethingElse() {
        #expect(ToolConfirmReply.parse("Ja") == .yes)
        #expect(ToolConfirmReply.parse("ja, gör det") == .yes)
        #expect(ToolConfirmReply.parse("Okej.") == .yes)
        #expect(ToolConfirmReply.parse("nej tack") == .no)
        #expect(ToolConfirmReply.parse("Avbryt") == .no)
        #expect(ToolConfirmReply.parse("vad är fotosyntes") == .other)
        #expect(ToolConfirmReply.parse("ja men vad händer om jag vill flytta den till nästa vecka i stället") == .other)
    }

    @Test func theServersTimes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(PhoneToolTime.date("2026-11-12T15:00", calendar: calendar))
        #expect(calendar.component(.hour, from: start) == 15 && calendar.component(.day, from: start) == 12)
        let day = try #require(PhoneToolTime.date("2026-11-12", calendar: calendar))
        #expect(calendar.component(.hour, from: day) == 0)
        #expect(PhoneToolTime.text(start, calendar: calendar) == "2026-11-12T15:00")
        #expect(PhoneToolTime.date("i morgon", calendar: calendar) == nil)
        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 22)))
        let alarm = try #require(PhoneToolTime.nextTime("06:30", now: evening, calendar: calendar))
        #expect(calendar.component(.day, from: alarm) == 11 && calendar.component(.hour, from: alarm) == 6)
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 5)))
        let same = try #require(PhoneToolTime.nextTime("06:30", now: morning, calendar: calendar))
        #expect(calendar.component(.day, from: same) == 10)
        #expect(PhoneToolTime.nextTime("25:00", now: morning, calendar: calendar) == nil)
    }

    @Test func aNoteIsSavedInAnteckningar() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("a48-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = NotesStore(directory: directory)
        store.add(text: "Köp mjölk")
        #expect(store.notes.first?.answers.first?.answer == "Köp mjölk")
        #expect(store.notes.first?.title == "Anteckning")
    }
}
