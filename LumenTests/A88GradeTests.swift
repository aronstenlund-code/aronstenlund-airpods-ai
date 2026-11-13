import Foundation
import Testing
@testable import Lumen

/// A88 (D161): "Vilken årskurs?" in Nytt prov is kept in the profile and chosen again; Hoppa över keeps it.
@MainActor
@Suite struct A88GradeTests {
    @Test func theChosenGradeIsKeptAndSkippingKeepsIt() throws {
        let defaults = UserDefaults(suiteName: "A88-\(UUID().uuidString)") ?? .standard
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a88-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let model = RepetitionModel(store: DrillStore(url: folder.appendingPathComponent("drills.json")),
                                    session: RepetitionSession(inputs: [], defaults: defaults, activatesAudioSession: false),
                                    maker: MockDrillMaker(), audio: DeviceVoiceDrillAudio(folder: folder, makesSound: false),
                                    sharing: DrillShareClient(cloud: nil), remote: RemoteCommandHub())
        let profile = StudyProfileStore(defaults: defaults)
        model.profile = profile
        #expect(model.preferredGrade == nil)
        model.preferredGrade = .y8
        #expect(profile.profile.grade == .y8)
        #expect(StudyProfileStore(defaults: defaults).profile.grade == .y8, "saved")
        model.preferredGrade = nil // Hoppa över
        #expect(model.preferredGrade == .y8)
        #expect(GradeChoice.choices.map(GradeChoice.label) == ["åk 7", "åk 8", "åk 9", "Gy 1", "Gy 2", "Gy 3", "Högskola"])
        #expect(StudyProfile.Grade.gy1.rawValue == "gy1", "K52 understands the profile's codes")
    }
}
