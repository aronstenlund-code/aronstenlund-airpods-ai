import Foundation
import Testing
@testable import Lumen

/// T61 (Toby, Deangelo 2026-11-27 05:19): A168, coming back to the repetition, from the app's own wiring
/// (`AppContainer`) in the repetition's mock mode (`RepetitionMock`, Debug only: a pretend maker and the phone's own
/// voice for the sound, so no server and no credits). Every request is stopped and written down by `OwnDeckGate`
/// (T58) while it happens: there must be none. Two quizzes are made; the older one is played, one answer is asked for
/// with a press, at least three questions are heard, and Avsluta. Then: the summary (heard, the question whose answer
/// was asked for), the quiz played last first on Start, its place kept ("Fortsätt"), and "Öva de N igen" playing only
/// those questions without moving the quiz's own place. Simulator only: never a device test.
@MainActor
@Suite(.serialized, .enabled(if: TroubleEnvironment.silence != nil, "run from scripts/apptest/t60.sh"))
struct ComebackE2ETests {
    @Test func afterAvslutaTheSummaryTheLastQuizFirstAndTheMissedAgain() async throws {
        guard !TroubleEnvironment.micDenied else { return }
        URLProtocol.registerClass(OwnDeckGate.self)
        OwnDeckGate.setShut(false)
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "RepetitionMock")
        defaults.set(false, forKey: STTSettings.cloudKey)
        defer { defaults.removeObject(forKey: "RepetitionMock") }
        let container = AppContainer()
        let repetition = try #require(container.listening.repetition)
        for drill in repetition.drills { repetition.delete(drill) }
        OwnDeckGate.setShut(true)
        let baseline = OwnDeckGate.snapshot().count
        var notes: [String] = []
        var wrong: [String] = []

        var settings = DrillSettings()
        settings.questions = 4
        let material = DrillMaterial(text: "Fotosyntesen gör socker och syre av koldioxid, vatten och ljus. Den sker i kloroplasterna.")
        let draftA = try await repetition.make(material, settings: settings)
        let quizA = repetition.save(Drill(title: "T61 A", summary: draftA.summary, items: draftA.items))
        try await Task.sleep(for: .milliseconds(50))
        let draftB = try await repetition.make(material, settings: settings)
        let quizB = repetition.save(Drill(title: "T61 B", summary: draftB.summary, items: draftB.items))
        notes.append("made A (\(quizA.items.count) questions) and B; Start before: \(repetition.examDrills.map(\.title))")
        if repetition.examDrills.first?.id != quizB.id { wrong.append("the newest quiz is not first before anything is played") }

        // Play A: one press for the answer of question 2, at least three questions heard, then Avsluta.
        await repetition.start(quizA)
        var pressed = false
        var phases: [String] = []
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            guard let player = repetition.session.player else { break }
            let phase = "\(player.phase)"
            if phases.last != phase { phases.append(phase) }
            if !pressed, case .thinking(1) = player.phase { player.handle(.long); pressed = true }
            if player.heardQuestions.count >= 3, pressed, case .question = player.phase { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        notes.append("phases: \(phases.prefix(14).joined(separator: " → "))")
        repetition.end()
        let summary = repetition.practiceSummary
        notes.append("summary: \(summary.map { "\($0.title), heard \($0.heard), laps \($0.laps), missed \($0.missed), places \($0.places)" } ?? "none")")
        if let summary {
            if summary.heard < 3 { wrong.append("heard \(summary.heard)") }
            if summary.missed != [quizA.items[1].question] { wrong.append("missed \(summary.missed), not question 2") }
        } else {
            wrong.append("no summary after Avsluta")
        }
        let place = repetition.savedIndex(quizA)
        notes.append("Start after: \(repetition.examDrills.map(\.title)); A's place (Fortsätt) \(place.map(String.init) ?? "none")")
        if repetition.examDrills.first?.id != quizA.id { wrong.append("the quiz played last is not first on Start") }
        if place == nil { wrong.append("no Fortsätt place for A") }

        // "Öva de 1 igen": only that question, in the same player; A's own place stays.
        if let summary {
            repetition.practiceSummary = nil
            await repetition.practiseMissed(summary)
            let count = repetition.session.player?.count
            let heard = await waitFor(40) { (repetition.session.player?.heardQuestions.count ?? 0) >= 1 }
            notes.append("practise the missed: \(count.map(String.init) ?? "-") question(s), heard \(heard), shows the player \(repetition.showsPlayer)")
            if count != summary.places.count { wrong.append("the missed run has \(count.map(String.init) ?? "no") questions, not \(summary.places.count)") }
            repetition.end()
            if repetition.savedIndex(quizA) != place { wrong.append("A's place moved after the missed run (\(String(describing: place)) → \(String(describing: repetition.savedIndex(quizA))))") }
        }
        let requests = Array(OwnDeckGate.snapshot().dropFirst(baseline))
        OwnDeckGate.setShut(false)
        notes.append("requests: \(requests.count) \(requests.prefix(5))")
        if !requests.isEmpty { wrong.append("\(requests.count) requests in the mock mode") }
        for drill in [quizA, quizB] { repetition.delete(drill) }
        _ = container
        let verdict = wrong.isEmpty ? "ok" : wrong.joined(separator: "; ")
        print("T61 comeback: \(verdict); \(notes.joined(separator: " | "))")
        struct Line: Codable { var id: String; var verdict: String; var notes: [String] }
        let line = try JSONEncoder().encode(Line(id: "comeback-a168", verdict: verdict, notes: notes))
        if let handle = try? FileHandle(forWritingTo: TroubleEnvironment.out.appending(path: "trouble.jsonl")) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line + Data([0x0A]))
        }
        #expect(verdict == "ok", "\(verdict)")
    }

    private func waitFor(_ seconds: Double, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return condition()
    }
}
