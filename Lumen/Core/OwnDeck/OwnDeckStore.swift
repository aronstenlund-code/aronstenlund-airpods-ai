import Foundation
import Observation

/// A164 (D263): where the user's own decks are kept. One file with the texts and a folder with the recordings, both in
/// the app's own Application Support. Nothing here knows of the server. The recordings folder is kept out of the
/// iCloud backup, so the sound stays on this phone; deleting a card, a deck or the account (`LocalWipe`) removes it.
@MainActor
@Observable
final class OwnDeckStore {
    /// Newest first.
    private(set) var decks: [OwnDeck] = []
    @ObservationIgnored let folder: URL

    static var defaultFolder: URL {
        URL.applicationSupportDirectory.appending(path: "OwnDecks", directoryHint: .isDirectory)
    }

    var audioFolder: URL { folder.appending(path: "audio", directoryHint: .isDirectory) }
    private var fileURL: URL { folder.appending(path: "decks.json") }

    init(folder: URL? = nil) {
        self.folder = folder ?? Self.defaultFolder
        try? FileManager.default.createDirectory(at: audioFolder, withIntermediateDirectories: true)
        Self.keepOutOfBackup(audioFolder)
        if let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode([OwnDeck].self, from: data) {
            decks = saved
        }
    }

    /// The sound stays on the phone: not in the iCloud backup either.
    static func keepOutOfBackup(_ folder: URL) {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = folder
        try? url.setResourceValues(values)
    }

    func deck(_ id: UUID) -> OwnDeck? {
        decks.first { $0.id == id }
    }

    /// Adds the deck, or replaces the one with the same id.
    func save(_ deck: OwnDeck) {
        var deck = deck
        deck.updatedAt = Date()
        if let index = decks.firstIndex(where: { $0.id == deck.id }) {
            decks[index] = deck
        } else {
            decks.insert(deck, at: 0)
        }
        write()
    }

    /// The deck, its texts and every recording in it.
    func delete(_ id: UUID) {
        guard let deck = deck(id) else { return }
        for card in deck.cards {
            remove(card.questionRecording)
            remove(card.answerRecording)
        }
        decks.removeAll { $0.id == id }
        write()
    }

    // MARK: The recordings

    func url(for file: OwnRecordingFile) -> URL {
        audioFolder.appending(path: file.name)
    }

    /// Where a new recording goes. AAC in an m4a file from the phone's recorder: small, and the player opens it like
    /// any other file.
    func newRecordingURL(fileExtension: String = "m4a") -> URL {
        audioFolder.appending(path: "\(UUID().uuidString).\(fileExtension)")
    }

    func remove(_ file: OwnRecordingFile?) {
        guard let file else { return }
        try? FileManager.default.removeItem(at: url(for: file))
    }

    private func write() {
        guard let data = try? JSONEncoder().encode(decks) else { return }
        // Readable while the phone is locked after the first unlock: practising goes on with the screen off.
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
