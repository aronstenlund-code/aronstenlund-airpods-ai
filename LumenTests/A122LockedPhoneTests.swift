import Foundation
import Testing
@testable import Lumen

/// A122 (D209): "Säg i AirPods" says that the phone can be locked and put away, and that has to be true. What the
/// Simulator can show: the repetition lives in the session (no view is needed for it to go round), the presses that
/// the Lock Screen and the AirPods send pause and go on, and the Lock Screen is given its words. That the sound
/// really goes on with the screen locked is for the phone. Mock sound, 0 ElevenLabs (D180).
@MainActor
@Suite struct A122LockedPhoneTests {
    typealias MockSource = A78RepetitionTests.MockSource
    typealias MockTimer = A78RepetitionTests.MockTimer
    typealias Clock = A115SayInAirPodsTests.Clock

    func session(_ source: MockSource, _ clock: Clock) -> RepetitionSession {
        let session = RepetitionSession(inputs: [], makeSource: { source }, makeTimer: { MockTimer() },
                                        defaults: UserDefaults(suiteName: "a122-\(UUID().uuidString)")!,
                                        activatesAudioSession: false)
        session.now = { clock.date }
        return session
    }

    @Test func theLineUnderTheFieldIsAronsWords() {
        #expect(SayText.lockLine == "Du kan låsa telefonen och lägga undan den. Det hörs i AirPods ändå.")
    }

    @Test func theLockScreenSaysSagIAirPods() {
        let once = RepetitionSession.sayingNowPlaying(title: "Fotosyntes: koldioxid + vatten …", lap: 1, repeats: false)
        #expect(once.title == "EarMind · Säg i AirPods" && once.artist == "Fotosyntes: koldioxid + vatten …")
        let round = RepetitionSession.sayingNowPlaying(title: "Fotosyntes", lap: 3, repeats: true)
        #expect(round.title == "EarMind · Säg i AirPods" && round.artist == "Fotosyntes · varv 3")
    }

    /// No view and no screen: the session alone takes the text round, and a press from the Lock Screen or the AirPods
    /// (1 press = play/pause) pauses it and goes on, with the lap and the time kept.
    @Test func itGoesRoundAndIsPausedByAPressWithoutAnyView() throws {
        let source = MockSource()
        let clock = Clock()
        let session = session(source, clock)
        session.startReading(A115SayInAirPodsTests.text, saying: .init(repeatMinutes: 5)) { _ in A115SayInAirPodsTests.audio }
        let reader = try #require(session.reader)
        #expect(session.isActive && session.readingLap == 1)

        session.press(.long) // the Lock Screen's pause, or 1 press on the AirPods
        #expect(reader.isPaused)
        clock.date += 30
        session.press(.long)
        #expect(!reader.isPaused && session.isActive)
        #expect(session.readingLap == 1 && session.repeatSecondsLeft == 270, "the time runs by the clock, not by the screen")

        source.last.finish()
        #expect(session.readingLap == 2, "the text starts over while time is left")
        #expect(session.isActive)
    }
}
