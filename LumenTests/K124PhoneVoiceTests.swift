import Foundation
import Testing
@testable import Lumen

/// K124 (Kevin, D267; D270): when ElevenLabs' quota is out the server answers 503 `tts_quota` (and for 10 minutes
/// without trying) and the exams come back with `audio_unavailable`. The phone's own voice reads then, and the screen
/// says so briefly. Nothing is charged. The server's answers are faked; 0 ElevenLabs (D180).
@MainActor
@Suite struct K124PhoneVoiceTests {
    private let premiumVoice = VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Astrid")
    private let quotaOut = TTSError.network(.backend(status: 503, failure: AnswerFailure(code: "tts_quota", message: nil, fallback: true)))

    // MARK: Listening: the phone's voice for 10 minutes, without asking for every sentence

    @Test func theQuotaOutReadsWithThePhoneForTenMinutes() async {
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.error = quotaOut
        let speaker = makeTestSpeaker(FakePlaybackService(), apple: apple, premium: premium)
        speaker.settings.voice = premiumVoice
        final class Clock { var now = Date(timeIntervalSince1970: 2_000_000) }
        let clock = Clock()
        speaker.now = { clock.now }

        speaker.enqueue("Roten ur hundra är tio.", language: .swedish)
        speaker.enqueue("Det är enkelt.", language: .swedish)
        #expect(await waitUntil { speaker.spokenCount == 2 })
        #expect(premium.calls.count == 1, "asked once; the second sentence goes straight to the phone")
        #expect(apple.calls.map(\.text) == ["Roten ur hundra är tio.", "Det är enkelt."])
        #expect(speaker.isPremiumPaused)
        #expect(speaker.fallbackCount == 1)

        clock.now = clock.now.addingTimeInterval(Speaker.quotaPause + 1)
        premium.error = nil
        speaker.enqueue("Och nu igen.", language: .swedish)
        #expect(await waitUntil { speaker.spokenCount == 3 })
        #expect(premium.calls.count == 2, "after 10 minutes the chosen voice is asked again")
        #expect(!speaker.isPremiumPaused)
    }

    @Test func otherVoiceErrorsDoNotPauseTheChosenVoice() async {
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.error = .network(.offline)
        let speaker = makeTestSpeaker(FakePlaybackService(), apple: apple, premium: premium)
        speaker.settings.voice = premiumVoice
        speaker.enqueue("Ett.", language: .swedish)
        speaker.enqueue("Två.", language: .swedish)
        #expect(await waitUntil { speaker.spokenCount == 2 })
        #expect(premium.calls.count == 2, "a dropped connection is tried again at the next sentence")
        #expect(!speaker.isPremiumPaused)
        #expect(Speaker.isQuotaOut(quotaOut) && !Speaker.isQuotaOut(.network(.offline)))
    }

    // MARK: Exams: the phone reads instead of only showing the text

    typealias MockCloud = A79A81RepetitionTests.MockCloud

    private func rig(phone: Bool) throws -> (CloudDrillAudio, DrillStore, Drill, MockCloud, DeviceVoiceDrillAudio) {
        let folder = try A79A81RepetitionTests.folder("k124")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = MockCloud()
        cloud.views["srv"] = A112ReadingAloudOffTests.view(started: false)
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 3)
        let voice = DeviceVoiceDrillAudio(folder: folder.appendingPathComponent("phone"), language: "sv-SE", makesSound: false)
        if phone { audio.phoneVoice = { _ in voice } }
        var drill = A79A81RepetitionTests.bio(2)
        drill.serverID = "srv"
        drill.audioStarted = false
        store.save(drill)
        // The phone's files, as its voice would write them (the test does not synthesise speech).
        for item in drill.items {
            for text in [item.question, item.short, item.long] {
                try WAVWriter.write(samples: [Int16](repeating: 0, count: 1_600), sampleRate: 16_000, to: voice.url(text: text))
            }
        }
        return (audio, store, drill, cloud, voice)
    }

    @Test func withTheVoiceServiceOutThePhoneReadsTheExam() async throws {
        let (audio, store, drill, cloud, voice) = try rig(phone: true)
        let started = await audio.startAudio(drill)
        #expect(started, "Starta prov goes on: the phone reads")
        let after = try #require(store.drill(drill.id))
        #expect(audio.isReadingAloudOff(after), "the server still says the voice service is out")
        #expect(audio.problem(for: after) == CloudDrillAudio.phoneLine, "said briefly on the exam's screen")
        let track = try #require(audio.track(for: after, at: 0))
        #expect(track.question == voice.url(text: drill.items[0].question))
        #expect(track.long == voice.url(text: drill.items[0].long))
        #expect(audio.tracks(for: after)?.count == 2)
        #expect(!audio.quotaExceeded.contains(drill.id), "nothing is counted")

        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() },
                                        makeTimer: { A78RepetitionTests.MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "k124-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        #expect(!model.isReadingAloudOff(after), "the player plays, not the text-only screen")
        #expect(model.canStart(after))
    }

    @Test func withoutThePhoneVoiceTheExamStaysTextAsBefore() async throws {
        let (audio, store, drill, _, _) = try rig(phone: false)
        let started = await audio.startAudio(drill)
        #expect(!started)
        let after = try #require(store.drill(drill.id))
        #expect(audio.problem(for: after) == CloudDrillAudio.unavailableLine)
        #expect(audio.track(for: after, at: 0) == nil)
    }

    @Test func whenTheVoiceServiceIsBackThePhoneStops() async throws {
        let (audio, store, drill, cloud, _) = try rig(phone: true)
        _ = await audio.startAudio(drill)
        #expect(audio.problem(for: try #require(store.drill(drill.id))) == CloudDrillAudio.phoneLine)
        var back = A112ReadingAloudOffTests.view(started: false)
        back.audio_unavailable = nil
        cloud.views["srv"] = back
        await audio.prepare(try #require(store.drill(drill.id)))
        let after = try #require(store.drill(drill.id))
        #expect(audio.phone(for: after) == nil)
        #expect(audio.problem(for: after) == nil)
    }

    @Test func tts_quotaIsTheVoiceServiceBeingOut() {
        #expect(CloudDrillAudio.isUnavailable("tts_quota"))
        #expect(!CloudDrillAudio.isUnavailable("provider_quota"), "the model's quota is not the voice's (O97)")
    }

    @Test func thePhoneSpeaksTheExamsLanguage() {
        #expect(CloudDrillAudio.spokenLanguage(A79A81RepetitionTests.bio(2)) == "sv-SE")
        let english = Drill(title: "Bio", summary: A79A81RepetitionTests.summary,
                            items: [DrillItem(question: "Why do plants need light?", short: "To make sugar.",
                                              long: "To make sugar. Light gives the energy for photosynthesis in the leaves.")])
        #expect(CloudDrillAudio.spokenLanguage(english) == "en-US")
    }
}
