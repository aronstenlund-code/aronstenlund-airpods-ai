import Foundation
import Testing
@testable import Lumen

/// A105 (D185): the reading mode with A78's silent mock files and hand-fired timer. No sound, 0 ElevenLabs characters
/// (D180).
@MainActor
@Suite struct A105ReadingTests {
    typealias MockSource = A78RepetitionTests.MockSource
    typealias MockTimer = A78RepetitionTests.MockTimer

    /// A heading of one sentence, then a paragraph of three sentences of 2 s each.
    static let parts: [ReadingParagraph] = [
        ReadingParagraph(sentences: ["Fotosyntes"], isHeading: true),
        ReadingParagraph(sentences: ["Växter gör socker.", "De behöver ljus.", "Syre blir över."]),
    ]

    static func audio(_ part: Int) -> ReadingAudio {
        part == 0
            ? ReadingAudio(url: URL(fileURLWithPath: "/tmp/p0.mp3"), times: [0...1])
            : ReadingAudio(url: URL(fileURLWithPath: "/tmp/p1.mp3"), times: [0...2, 2...4, 4...6])
    }

    func make(startAt: Int = 0) -> (ReadingPlayer, MockSource, MockTimer) {
        let source = MockSource()
        let timer = MockTimer()
        let player = ReadingPlayer(parts: Self.parts, audio: { Self.audio($0) }, source: source, timer: timer,
                                   startAt: startAt)
        return (player, source, timer)
    }

    // MARK: Flow

    @Test func readsThePartsInOrderAndStopsAtTheEnd() {
        let (player, source, _) = make()
        player.start()
        #expect(player.phase == .reading)
        #expect(source.last.url.lastPathComponent == "p0.mp3")
        source.last.finish()
        #expect(source.last.url.lastPathComponent == "p1.mp3")
        #expect(player.sentenceIndex == 1)
        source.last.finish()
        #expect(player.isAtEnd)
        #expect(player.isRunning) // only Avsluta ends it
    }

    @Test func followsTheSoundSentenceBySentence() {
        let (player, source, _) = make(startAt: 1)
        var saved: [Int] = []
        player.onProgress = { saved.append($0) }
        player.start()
        source.last.advance(2.5)
        player.followSound()
        #expect(player.sentenceIndex == 2)
        #expect(player.currentSentence == "De behöver ljus.")
        source.last.advance(2)
        player.followSound()
        #expect(player.sentenceIndex == 3)
        #expect(saved.suffix(2) == [2, 3])
    }

    @Test func theHeadingIsTheOneTheReaderIsUnder() {
        let (player, _, _) = make(startAt: 2)
        #expect(player.currentHeading == "Fotosyntes")
        let plain = ReadingPlayer(parts: [ReadingParagraph(sentences: ["En mening."])], audio: { _ in nil },
                                  source: MockSource(), timer: MockTimer())
        #expect(plain.currentHeading == nil)
    }

    // MARK: Presses (D185)

    @Test func onePressPausesAndGoesOnFromTheStartOfTheSentence() {
        let (player, source, _) = make(startAt: 1)
        player.start()
        source.last.advance(3.2) // in "De behöver ljus." (2–4 s)
        player.followSound()
        player.handle(.long)
        #expect(player.isPaused)
        #expect(source.last.isPlaying == false)
        player.handle(.long)
        #expect(!player.isPaused)
        #expect(source.last.currentTime == 2) // D164
        #expect(source.last.isPlaying)
    }

    @Test func twoPressesNextSentenceThreePressesPrevious() {
        let (player, source, _) = make(startAt: 1)
        player.start()
        let file = source.last
        player.handle(.short)
        #expect(player.sentenceIndex == 2)
        #expect(file.currentTime == 2) // the same file, moved
        #expect(source.made.count == 1)
        player.handle(.pauseToggle)
        player.handle(.pauseToggle)
        #expect(player.sentenceIndex == 0) // back into the heading's file
        #expect(source.last.url.lastPathComponent == "p0.mp3")
        player.handle(.pauseToggle)
        #expect(player.sentenceIndex == 0) // never before the first
        #expect(source.last.isPlaying)
    }

    @Test func nextFromAPartsLastSentenceIsTheNextPartsFirst() {
        let (player, source, _) = make()
        player.start()
        player.handle(.short)
        #expect(player.sentenceIndex == 1)
        #expect(source.last.url.lastPathComponent == "p1.mp3")
        #expect(source.last.currentTime == 0)
    }

    @Test func theEndSaysStartOverAndThreePressesGoBack() {
        let (player, source, _) = make(startAt: 3)
        var saved: [Int] = []
        player.onProgress = { saved.append($0) }
        player.start()
        player.handle(.short)
        #expect(player.isAtEnd)
        #expect(saved.last == 0) // the next start is from the beginning
        player.handle(.short)
        #expect(player.isAtEnd) // 2 presses at the end: nothing
        player.handle(.pauseToggle)
        #expect(player.sentenceIndex == 3)
        #expect(player.phase == .reading)
        player.handle(.short)
        player.handle(.long) // Börja om
        #expect(player.sentenceIndex == 0)
        #expect(player.phase == .reading)
        #expect(source.last.url.lastPathComponent == "p0.mp3")
    }

    @Test func movingWhilePausedStaysPausedAndReadsFromThere() {
        let (player, source, _) = make(startAt: 1)
        player.start()
        player.handle(.long)
        player.handle(.short)
        player.handle(.short)
        #expect(player.isPaused)
        #expect(player.sentenceIndex == 3)
        let before = source.made.count
        player.handle(.long)
        #expect(!player.isPaused)
        #expect(source.made.count == before + 1)
        #expect(source.last.currentTime == 4)
        #expect(source.last.isPlaying)
    }

    @Test func aTapOnASentenceReadsFromThereAlsoWhenPaused() {
        let (player, source, _) = make()
        player.start()
        player.handle(.long)
        player.jump(to: 2)
        #expect(!player.isPaused)
        #expect(player.sentenceIndex == 2)
        #expect(source.last.url.lastPathComponent == "p1.mp3")
        #expect(source.last.currentTime == 2)
        #expect(source.last.isPlaying)
    }

    // MARK: iOS and the sound

    @Test func iOSsPauseGoesOnFromTheWord() {
        let (player, source, _) = make(startAt: 1)
        player.start()
        source.last.advance(3.2)
        player.systemPaused("call")
        #expect(player.pausedBySystem)
        player.handle(.short) // a press while iOS paused is the user's: it moves and stays paused
        player.systemResumed("call ended")
        #expect(player.sentenceIndex == 2)
        #expect(source.last.isPlaying)

        let (other, otherSource, _) = make(startAt: 1)
        other.start()
        otherSource.last.advance(3.2)
        other.systemPaused("call")
        other.systemResumed("call ended")
        #expect(otherSource.last.currentTime == 3.2)
        #expect(otherSource.last.isPlaying)
    }

    @Test func aPartWithoutSoundIsWaitedFor() {
        @MainActor final class Flag { var on = false }
        let ready = Flag()
        let source = MockSource()
        let timer = MockTimer()
        let player = ReadingPlayer(parts: Self.parts, audio: { ready.on || $0 == 0 ? Self.audio($0) : nil },
                                   source: source, timer: timer, startAt: 1)
        player.start()
        #expect(player.phase == .waitingForAudio)
        #expect(timer.pending?.seconds == ReadingPlayer.audioRetrySeconds)
        timer.fire()
        #expect(player.phase == .waitingForAudio)
        ready.on = true
        timer.fire()
        #expect(player.phase == .reading)
        #expect(source.last.url.lastPathComponent == "p1.mp3")
    }

    @Test func aFileThatWillNotOpenIsSkipped() {
        let (player, source, timer) = make()
        source.missing = ["p0.mp3"]
        player.start()
        timer.fire()
        #expect(source.last.url.lastPathComponent == "p1.mp3")
        #expect(player.sentenceIndex == 1)
    }

    @Test func fewerTimesThanSentencesNeverSkipsAhead() {
        let audio = ReadingAudio(url: URL(fileURLWithPath: "/tmp/x.mp3"), times: [0...2])
        #expect(audio.start(of: 0) == 0)
        #expect(audio.start(of: 2) == 0)
        #expect(ReadingAudio(url: audio.url, times: []).start(of: 1) == 0)
    }

    @Test func withoutTimesThePlaceStaysWhereThePressesPutIt() {
        let source = MockSource()
        let player = ReadingPlayer(parts: Self.parts,
                                   audio: { ReadingAudio(url: URL(fileURLWithPath: "/tmp/p\($0).mp3"), times: []) },
                                   source: source, timer: MockTimer(), startAt: 1)
        player.start()
        source.last.advance(5)
        player.followSound()
        #expect(player.sentenceIndex == 1, "never the part's last sentence because every start reads 0")
        player.handle(.short)
        #expect(player.sentenceIndex == 2)
        player.followSound()
        #expect(player.sentenceIndex == 2)
    }

    @Test func startAtIsKeptInsideTheText() {
        #expect(make(startAt: 99).0.sentenceIndex == 3)
        #expect(make(startAt: -2).0.sentenceIndex == 0)
    }

    // MARK: The saved place

    @Test func thePlaceIsSavedPerText() throws {
        let defaults = try #require(UserDefaults(suiteName: "A105-\(UUID())"))
        let a = UUID(), b = UUID()
        ReadingProgress.save(a, sentence: 5, defaults)
        ReadingProgress.save(b, sentence: 2, defaults)
        #expect(ReadingProgress.load(a, defaults)?.sentence == 5)
        #expect(ReadingProgress.load(b, defaults)?.sentence == 2)
        ReadingProgress.clear(a, defaults)
        #expect(ReadingProgress.load(a, defaults) == nil)
        #expect(ReadingProgress.load(b, defaults)?.sentence == 2)
    }
}

/// A105 (K70 contract in backend/README "Läsläget"): a text from the server, saved, downloaded and read without network.
@MainActor
@Suite struct A105TextDrillTests {
    typealias MockCloud = A79A81RepetitionTests.MockCloud

    /// `get`/`status` for a text, as K70 answers (README point 4).
    static let textView = #"""
    {"drill":{"id":"text-1","title":"Fotosyntes","subject":"Biologi","grade":"åk 8","kind":"text"},
     "items":[
      {"id":"p0","position":0,"part":"heading","text":"Fotosyntes","sentences":["Fotosyntes"],"voice_chars":10,
       "audio":{"text":{"status":"done","url":"https://x.supabase.co/storage/v1/object/sign/drill_audio/ab/h0.mp3?token=t",
                        "duration_ms":900,"sentences":[[0,900]]}}},
      {"id":"p1","position":1,"part":"para","text":"Växter gör socker. De behöver ljus.",
       "sentences":["Växter gör socker.","De behöver ljus."],"voice_chars":35,
       "audio":{"text":{"status":"done","url":"https://x.supabase.co/storage/v1/object/sign/drill_audio/ab/h1.mp3?token=t",
                        "duration_ms":4000,"sentences":[[0,1800],[1900,4000]]}}}],
     "audio":{"done":2,"total":2,"failed":0}}
    """#

    static func view() throws -> DrillCloudView {
        try JSONDecoder().decode(DrillCloudView.self, from: Data(textView.utf8))
    }

    @Test func aTextFromTheServerIsReadAsParts() throws {
        let view = try Self.view()
        #expect(view.drill.kind == "text")
        #expect(view.items[1].isTextPart && view.items[1].long == "Växter gör socker. De behöver ljus.")
        #expect(view.items[1].audio.question.status == "missing" && view.items[1].audio.text?.isDone == true)
        let drill = Drill.from(view)
        #expect(drill.isText)
        #expect(drill.items.map(\.part) == [.heading, .para])
        #expect(drill.sentenceCount == 3)
        #expect(drill.readingParts[0].isHeading && drill.readingParts[1].sentences == ["Växter gör socker.", "De behöver ljus."])
        #expect(drill.audioFileCount == 2, "K70: one file per part")
    }

    @Test func aQuestionsExamStillDecodesAsBefore() throws {
        let json = #"""
        {"id":"i1","position":0,"question":"När?","short":"Runt 1850.","long":"Runt 1850. Mer.",
         "audio":{"question":{"status":"done"},"long":{"status":"pending"}}}
        """#
        let item = try JSONDecoder().decode(DrillCloudView.Item.self, from: Data(json.utf8))
        #expect(!item.isTextPart && item.question == "När?" && item.audio.text == nil)
        #expect(item.audio.files.map(\.status) == ["done", "pending"])
        let whole = "{\"drill\":{\"id\":\"d\"},\"items\":[" + json + "],\"audio\":{\"done\":1,\"total\":2}}"
        let exam = Drill.from(try JSONDecoder().decode(DrillCloudView.self, from: Data(whole.utf8)))
        #expect(!exam.isText && exam.kind == nil)
    }

    @Test func aTextIsSavedAsItsParts() throws {
        var drill = Drill.text(title: "Fotosyntes", summary: A79A81RepetitionTests.summary,
                               parts: [.textPart("Fotosyntes", part: .heading), .textPart("Växter gör socker.", part: .para)])
        drill.items[1].serverID = "p1"
        let body = DrillCloudClient.saveBody(drill)
        let info = try #require(body["drill"] as? [String: Any])
        #expect(info["kind"] as? String == "text")
        let items = try #require(body["items"] as? [[String: Any]])
        #expect(items.map { $0["kind"] as? String } == ["heading", "para"])
        #expect(items.map { $0["text"] as? String } == ["Fotosyntes", "Växter gör socker."])
        #expect(items[0]["id"] == nil && items[1]["id"] as? String == "p1")
        #expect(items[0]["question"] == nil, "K70: a text part has no question")
    }

    @Test func theDownloadedTextPlaysWithoutANetwork() async throws {
        let folder = try A79A81RepetitionTests.folder("a105")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = MockCloud()
        cloud.views["text-1"] = try Self.view()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1))
        var drill = Drill.from(try Self.view())
        drill.needsUpload = nil
        store.save(drill)
        #expect(audio.reading(for: drill, part: 1) == nil, "nothing downloaded yet")

        await audio.prepare(drill)

        let saved = try #require(store.drill(drill.id))
        #expect(audio.hasAllSound(saved))
        #expect(saved.items.map(\.longAudio) == ["h0.mp3", "h1.mp3"])
        let part = try #require(audio.reading(for: saved, part: 1))
        #expect(part.url.lastPathComponent == "h1.mp3")
        #expect(part.times == [0...1.8, 1.9...4.0])

        // A103: the network gone, the text is still there (the server is never asked to play).
        cloud.offline = true
        let again = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1))
        #expect(again.reading(for: saved, part: 1)?.times.count == 2)
        #expect(CloudDrillAudio.usedFiles([saved]) == ["h0.mp3", "h1.mp3"], "A103: removeUnused keeps a text's files")
    }

    @Test func theModelReadsATextFromTheSavedSentence() async throws {
        let folder = try A79A81RepetitionTests.folder("a105m")
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let defaults = try #require(UserDefaults(suiteName: "A105m-\(UUID())"))
        let cloud = MockCloud()
        cloud.views["text-1"] = try Self.view()
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1))
        let session = RepetitionSession(inputs: [], makeSource: { A78RepetitionTests.MockSource() },
                                        makeTimer: { A78RepetitionTests.MockTimer() }, defaults: defaults,
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(),
                                    cloud: cloud, defaults: defaults)
        var drill = Drill.from(try Self.view())
        drill.needsUpload = nil
        store.save(drill)
        await audio.prepare(drill)
        let saved = try #require(store.drill(drill.id))
        #expect(model.canStart(saved))
        #expect(RepetitionModel.part(of: 2, in: saved) == 1)

        await model.start(saved, at: 2)
        let reader = try #require(session.reader)
        #expect(session.isActive && session.player == nil)
        #expect(reader.sentenceIndex == 2 && reader.currentSentence == "De behöver ljus.")
        #expect(reader.currentHeading == "Fotosyntes")
        session.press(.pauseToggle) // 3 presses: the sentence before
        #expect(reader.sentenceIndex == 1)
        #expect(model.savedSentence(saved) == 1, "the place is saved as it moves")
        let shown = RepetitionSession.readingNowPlaying(reader, title: saved.title)
        #expect(shown.title == "Fotosyntes" && shown.artist == "EarMind · Fotosyntes · mening 2 av 3", "Ke63 §4.3")
        model.end()
        #expect(session.reader == nil && !session.isActive)
        #expect(model.savedSentence(saved) == 1, "Avsluta keeps the place (Ke63 §5)")
    }

    @Test func theMockReadsTheMaterialsLinesAsParts() async throws {
        let draft = try await MockDrillMaker().readText(DrillMaterial(text: "Fotosyntes\nVäxter gör socker. De behöver ljus."),
                                                        subject: nil, grade: nil, title: nil)
        #expect(draft.parts.map(\.part) == [.heading, .para])
        #expect(draft.parts[1].sentences == ["Växter gör socker.", "De behöver ljus."])
        #expect(draft.drill.isText && draft.countsAs == 1)
        #expect(DrillTextDraft.countsAs(chars: 800) == 1 && DrillTextDraft.countsAs(chars: 801) == 2)
        #expect(DeviceVoiceDrillAudio.spread(["ab", "abcd"], over: 3) == [0...1, 1...3])
    }
}
