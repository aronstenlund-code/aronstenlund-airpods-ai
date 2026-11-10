import Foundation
import UIKit
import Vision

/// A36 (D115): the text of a photographed page, read on the iPhone with Vision. The photo itself is never saved or sent.
enum PagePhoto {
    /// Fewer characters than this is not a page (a blurry or dark photo).
    static let minimumCharacters = 40

    nonisolated static func text(of image: UIImage) async -> String {
        // Drawn upright and at most 1 600 px first (the photo's orientation is then part of the pixels).
        guard let data = ExamMaterials.jpeg(image), let upright = UIImage(data: data)?.cgImage else { return "" }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [Locale.Language(identifier: "sv-SE"), Locale.Language(identifier: "en-US")]
        guard let observations = try? await request.perform(on: upright) else { return "" }
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// "Fotad sida 10 nov 14:52"
    static func title(at date: Date = Date()) -> String {
        "Fotad sida " + date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    /// A photographed page may replace the practice exam only when there is none, or the last one was a page too.
    static func mayReplace(_ paper: ExamPaper) -> Bool {
        paper.tasks.isEmpty || paper.name.hasPrefix("Fotad sida")
    }
}
