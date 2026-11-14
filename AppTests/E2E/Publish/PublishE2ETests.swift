import AVFAudio
import Foundation
import Testing
@testable import Lumen

/// T19 (Toby 1): Publicera prov (A83, K49, D149/D150) through the app's own clients against the live `/drill`, with two
/// accounts the way two pupils would: A saves a small exam (3 questions, voice C = Flash, the cheapest) and waits for
/// its sound, finds a school and publishes it; B finds it by the school, adds it, downloads and plays its files and
/// reports it; A unpublishes and B no longer finds it. Each step is timed and written to `publish.json`.
///
/// Live and paid (ElevenLabs Flash for about 1 000 characters, once): only when `scripts/apptest/publish.sh` sets
/// `LUMEN_E2E_PUBLISH`. Both accounts are anonymous and new, and everything is deleted at the end. Simulator only.
enum PublishEnvironment {
    static var enabled: Bool { ProcessInfo.processInfo.environment["LUMEN_E2E_PUBLISH"] != nil }
    static var out: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
    }
}

@MainActor
@Suite(.serialized, .enabled(if: PublishEnvironment.enabled, "set LUMEN_E2E_PUBLISH (scripts/apptest/publish.sh)"))
struct PublishE2ETests {
    struct Step: Codable {
        var step: String
        var seconds: Double
        var ok: Bool
        var detail: String
    }

    final class Steps {
        var list: [Step] = []
        let started = Date()
        var last = Date()

        func add(_ step: String, ok: Bool = true, _ detail: String = "") {
            let now = Date()
            list.append(Step(step: step, seconds: (now.timeIntervalSince(last) * 10).rounded() / 10, ok: ok, detail: detail))
            print("T19 \(step): \(ok ? "ok" : "FAILED") \(detail)")
            last = now
        }

        func write() throws {
            let out = PublishEnvironment.out
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(list).write(to: out.appendingPathComponent("publish.json"))
        }
    }

    static func client() -> DrillCloudClient {
        let http = URLSessionHTTP()
        let auth = SupabaseAuth(config: .lumen, store: InMemorySessionStore(), http: http)
        return DrillCloudClient(config: .lumen, auth: auth, http: http)
    }

    static func exam() -> Drill {
        let items = [
            DrillItem(question: "Vad behövs för fotosyntes?", short: "Ljus, vatten och koldioxid.",
                      long: "Ljus, vatten och koldioxid. Klorofyllet fångar ljuset, och växten gör socker och syre."),
            DrillItem(question: "Var sker cellandningen?", short: "I mitokondrierna.",
                      long: "I mitokondrierna. Där bryts druvsocker ner med syre till energi, koldioxid och vatten."),
            DrillItem(question: "Varför finns färre rovdjur?", short: "Energin minskar i varje led.",
                      long: "Energin minskar i varje led. Bara en tiondel går vidare, resten blir rörelse och värme."),
        ]
        var drill = Drill(title: "T19 test \(UUID().uuidString.prefix(6))",
                          summary: DrillSummary(subject: "Biologi", grade: "åk 8", covers: "Fotosyntes och energi"), items: items)
        drill.voiceModel = "C"
        drill.longWords = 40
        return drill
    }

    @Test func publishFindAddPlayReportAndUnpublish() async throws {
        let steps = Steps()
        defer { try? steps.write() }
        let a = Self.client()
        let b = Self.client()

        // 1. A saves the exam and waits for every file (Publicera is off until the sound is done, D143).
        let saved = try await a.save(Self.exam())
        let drillID = saved.drill.id
        steps.add("A sparar provet", "\(saved.items.count) frågor, ljud \(saved.audio.done)/\(saved.audio.total)")
        var view = saved
        let deadline = Date().addingTimeInterval(300)
        while view.audio.done < view.audio.total, (view.audio.failed ?? 0) == 0, Date() < deadline {
            try await Task.sleep(for: .seconds(3))
            view = try await a.status(id: drillID)
        }
        let soundReady = view.audio.total > 0 && view.audio.done == view.audio.total
        steps.add("A väntar på ljudet", ok: soundReady, "\(view.audio.done)/\(view.audio.total), failed \(view.audio.failed ?? 0)")
        try #require(soundReady, "the sound was not done in 300 s")

        // 2. A finds a school and publishes (D150: without the name).
        let schools = try await a.schools(matching: "Katedralskolan")
        let school = try #require(schools.first, "no school for 'Katedralskolan'")
        steps.add("A söker skola", "\(schools.count) träffar, \(school.name) (\(school.code))")
        let examDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let publication = try await a.publish(drillID: drillID, school: school, subject: "Biologi", examDate: examDate, displayName: nil)
        steps.add("A publicerar", "\(publication.id), \(publication.items) frågor, namn \(publication.display_name ?? "inget")")
        #expect(publication.display_name == nil, "the name was shown without the choice (D150)")
        #expect(publication.items == 3)

        // 3. B finds it by the school and the subject.
        let found = try await b.search(school: school, subject: "Biologi", mySchool: nil)
        let hit = found.first { $0.id == publication.id }
        steps.add("B hittar provet via skolan", ok: hit != nil, "\(found.count) prov på skolan, vårt \(hit == nil ? "saknas" : "finns")")
        try #require(hit != nil)

        // 4. B adds it and plays its files (shared audio: no new ElevenLabs call, R5c).
        let copy = try await b.importPublication(id: publication.id)
        steps.add("B lägger till provet", ok: copy.items.count == 3 && copy.audio.done == copy.audio.total,
                  "\(copy.items.count) frågor, ljud \(copy.audio.done)/\(copy.audio.total)")
        #expect(copy.items.map(\.question) == view.items.map(\.question))
        var played = 0
        var seconds = 0.0
        for item in copy.items {
            for file in [item.audio.question, item.audio.long] {
                guard file.isDone, let link = file.url, let url = URL(string: link) else { continue }
                let data = try await b.download(url)
                let player = try AVAudioPlayer(data: data)
                if player.prepareToPlay(), player.duration > 0.3, player.play() {
                    played += 1
                    seconds += player.duration
                }
                player.stop()
            }
        }
        steps.add("B spelar ljudet", ok: played == 6, "\(played) av 6 filer spelade, \(Int(seconds)) s ljud")
        #expect(played == 6)
        await b.played(drillID: copy.drill.id)

        // 5. The original is unchanged.
        let original = try await a.status(id: drillID)
        #expect(original.items.map(\.question) == view.items.map(\.question))
        steps.add("A:s original oförändrat", ok: original.items.count == 3, "\(original.items.count) frågor")

        // 6. B reports it.
        do {
            try await b.report(publicationID: publication.id, reason: .fel)
            steps.add("B rapporterar")
        } catch {
            steps.add("B rapporterar", ok: false, "\(error)")
            Issue.record("report failed: \(error)")
        }

        // 7. A unpublishes; B no longer finds it.
        try await a.unpublish(drillID: drillID)
        let after = try await b.search(school: school, subject: "Biologi", mySchool: nil)
        let gone = !after.contains { $0.id == publication.id }
        steps.add("A tar bort publiceringen", ok: gone, gone ? "B hittar det inte längre" : "syns fortfarande")
        #expect(gone)

        // 8. Clean up both accounts.
        try? await b.delete(id: copy.drill.id)
        try? await a.delete(id: drillID)
        steps.add("städat")
    }
}
