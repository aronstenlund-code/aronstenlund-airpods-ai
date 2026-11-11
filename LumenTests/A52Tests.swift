import Foundation
import Testing
@testable import Lumen

/// A52 (D125, Kelly Ke29): "Vad kan Lumen?". Every row says what you say and what has to be set up; what is not built
/// says "Kommer snart" with no button; the status of a permission comes from the phone.
@MainActor
@Suite struct A52Tests {
    @Test func everyGroupHasRowsAndEveryRowSaysSomething() {
        for group in LumenCapability.Group.allCases {
            #expect(LumenCapability.all.contains { $0.group == group }, "\(group.rawValue)")
        }
        #expect(Set(LumenCapability.all.map(\.id)).count == LumenCapability.all.count, "unique ids")
        for item in LumenCapability.all { #expect(!item.say.isEmpty && !item.title.isEmpty) }
    }

    @Test func spotifyIsComingSoonAndCallsNeedTheContacts() {
        let spotify = LumenCapability.all.first { $0.id == "spotify" }
        let call = LumenCapability.all.first { $0.id == "call" }
        #expect(spotify?.setup == .soon)
        #expect(call?.setup == .permission(.contacts), "A58: call_contact is built")
        let line = CapabilityAccess.line(for: .soon, access: nil)
        #expect(line.text == "Kommer snart" && !line.needsAction)
    }

    @Test func aPermissionSaysWhatIsNeededOrThatItIsAllowed() {
        let allowed = CapabilityAccess.line(for: .permission(.calendar), access: .allowed)
        #expect(allowed.text == "✓ Tillåtet" && !allowed.needsAction)
        let notAsked = CapabilityAccess.line(for: .permission(.calendar), access: .notAsked)
        #expect(notAsked.text == "Behöver tillgång till Kalender" && notAsked.needsAction)
        #expect(CapabilityAccess.line(for: .permission(.reminders), access: .denied).needsAction)
        let nothing = CapabilityAccess.line(for: .nothing, access: nil)
        #expect(nothing.text == "Inget att ställa in" && !nothing.needsAction)
        #expect(CapabilityAccess.of(.fullAccess) == .allowed)
        #expect(CapabilityAccess.of(.notDetermined) == .notAsked)
        #expect(CapabilityAccess.of(.writeOnly) == .denied, "Lumen reads the calendar")
    }

    @Test func theFirstSheetShowsThreeThatWorkWithoutConnecting() {
        let items = LumenCapability.firstExamples.compactMap { id in LumenCapability.all.first { $0.id == id } }
        #expect(items.count == 3)
        #expect(items.allSatisfy { $0.setup != .soon })
    }
}
