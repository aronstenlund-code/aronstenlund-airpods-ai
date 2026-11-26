import CryptoKit
import Foundation

/// A164 (D263): the sound of an own deck as the player wants it. A part's sound is the user's recording when there is
/// one; otherwise the phone's own voice reading the text, written to a file the first time. Only files on the phone.
@MainActor
final class OwnDeckAudio {
    private let store: OwnDeckStore
    private let voice: any PhoneVoicing
    /// The phone's voice as files. They can be made again at any time, so they are not in the backup either.
    let spokenFolder: URL
    private var making: Set<String> = []

    init(store: OwnDeckStore, voice: any PhoneVoicing, spokenFolder: URL? = nil) {
        self.store = store
        self.voice = voice
        self.spokenFolder = spokenFolder ?? store.folder.appending(path: "spoken", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: self.spokenFolder, withIntermediateDirectories: true)
        OwnDeckStore.keepOutOfBackup(self.spokenFolder)
    }

    /// The file to play for this part: the recording, else the phone's voice if it has been made; nil when there is
    /// nothing to play yet.
    func url(_ part: OwnPart, of card: OwnCard, language: String) -> URL? {
        if let file = card.recording(part) {
            let recorded = store.url(for: file)
            if FileManager.default.fileExists(atPath: recorded.path) { return recorded }
        }
        let text = card.text(part).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let spoken = spokenURL(for: text, language: language)
        return FileManager.default.fileExists(atPath: spoken.path) ? spoken : nil
    }

    /// The question and the answer for the player. There is one answer, so the short answer is the whole long one.
    /// Nil until both files are there; the player waits, as it does for an exam's sound.
    func track(for card: OwnCard, language: String) -> RepetitionTrack? {
        guard let question = url(.question, of: card, language: language),
              let answer = url(.answer, of: card, language: language) else { return nil }
        return RepetitionTrack(question: question, long: answer, short: .prefix(ofLongUntil: .infinity))
    }

    /// Makes the phone's voice for every part that has a text and no recording, in play order.
    func prepare(_ cards: [OwnCard], language: String) async {
        for card in cards {
            for part in OwnPart.allCases where url(part, of: card, language: language) == nil {
                let text = card.text(part).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let target = spokenURL(for: text, language: language)
                guard !making.contains(target.lastPathComponent) else { continue }
                making.insert(target.lastPathComponent)
                // To a temporary name first: a half-written file is never taken for the sound.
                let draft = target.appendingPathExtension("part")
                if await voice.write(text, language: language, to: draft) {
                    try? FileManager.default.removeItem(at: target)
                    try? FileManager.default.moveItem(at: draft, to: target)
                } else {
                    try? FileManager.default.removeItem(at: draft)
                }
                making.remove(target.lastPathComponent)
            }
        }
    }

    /// One file per text and language: the same text is spoken once.
    func spokenURL(for text: String, language: String) -> URL {
        let digest = SHA256.hash(data: Data("own-voice-v1|\(language)|\(text)".utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return spokenFolder.appending(path: "\(name).wav")
    }
}
