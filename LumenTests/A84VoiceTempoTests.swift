import Foundation
import Testing
@testable import Lumen

/// A84 (D151, D152, D155) and A89 (D162): voice, tempo, the month's limit and the long answers' length.
@MainActor
@Suite struct A84VoiceTempoTests {
    func model() throws -> (RepetitionModel, UserDefaults) {
        let defaults = UserDefaults(suiteName: "A84-\(UUID().uuidString)") ?? .standard
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a84-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let model = RepetitionModel(store: DrillStore(url: folder.appendingPathComponent("drills.json")),
                                    session: RepetitionSession(inputs: [], defaults: defaults, activatesAudioSession: false),
                                    maker: MockDrillMaker(), audio: DeviceVoiceDrillAudio(folder: folder, makesSound: false),
                                    sharing: DrillShareClient(cloud: nil), remote: RemoteCommandHub(), defaults: defaults)
        return (model, defaults)
    }

    @Test func theTempoIsOneOfTheOffered() throws {
        let (model, defaults) = try model()
        #expect(model.tempo == 1)
        model.tempo = 0.65
        #expect(model.tempo == 0.65)
        defaults.set(0.33, forKey: RepetitionModel.tempoKey)
        #expect(model.tempo == 1, "an unknown value falls back to normal")
        #expect(RepetitionModel.tempoLabel(1) == "Normal")
        #expect(RepetitionModel.tempoLabel(0.65) == "0,65×")
        #expect(RepetitionModel.tempos == [0.5, 0.65, 0.7, 0.75, 0.85, 0.9, 1.0, 1.5])
    }

    @Test func theVoiceGoesOnlyWithTheFirstSave() {
        var drill = Drill(title: "T", summary: DrillSummary(subject: "", grade: "", covers: ""),
                          items: [DrillItem(question: "F?", short: "K.", long: "K. L.")])
        drill.voiceModel = "B"
        let first = DrillCloudClient.saveBody(drill)["drill"] as? [String: Any]
        #expect(first?["voice_model"] as? String == "B")
        drill.serverID = "srv"
        let later = DrillCloudClient.saveBody(drill)["drill"] as? [String: Any]
        #expect((later?["voice_model"] as? String) == nil, "K50: locked after the first save")
    }

    @Test func theMonthsLimitLine() {
        let quota = DrillQuota(used: 12, limit: 15, per: "month", resets: "2026-12-01")
        #expect(quota.line == "3 av 15 frågor kvar den här månaden")
        #expect(DrillQuota(used: 20, limit: 15, per: nil, resets: nil).left == 0)
    }

    @Test func theLongAnswersLengthComesFromAvancerat() throws {
        let (model, _) = try model()
        #expect(model.newDrillSettings.length == .normal && model.newDrillSettings.length.words == 90)
        model.longAnswerLength = .longer
        #expect(model.newDrillSettings.length == .longer)
    }
}
