import AlarmKit
@preconcurrency import Contacts
import EventKit
import Foundation
import SwiftUI

/// A48 (D122): the phone tools on the phone. Kalender and Påminnelser through EventKit, timer and alarm through
/// AlarmKit (iOS 26), notes in the app's own Anteckningar. Permission is asked the first time a tool is used, never at
/// start. Every tool runs in its own nonisolated function with its own store, so nothing that is not Sendable crosses
/// actors (Swift 6).
@MainActor
final class LivePhoneTools: PhoneToolRunning {
    private let addNote: @MainActor (String) -> Void

    init(addNote: @escaping @MainActor (String) -> Void) {
        self.addNote = addNote
    }

    var available: [PhoneTool] { PhoneTool.allCases }

    func run(_ call: PhoneToolCall) async -> (status: ToolRound.Status, result: JSONValue?) {
        let input = call.input
        switch call.tool {
        case .calendarAdd:
            guard let title = input["title"]?.string, let start = PhoneToolTime.date(input["start"]?.string) else { return (.error, nil) }
            let allDay = input["all_day"]?.bool ?? false
            let end = PhoneToolTime.date(input["end"]?.string) ?? start.addingTimeInterval(allDay ? 86_400 : 3_600)
            return await Self.addEvent(title: title, start: start, end: end, allDay: allDay, location: input["location"]?.string)
        case .calendarList:
            guard let from = PhoneToolTime.date(input["from"]?.string), let toDay = PhoneToolTime.date(input["to"]?.string) else { return (.error, nil) }
            // A date without a time as "to" means the whole of that day.
            let to = input["to"]?.string?.contains("T") == true ? toDay : toDay.addingTimeInterval(86_400)
            return await Self.listEvents(from: from, to: max(to, from.addingTimeInterval(60)))
        case .reminderAdd:
            guard let title = input["title"]?.string else { return (.error, nil) }
            return await Self.addReminder(title: title, due: PhoneToolTime.date(input["due"]?.string))
        case .timerStart:
            guard let seconds = input["seconds"]?.number, seconds >= 1 else { return (.error, nil) }
            return await Self.startTimer(seconds: seconds, label: input["label"]?.string)
        case .alarmSet:
            guard let fire = PhoneToolTime.nextTime(input["time"]?.string) else { return (.error, nil) }
            return await Self.setAlarm(at: fire, label: input["label"]?.string)
        case .noteAdd:
            guard let text = input["text"]?.string, !text.isEmpty else { return (.error, nil) }
            addNote(text)
            return (.ok, .object(["ok": .bool(true)]))
        case .callContact:
            // A58 (K36): a number the user said (the server keeps only digits that were said, B6), else the contact.
            let number: String
            if let said = input["number"]?.string, let dialable = PhoneCall.dialable(said) {
                number = dialable
            } else if let name = input["name"]?.string, !name.isEmpty {
                switch await Self.lookUpContact(name) {
                case .found(let found): number = found
                case .several(let names): return (.error, .object(["error": .string("several"), "names": .array(names.map { .string($0) })]))
                case .none: return (.error, .object(["error": .string("no_contact")]))
                case .noPermission: return (.error, .object(["error": .string("no_permission")]))
                }
            } else {
                return (.error, .object(["error": .string("no_contact")]))
            }
            guard let url = PhoneCall.url(number), await UIApplication.shared.open(url) else {
                return (.error, .object(["error": .string("cannot_call")]))
            }
            return (.ok, .object(["ok": .bool(true)]))
        case .musicOpen:
            guard let query = input["query"]?.string, !query.isEmpty else { return (.error, nil) }
            let app = MusicSearch.spotifyURL(query)
            if let app, UIApplication.shared.canOpenURL(app), await UIApplication.shared.open(app) {
                return (.ok, .object(["ok": .bool(true)]))
            }
            if let web = MusicSearch.webURL(query), await UIApplication.shared.open(web) {
                return (.ok, .object(["ok": .bool(true), "web": .bool(true)]))
            }
            return (.error, .object(["error": .string("cannot_open")]))
        case nil:
            return (.error, nil)
        }
    }

    // MARK: EventKit

    nonisolated private static func addEvent(title: String, start: Date, end: Date, allDay: Bool,
                                             location: String?) async -> (status: ToolRound.Status, result: JSONValue?) {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToEvents()) == true else { return (.error, .object(["reason": .string("no_permission")])) }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = allDay
        event.location = location
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            return (.ok, .object(["event_id": .string(event.eventIdentifier ?? "")]))
        } catch {
            return (.error, .object(["reason": .string("save_failed")]))
        }
    }

    nonisolated private static func listEvents(from: Date, to: Date) async -> (status: ToolRound.Status, result: JSONValue?) {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToEvents()) == true else { return (.error, .object(["reason": .string("no_permission")])) }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }.prefix(20).map { event -> JSONValue in
            var item: [String: JSONValue] = ["title": .string(event.title ?? ""),
                                             "start": .string(PhoneToolTime.text(event.startDate)),
                                             "end": .string(PhoneToolTime.text(event.endDate))]
            if let location = event.location, !location.isEmpty { item["location"] = .string(location) }
            return .object(item)
        }
        return (.ok, .object(["events": .array(Array(events))]))
    }

    nonisolated private static func addReminder(title: String, due: Date?) async -> (status: ToolRound.Status, result: JSONValue?) {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToReminders()) == true else { return (.error, .object(["reason": .string("no_permission")])) }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let due {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }
        do {
            try store.save(reminder, commit: true)
            return (.ok, .object(["reminder_id": .string(reminder.calendarItemIdentifier)]))
        } catch {
            return (.error, .object(["reason": .string("save_failed")]))
        }
    }

    // MARK: Contacts (A58)

    enum ContactMatch: Sendable {
        case found(String)
        case several([String])
        case none
        case noPermission
    }

    /// The name as said ("mamma", "Elin", "tandläkaren") against the contacts' names and nicknames. One match: its
    /// mobile number first. Several: their names, so Lumen can ask which one.
    nonisolated private static func lookUpContact(_ name: String) async -> ContactMatch {
        let store = CNContactStore()
        guard (try? await store.requestAccess(for: .contacts)) == true else { return .noPermission }
        let keys: [CNKeyDescriptor] = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey,
                                       CNContactOrganizationNameKey, CNContactPhoneNumbersKey].map { $0 as CNKeyDescriptor }
        var all: [PhoneCall.Contact] = []
        let request = CNContactFetchRequest(keysToFetch: keys)
        try? store.enumerateContacts(with: request) { contact, _ in
            let numbers = contact.phoneNumbers.map { (label: $0.label ?? "", number: $0.value.stringValue) }
            guard !numbers.isEmpty else { return }
            all.append(PhoneCall.Contact(given: contact.givenName, family: contact.familyName, nickname: contact.nickname,
                                         organization: contact.organizationName, numbers: numbers))
        }
        let matches = PhoneCall.matches(name, in: all)
        if matches.count == 1, let number = matches[0].bestNumber { return .found(number) }
        if matches.count > 1 { return .several(Array(matches.prefix(4).map(\.displayName))) }
        return .none
    }

    // MARK: AlarmKit

    nonisolated private static func alarmAllowed() async -> Bool {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        default: return (try? await manager.requestAuthorization()) == .authorized
        }
    }

    nonisolated private static func attributes(_ label: String?) -> AlarmAttributes<LumenAlarmMetadata> {
        let stop = AlarmButton(text: "Stopp", textColor: .white, systemImageName: "stop.fill")
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: label ?? "EarMind"), stopButton: stop)
        return AlarmAttributes(presentation: AlarmPresentation(alert: alert), tintColor: LumenColor.blue)
    }

    nonisolated private static func startTimer(seconds: Double, label: String?) async -> (status: ToolRound.Status, result: JSONValue?) {
        guard await alarmAllowed() else { return (.error, .object(["reason": .string("no_permission")])) }
        do {
            let configuration = AlarmManager.AlarmConfiguration<LumenAlarmMetadata>.timer(duration: seconds, attributes: attributes(label ?? "Timer"))
            _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
            return (.ok, .object(["ok": .bool(true)]))
        } catch {
            return (.error, .object(["reason": .string("schedule_failed")]))
        }
    }

    nonisolated private static func setAlarm(at date: Date, label: String?) async -> (status: ToolRound.Status, result: JSONValue?) {
        guard await alarmAllowed() else { return (.error, .object(["reason": .string("no_permission")])) }
        let id = UUID()
        do {
            let configuration = AlarmManager.AlarmConfiguration<LumenAlarmMetadata>.alarm(schedule: .fixed(date), attributes: attributes(label ?? "Larm"))
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            return (.ok, .object(["alarm_id": .string(id.uuidString)]))
        } catch {
            return (.error, .object(["reason": .string("schedule_failed")]))
        }
    }
}

/// AlarmKit wants a metadata type; Lumen's alarms carry nothing extra.
struct LumenAlarmMetadata: AlarmMetadata {}
