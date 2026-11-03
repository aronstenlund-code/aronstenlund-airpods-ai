import Foundation
import PDFKit

/// Reads the text of an imported file (item 9): PDF via PDFKit, anything else as UTF-8 text.
enum DocumentText {
    enum ImportError: Error, LocalizedError, Equatable {
        case noAccess
        case unreadable(String)
        case empty

        var errorDescription: String? {
            switch self {
            case .noAccess: "No permission to read the file"
            case .unreadable(let detail): "Could not read the file: \(detail)"
            case .empty: "The file contains no text"
            }
        }
    }

    static func read(_ url: URL) throws(ImportError) -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let text: String
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { throw ImportError.unreadable("not a readable PDF") }
            text = document.string ?? ""
        } else {
            do {
                text = try String(contentsOf: url, encoding: .utf8)
            } catch {
                throw ImportError.unreadable(error.localizedDescription)
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportError.empty }
        return trimmed
    }
}
