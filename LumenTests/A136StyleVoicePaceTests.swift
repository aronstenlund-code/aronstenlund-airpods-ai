import Foundation
import Testing
@testable import Lumen

/// A136 (D220): "Hur ska det låta?", the voice from the catalog and "Skriv i takt". Fake replies and silent mock
/// files only: no sound is made and nothing is fetched, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A136StyleVoicePaceTests {
    typealias MockSource = A78RepetitionTests.MockSource
    typealias MockTimer = A78RepetitionTests.MockTimer

    // MARK: Skriv i takt

    @Test func aPhraseIsThreeToSixWords() {
        #expect(WritingPace.phrases(count: 1) == [1] && WritingPace.phrases(count: 2) == [2], "a short sentence is one phrase")
        #expect(WritingPace.phrases(count: 5) == [5] && WritingPace.phrases(count: 6) == [6])
        #expect(WritingPace.phrases(count: 7) == [4, 3] && WritingPace.phrases(count: 8) == [4, 4])
        #expect(WritingPace.phrases(count: 9) == [6, 3] && WritingPace.phrases(count: 14) == [6, 4, 4])
        for count in 3...60 {
            let phrases = WritingPace.phrases(count: count)
            #expect(phrases.reduce(0, +) == count && phrases.allSatisfy { WritingPace.phrase.contains($0) }, "\(count) words: \(phrases)")
        }
        // A pause between two words (a comma) ends the phrase there, when both sides have three words.
        #expect(WritingPace.phrases(count: 8, gaps: [0, 0, 0.3, 0, 0, 0, 0]) == [3, 5])
        #expect(WritingPace.phrases(count: 5, gaps: [0, 0.3, 0, 0]) == [5], "never a phrase of two words")
        #expect(WritingPace.pause(words: 3) < WritingPace.pause(words: 6) && WritingPace.pause(words: 40) == 8)
    }

    @Test func thePlanStopsBetweenTheWordsOfTheServersTimes() {
        // One sentence of seven words, 0.3 s each with 0.1 s between: a stop after the fourth, three words after it.
        let words: [ClosedRange<TimeInterval>] = (0..<7).map { Double($0) * 0.4...Double($0) * 0.4 + 0.3 }
        let plan = WritingPace.plan(words: words, sentences: [0...2.7], sentenceWords: [7])
        #expect(plan.stops.count == 1 && plan.stops[0].words == 4 && abs(plan.stops[0].time - 1.55) < 0.001 && plan.tailWords == 3)

        // Two sentences of three words: the stop is where the first sentence ends, also without a pause there.
        let two: [ClosedRange<TimeInterval>] = (0..<6).map { Double($0) * 0.4...Double($0) * 0.4 + 0.4 }
        let split = WritingPace.plan(words: two, sentences: [0...1.2, 1.2...2.4], sentenceWords: [3, 3])
        #expect(split.stops.map(\.words) == [3] && abs(split.stops[0].time - 1.2) < 0.001 && split.tailWords == 3)

        // A file from before the word times: a stop after each sentence.
        let old = WritingPace.plan(words: [], sentences: [0...2, 2...4, 4...6], sentenceWords: [3, 4, 2])
        #expect(old.stops == [.init(time: 2, words: 3), .init(time: 4, words: 4)] && old.tailWords == 2)
        #expect(WritingPace.plan(words: [], sentences: [], sentenceWords: [5]).stops.isEmpty)
    }

    @Test func inPaceTheReaderIsSlowerAndWaitsAfterEveryPhrase() {
        let parts = [ReadingParagraph(sentences: ["Fotosyntes"], isHeading: true),
                     ReadingParagraph(sentences: ["Växter gör socker.", "De behöver ljus.", "Syre blir över."])]
        let source = MockSource()
        let timer = MockTimer()
        let player = ReadingPlayer(parts: parts, audio: { part in
            part == 0 ? ReadingAudio(url: URL(fileURLWithPath: "/tmp/p0.mp3"), times: [0...1])
                : ReadingAudio(url: URL(fileURLWithPath: "/tmp/p1.mp3"), times: [0...1, 1...2, 2...3])
        }, source: source, timer: timer)
        player.inPace = true
        player.tempo = 1.5 // the pace has its own speed
        player.start()
        #expect(source.last.rate == Float(WritingPace.rate) && source.last.until == nil, "a heading of one word plays to its end")
        source.last.finish()
        #expect(source.made.count == 1 && timer.pending?.seconds == WritingPace.pause(words: 1), "a pause before the next part")
        timer.fire()
        #expect(source.last.url.lastPathComponent == "p1.mp3" && source.last.until == 1, "to the end of the first sentence")
        source.last.currentTime = 1
        source.last.finish()
        #expect(player.phase == .reading && timer.pending?.seconds == WritingPace.pause(words: 3))
        #expect(source.made.count == 2, "the same file waits; nothing new is opened")
        timer.fire()
        #expect(source.last.until == 2 && source.last.plays == 2)

        // A press during the pause: paused, and nothing goes on by itself.
        source.last.currentTime = 2
        source.last.finish()
        player.handle(.long)
        #expect(player.isPaused && timer.pending == nil)
        player.handle(.long) // goes on from the start of the sentence the place is at (D164), to that sentence's end
        #expect(!player.isPaused && source.last.isPlaying && source.last.currentTime == 0 && source.last.until == 1)
        for end in [1.0, 2.0] {
            source.last.currentTime = end
            source.last.finish()
            timer.fire()
        }
        #expect(source.last.until == nil)
        source.last.finish()
        #expect(player.phase == .reading && timer.pending?.seconds == WritingPace.pause(words: 3), "the last phrase gets its pause")
        timer.fire()
        #expect(player.isAtEnd)
    }

    @Test func withoutThePaceNothingStops() {
        let source = MockSource()
        let timer = MockTimer()
        let player = ReadingPlayer(parts: [ReadingParagraph(sentences: ["Ett två tre.", "Fyra fem sex."])],
                                   audio: { _ in ReadingAudio(url: URL(fileURLWithPath: "/tmp/p.mp3"), times: [0...1, 1...2], words: [0...0.3, 0.3...0.6, 0.6...1, 1...1.3, 1.3...1.6, 1.6...2]) },
                                   source: source, timer: timer)
        player.start()
        #expect(source.last.until == nil && source.last.rate == 1)
        source.last.finish()
        #expect(player.isAtEnd && timer.pending == nil)
    }

    // MARK: The style and the voice

    @Test func theStyleGoesWithEverySaveAndTheVoiceOnlyWithTheFirst() {
        var drill = Drill.text(title: "T", summary: A79A81RepetitionTests.summary, parts: [DrillItem.textPart("En.", part: .para)])
        var body = DrillCloudClient.saveBody(drill)["drill"] as? [String: Any]
        #expect(body?["style"] == nil && body?["voice_id"] == nil, "nothing chosen, nothing sent")
        drill.style = "  Lugnt, som en lärare  "
        drill.voiceID = "astrid0000000001"
        body = DrillCloudClient.saveBody(drill)["drill"] as? [String: Any]
        #expect(body?["style"] as? String == "Lugnt, som en lärare" && body?["voice_id"] as? String == "astrid0000000001")
        drill.serverID = "srv-1"
        body = DrillCloudClient.saveBody(drill)["drill"] as? [String: Any]
        #expect(body?["style"] as? String == "Lugnt, som en lärare" && body?["voice_id"] == nil, "the voice is locked after the first save")
        drill.style = String(repeating: "a", count: 200)
        #expect((DrillCloudClient.saveBody(drill)["drill"] as? [String: Any])?["style"] as? String == String(repeating: "a", count: 80))
        #expect(Drill.cleanStyle("   ") == nil && SaySound(voiceID: nil, style: " ") == .plain)
    }

    @Test func theServersStyleVoiceAndWordTimesAreRead() throws {
        let info = try JSONDecoder().decode(DrillCloudView.Info.self, from: Data(#"{"id":"x","style":"Viskande","voice_id":"nils000000000004"}"#.utf8))
        #expect(info.style == "Viskande" && info.voice_id == "nils000000000004")
        let plain = try JSONDecoder().decode(DrillCloudView.Info.self, from: Data(#"{"id":"x","style":null,"voice_id":null}"#.utf8))
        #expect(plain.style == nil && plain.voice_id == nil)
        let file = try JSONDecoder().decode(DrillCloudView.File.self, from: Data(#"{"status":"done","url":"https://x/a.mp3","sentences":[[0,700]],"words":[[0,300],[350,700]]}"#.utf8))
        #expect(file.words == [[0, 300], [350, 700]])
        let old = try JSONDecoder().decode(DrillCloudView.File.self, from: Data(#"{"status":"done","url":"https://x/a.mp3","words":null}"#.utf8))
        #expect(old.words == nil)
        var item = DrillItem.textPart("Ett två.", part: .para)
        item.wordTimesMs = file.words
        #expect(item.wordTimes == [0...0.3, 0.35...0.7])
    }

    @Test func theCatalogAndTheLibraryAreRead() throws {
        let json = #"{"voices":[{"name":"A","id":"a"}],"default_id":"a","catalog":[{"voice_id":"astrid0000000001","name":"Astrid","gender":"female","age":"young","accent":"standard","language":"sv","preview_url":"https://storage.example.com/astrid.mp3","description":"Lugn, rikssvenska"},{"voice_id":"nils000000000004","name":"Nils","accent":"scanian","preview_url":"http://insecure.example.com/n.mp3","description":null}]}"#
        let listing = try JSONDecoder().decode(SayVoice.Listing.self, from: Data(json.utf8))
        let catalog = try #require(listing.catalog)
        #expect(catalog.map(\.name) == ["Astrid", "Nils"] && catalog[0].canBeChosen && catalog[0].line == "Lugn, rikssvenska")
        #expect(catalog[0].previewURL?.host == "storage.example.com")
        #expect(catalog[1].previewURL == nil && catalog[1].line == "Scanian", "only https is fetched; without a description the accent")
        let empty = try JSONDecoder().decode(SayVoice.Listing.self, from: Data(#"{"voices":[],"catalog":[]}"#.utf8))
        #expect(empty.catalog == [])
        let library = try JSONDecoder().decode(SayVoice.Listing.self, from: Data(#"{"library":[{"voice_id":"erik000000000009","name":"Erik"}],"selectable":false}"#.utf8))
        #expect(library.library?.first?.name == "Erik" && library.selectable == false)
    }

    @Test func theWordsAreKellys() {
        #expect(SayText.stylePrompt == "Hur ska det låta?" && SayText.paceTitle == "Skriv i takt" && SayText.paceCapsule == "I takt")
        #expect(SaySound.suggestions == ["Tydligt", "Lugnt", "Glatt", "Viskande"])
        #expect(SayVoicesSheet.footnote == "Provlyssning kostar inget. En ny röst blir nytt ljud.")
        // Ke75 §2: a suggestion is written alone, or after a comma when there is text already.
        #expect(SaySound.adding("Lugnt", to: "") == "Lugnt" && SaySound.adding("Glatt", to: "Lugnt ") == "Lugnt, glatt")
        #expect(SaySound.adding("Viskande", to: "Lugnt,") == "Lugnt, viskande")
        #expect(SayVoicesSheet.notInCatalog == "Kan bara provlyssnas")
        // Kelly's review: a capsule in Senaste says the style's first word, else the chosen voice's name.
        var said = Drill.text(title: "T", summary: A79A81RepetitionTests.summary, parts: [DrillItem.textPart("En rad.", part: .para)])
        let voices = [SayVoice(voice_id: "nils000000000004", name: "Nils")]
        #expect(SayText.soundMark(said, voices: voices) == nil)
        said.voiceID = "nils000000000004"
        #expect(SayText.soundMark(said, voices: voices) == "Nils" && SayText.soundMark(said, voices: []) == nil)
        said.style = "Lugnt, som en lärare"
        #expect(SayText.soundMark(said, voices: voices) == "Lugnt", "the style goes before the voice")
    }

    // MARK: Säg i AirPods with a sound

    func model(_ name: String) throws -> (RepetitionModel, A107StartAudioTests.DeferredCloud, DrillStore, CloudDrillAudio) {
        let folder = try A79A81RepetitionTests.folder(name)
        let store = DrillStore(url: folder.appendingPathComponent("drills.json"))
        let cloud = A107StartAudioTests.DeferredCloud()
        cloud.idPerExam = true
        let audio = CloudDrillAudio(cloud: cloud, store: store, folder: folder, pollInterval: .milliseconds(1), maxPolls: 20)
        let session = RepetitionSession(inputs: [], makeSource: { MockSource() }, makeTimer: { MockTimer() },
                                        defaults: try #require(UserDefaults(suiteName: "\(name)-\(UUID())")),
                                        activatesAudioSession: false)
        let model = RepetitionModel(store: store, session: session, maker: MockDrillMaker(), audio: audio,
                                    sharing: DrillShareClient(cloud: cloud), remote: RemoteCommandHub(), cloud: cloud)
        return (model, cloud, store, audio)
    }

    @Test func theSameTextWithAnotherSoundIsAnotherExamAndTheSameSoundIsTheSame() async throws {
        let (model, cloud, store, audio) = try model("a136-sound")
        let text = "1918: Vapenstillestånd den 11 november."
        let calm = SaySound(voiceID: "astrid0000000001", style: "Lugnt")

        let plain = try #require(await model.say(text, repeatMinutes: 10))
        model.end()
        for _ in 0..<50 where audio.preparing.contains(plain.id) { try? await Task.sleep(for: .milliseconds(2)) }
        let styled = try #require(await model.say(text, repeatMinutes: 10, sound: calm, inPace: true))
        #expect(model.session.saying?.inPace == true && model.session.reader?.inPace == true, "Skriv i takt reaches the reader")
        model.end()
        for _ in 0..<50 where audio.preparing.contains(styled.id) { try? await Task.sleep(for: .milliseconds(2)) }

        #expect(styled.id != plain.id && store.drills.count == 2, "a new voice or style is new sound: another exam")
        #expect(store.drill(styled.id)?.style == "Lugnt" && store.drill(styled.id)?.voiceID == "astrid0000000001")
        let sent = try #require(cloud.saves.last?["drill"] as? [String: Any])
        #expect(sent["style"] as? String == "Lugnt" && sent["voice_id"] as? String == "astrid0000000001")
        #expect((cloud.saves.first?["drill"] as? [String: Any])?["style"] == nil)

        // The same text, voice and style again: the same exam, nothing new saved.
        let saves = cloud.saves.count
        let again = try #require(await model.say(text, repeatMinutes: 10, sound: SaySound(voiceID: "astrid0000000001", style: " Lugnt ")))
        model.end()
        for _ in 0..<50 where audio.preparing.contains(again.id) { try? await Task.sleep(for: .milliseconds(2)) }
        #expect(again.id == styled.id && store.drills.count == 2 && cloud.saves.count == saves)

        // Senaste keeps the text once per sound, and each is found by its own sound.
        #expect(model.recentSaid.count == 2)
        #expect(model.saidDrill(for: text)?.id == plain.id && model.saidDrill(for: text, sound: calm)?.id == styled.id)
        #expect(model.saidDrill(for: text, sound: SaySound(style: "Glatt")) == nil)
    }

    @Test func theCostIsAskedWithTheStyleAndTheVoice() async throws {
        let (model, cloud, _, _) = try model("a136-cost")
        cloud.costAnswer = DrillCost(cost: 120, remaining: 1236, limit: 1500, enough: true)
        let answer = await model.sayCost("En text.", sound: SaySound(voiceID: "nils000000000004", style: "Viskande"))
        #expect(answer?.cost == 120)
        #expect(cloud.costAsked.last?.style == "Viskande" && cloud.costAsked.last?.voiceID == "nils000000000004")
        _ = await model.sayCost("En text.")
        #expect(cloud.costAsked.last?.style == nil && cloud.costAsked.last?.voiceID == nil)
    }

    @Test func soundOnThePhoneIsOnlyReusedForTheSameVoiceAndStyle() {
        var old = Drill.text(title: "T", summary: A79A81RepetitionTests.summary, parts: [DrillItem.textPart("En rad.", part: .para)])
        old.items[0].longAudio = "en.mp3"
        old.items[0].wordTimesMs = [[0, 300], [350, 700]]
        var new = Drill.text(title: "T", summary: A79A81RepetitionTests.summary, parts: [DrillItem.textPart("En rad.", part: .para)])
        let same = RepetitionModel.withSoundAlreadyHere(new, from: [old])
        #expect(same.items[0].longAudio == "en.mp3" && same.items[0].wordTimesMs == [[0, 300], [350, 700]])
        new.style = "Glatt"
        #expect(RepetitionModel.withSoundAlreadyHere(new, from: [old]).items[0].longAudio == nil, "another style is other sound")
        new.style = nil
        new.voiceID = "nils000000000004"
        #expect(RepetitionModel.withSoundAlreadyHere(new, from: [old]).items[0].longAudio == nil, "another voice is other sound")
    }

    // MARK: A140 (D223): mixed voices and the server's choice

    @Test func mixedVoicesAreSentAtTheFirstSaveAndReadPerPart() throws {
        var drill = Drill.text(title: "T", summary: A79A81RepetitionTests.summary, parts: [DrillItem.textPart("En.", part: .para)])
        drill.mixVoices = true
        #expect((DrillCloudClient.saveBody(drill)["drill"] as? [String: Any])?["mix_voices"] as? Bool == true)
        drill.serverID = "srv-1"
        #expect((DrillCloudClient.saveBody(drill)["drill"] as? [String: Any])?["mix_voices"] == nil, "locked after the first save")
        // A mix has no single voice, and it is another sound than one voice.
        #expect(SaySound(voiceID: "astrid0000000001", mix: true).voiceID == nil && SaySound(mix: true) != .plain)
        #expect(!SaySound(style: "Lugnt", mix: true).serverPicksVoice && SaySound(style: "Lugnt").serverPicksVoice)
        #expect(!SaySound(voiceID: "astrid0000000001", style: "Lugnt").serverPicksVoice && !SaySound.plain.serverPicksVoice)

        let json = #"{"id":"i1","position":0,"part":"para","text":"En.","voice_id":"nils000000000004","audio":{"text":{"status":"done","url":"https://x/a.mp3"}}}"#
        let item = try JSONDecoder().decode(DrillCloudView.Item.self, from: Data(json.utf8))
        #expect(item.voice_id == "nils000000000004")
        let info = try JSONDecoder().decode(DrillCloudView.Info.self, from: Data(#"{"id":"x","mix_voices":true}"#.utf8))
        #expect(info.mix_voices == true)
        let cost = try JSONDecoder().decode(DrillCost.self, from: Data(#"{"cost":120,"remaining":1236,"voice_id":"gustav000000003","voice_reason":"Mörk och tydlig."}"#.utf8))
        #expect(cost.voice_id == "gustav000000003" && cost.voice_reason == "Mörk och tydlig.")
    }

    @Test func theVoiceTheServerChoseIsKeptAndTheTextIsTheSameNextTime() async throws {
        let (model, cloud, store, audio) = try model("a140-picked")
        let text = "1918: Vapenstillestånd den 11 november."
        let styled = SaySound(style: "Lugnt")
        let said = try #require(await model.say(text, repeatMinutes: 10, sound: styled, picked: ("gustav000000003", "Mörk och tydlig.")))
        model.end()
        for _ in 0..<50 where audio.preparing.contains(said.id) { try? await Task.sleep(for: .milliseconds(2)) }
        let kept = try #require(store.drill(said.id))
        #expect(kept.voiceID == "gustav000000003" && kept.voicePicked == true && kept.voiceReason == "Mörk och tydlig.")
        #expect((cloud.saves.first?["drill"] as? [String: Any])?["voice_id"] as? String == "gustav000000003", "the voice that was shown is the one saved")

        // The same text and style, still no voice chosen: the same exam (the server is not asked to choose again).
        #expect(model.saidDrill(for: text, sound: styled)?.id == said.id)
        #expect(model.saidDrill(for: text, sound: SaySound(style: "Glatt")) == nil)
        let saves = cloud.saves.count
        let again = try #require(await model.say(text, repeatMinutes: 10, sound: styled))
        model.end()
        for _ in 0..<50 where audio.preparing.contains(again.id) { try? await Task.sleep(for: .milliseconds(2)) }
        #expect(again.id == said.id && cloud.saves.count == saves)
        // A voice chosen by hand is not overridden by a choice of the server's.
        let own = try #require(await model.say("En annan text.", repeatMinutes: 10, sound: SaySound(voiceID: "astrid0000000001", style: "Lugnt"),
                                               picked: ("gustav000000003", nil)))
        model.end()
        #expect(store.drill(own.id)?.voiceID == "astrid0000000001" && store.drill(own.id)?.voicePicked == nil)
    }

    @Test func theVoiceThatSpeaksIsNamed() throws {
        let (model, _, _, _) = try model("a140-speaks")
        model.stageSayVoices([SayVoice(voice_id: "astrid0000000001", name: "Astrid"), SayVoice(voice_id: "nils000000000004", name: "Nils")],
                             defaultName: "Standard")
        var drill = Drill.text(title: "T", summary: A79A81RepetitionTests.summary,
                               parts: [DrillItem.textPart("En.", part: .para), DrillItem.textPart("Två.", part: .para)])
        #expect(model.speakingVoice(drill, part: 0) == "Standard", "no voice chosen: the server's own")
        drill.voiceID = "astrid0000000001"
        #expect(model.speakingVoice(drill, part: 1) == "Astrid")
        drill.voiceID = nil
        drill.mixVoices = true
        drill.items[0].voiceID = "nils000000000004"
        drill.items[1].voiceID = "astrid0000000001"
        #expect(model.speakingVoice(drill, part: 0) == "Nils" && model.speakingVoice(drill, part: 1) == "Astrid")
        #expect(SayText.playingLine(voice: "Nils") == "Spelar i AirPods · Nils" && SayText.playingLine(voice: nil) == "Spelar i AirPods")
        #expect(SayText.pickedLine(name: "Gustav", reason: "Mörk och tydlig.") == "Gustav · Mörk och tydlig.")
        #expect(SayText.soundMark(drill, voices: model.sayVoices) == "Blandat")
        // K99: voices under review and the default voice are read.
        let listing = try JSONDecoder().decode(SayVoice.Listing.self, from: Data(#"{"catalog":[{"voice_id":"hindi00000000006","name":"Hindi","review":true}],"default_voice":{"voice_id":"astrid0000000001","name":"Astrid","in_catalog":true}}"#.utf8))
        #expect(listing.catalog?.first?.isUnderReview == true && listing.default_voice?.name == "Astrid")
    }

    @Test func theCatalogIsReadOnceAndAnEmptyOneShowsNoVoices() async throws {
        let (model, _, _, _) = try model("a136-voices")
        await model.loadSayVoices()
        #expect(model.sayVoices.isEmpty, "a server without a catalog: nothing to choose")
        #expect(await model.searchVoices("skånska") == [])
    }
}
