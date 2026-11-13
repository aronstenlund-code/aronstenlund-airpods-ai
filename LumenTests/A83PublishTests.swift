import Foundation
import Testing
@testable import Lumen

/// A83 (D149, D150, K49): Publicera prov and Prov från din skola, with K49 mocked.
@MainActor
@Suite struct A83PublishTests {
    @MainActor final class MockPublishing: DrillPublishingService {
        var published: [(id: String, school: String, subject: String, date: String, name: String?)] = []
        var unpublished: [String] = []
        var reports: [String] = []
        var plays: [String] = []
        var searched: [(school: String?, mySchool: String?)] = []
        var copy: DrillCloudView?

        func schools(matching query: String) async throws(DrillCloudError) -> [DrillSchool] {
            query.count < 2 ? [] : [DrillSchool(code: "123", name: "Kungsholmens gymnasium", locality: "Stockholm")]
        }

        func publish(drillID: String, school: DrillSchool, subject: String, examDate: Date,
                     displayName: String?) async throws(DrillCloudError) -> DrillPublicationView {
            published.append((drillID, school.code, subject, DrillPublishing.dayString(examDate), displayName))
            return DrillPublicationView(id: "pub-1", title: "Bio", subject: subject, school: school,
                                        exam_date: DrillPublishing.dayString(examDate), items: 2, display_name: displayName)
        }

        func unpublish(drillID: String) async throws(DrillCloudError) { unpublished.append(drillID) }

        func search(school: DrillSchool?, subject: String?, mySchool: DrillSchool?) async throws(DrillCloudError) -> [DrillPublicationView] {
            searched.append((school?.code, mySchool?.code))
            return []
        }

        func importPublication(id: String) async throws(DrillCloudError) -> DrillCloudView {
            guard let copy else { throw .refused(status: 404, code: "not_found", message: "Provet finns inte längre.") }
            return copy
        }

        func report(publicationID: String, reason: DrillReportReason) async throws(DrillCloudError) {
            reports.append("\(publicationID):\(reason.rawValue)")
        }

        func played(drillID: String) async { plays.append(drillID) }
    }

    func model() throws -> (RepetitionModel, MockPublishing, UserDefaults) {
        let defaults = UserDefaults(suiteName: "A83-\(UUID().uuidString)") ?? .standard
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a83-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let model = RepetitionModel(store: DrillStore(url: folder.appendingPathComponent("drills.json")),
                                    session: RepetitionSession(inputs: [], defaults: defaults, activatesAudioSession: false),
                                    maker: MockDrillMaker(), audio: DeviceVoiceDrillAudio(folder: folder, makesSound: false),
                                    sharing: DrillShareClient(cloud: nil), remote: RemoteCommandHub(), defaults: defaults)
        let publishing = MockPublishing()
        model.publishing = publishing
        return (model, publishing, defaults)
    }

    static let school = DrillSchool(code: "123", name: "Kungsholmens gymnasium", locality: "Stockholm")

    @Test func publishingKeepsThePublicationAndTheNameOnlyWhenChosen() async throws {
        let (model, publishing, _) = try model()
        var drill = Drill(title: "Bio", summary: DrillSummary(subject: "Biologi", grade: "åk 9", covers: ""),
                          items: [DrillItem(question: "F?", short: "K.", long: "K. L.")])
        drill.serverID = "srv-1"
        model.store.save(drill)
        let date = try #require(DrillPublishing.date("2026-11-20"))
        try await model.publish(drill, school: Self.school, subject: "Biologi", examDate: date, displayName: nil)
        #expect(publishing.published.first?.name == nil, "D150: no name unless chosen")
        #expect(publishing.published.first?.date == "2026-11-20")
        let saved = try #require(model.store.drill(drill.id)?.publication)
        #expect(saved.id == "pub-1" && saved.school == Self.school)
        #expect(DrillPublishing.line(saved).hasSuffix("· utan namn"))
        try await model.publish(drill, school: Self.school, subject: "Biologi", examDate: date, displayName: "plugghajen")
        #expect(model.lastDisplayName == "plugghajen", "the suggestion next time")
        try await model.unpublish(try #require(model.store.drill(drill.id)))
        #expect(publishing.unpublished == ["srv-1"])
        #expect(model.store.drill(drill.id)?.publication == nil)
    }

    @Test func mySchoolIsOnlyOnThePhoneAndSentAsMySchool() async throws {
        let (model, publishing, defaults) = try model()
        #expect(model.mySchool == nil && !model.mySchoolAsked)
        model.mySchool = Self.school
        #expect(model.mySchoolAsked)
        #expect(defaults.data(forKey: RepetitionModel.mySchoolKey) != nil)
        _ = try await model.searchPublications(school: nil, subject: nil)
        #expect(publishing.searched.first?.mySchool == "123")
    }

    @Test func aPlayOfAnAddedCopyIsCounted() async throws {
        let (model, publishing, _) = try model()
        let view = DrillCloudView(drill: .init(id: "copy-1", title: "Bio", subject: "Biologi", grade: "åk 9", covers: "",
                                               long_words: 90, shared_from: "pub-1"),
                                  items: [], audio: .init(done: 0, total: 0, failed: 0))
        publishing.copy = view
        let publication = DrillPublicationView(id: "pub-1", title: "Bio", subject: "Biologi", school: Self.school,
                                               exam_date: "2026-11-20", items: 0, display_name: nil)
        let drill = try await model.addPublication(publication)
        #expect(drill.fromPublication == "pub-1")
        #expect(model.added(publication)?.id == drill.id)
    }

    @Test func theWordsAndDates() throws {
        #expect(DrillPublishing.missing(school: nil, subject: "Biologi", date: nil) == "Saknas: skola, provdatum")
        #expect(DrillPublishing.missing(school: Self.school, subject: "Biologi", date: Date()) == nil)
        #expect(DrillPublishing.subject(from: "biologi") == "Biologi")
        #expect(DrillPublishing.subject(from: "Astrologi") == nil)
        let date = try #require(DrillPublishing.date("2026-11-20"))
        #expect(DrillPublishing.dayString(date) == "2026-11-20")
        #expect(DrillPublishing.shortDate(date, now: date) == "fre 20 nov")
        #expect(DrillReportReason.allCases.map(\.rawValue) == ["fel", "krankande", "upphovsratt", "annat"])
    }
}
