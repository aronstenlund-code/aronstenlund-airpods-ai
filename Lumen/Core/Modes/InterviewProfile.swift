import Foundation
import PDFKit

/// D81: the CV and the job ad for Intervjuläge. Both stay on the phone; only a compressed text goes along as
/// `persona_setup` (the backend's limit is 2 000 characters since Kevin's D81), with contact details removed first.
enum InterviewProfile {
    static let setupLimit = 2_000 // Kevin D81: the backend takes 2 000 for job ad + CV
    /// The job ad gets at most this; the CV gets the rest (and the ad's unused share).
    static let jobAdShare = 800

    /// The text of a PDF or a plain-text file. Nil when nothing readable is in it (a scanned PDF).
    static func text(from url: URL) -> String? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let raw: String?
        if url.pathExtension.lowercased() == "pdf" {
            raw = PDFDocument(url: url)?.string
        } else {
            raw = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1))
        }
        guard let raw else { return nil }
        let cleaned = collapse(raw)
        return cleaned.isEmpty ? nil : String(cleaned.prefix(20_000))
    }

    /// E-mail addresses, phone numbers, personnummer and street addresses are not needed to answer an interview
    /// question, so they never leave the phone.
    static func withoutContactDetails(_ text: String) -> String {
        var out = text
        let patterns = [
            #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,               // e-mail
            #"\b(19|20)?\d{6}[-+]?\d{4}\b"#,                                    // personnummer
            #"(?<![\d\w])(\+46|0)[\s-]?\d{1,3}([\s-]?\d{2,4}){2,4}"#,             // phone (not inside "2010-2015")
            #"\b[A-ZÅÄÖ][a-zåäö]+(gatan|vägen|gränd|torget|allén|stigen|backen)\s+\d+[A-Za-z]?\b"#, // street
            #"\b\d{3}\s?\d{2}\s+[A-ZÅÄÖ][a-zåäö]+\b"#,                          // postcode + town
            #"https?://\S+|www\.\S+|linkedin\.com/\S+"#,                        // links
        ]
        for pattern in patterns {
            out = out.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return collapse(out)
    }

    /// The setup sent with every interview call: "Jobbannons: … CV: …", within the limit, cut at a sentence.
    static func setup(jobAd: String, cv: String) -> String {
        let cleanCV = withoutContactDetails(cv)
        guard !cleanCV.isEmpty else { return jobAd } // no CV: as before D81
        let ad = collapse(jobAd)
        let adPart = ad.isEmpty ? "" : "Jobbannons: " + cut(ad, to: jobAdShare) + " "
        let room = setupLimit - adPart.count - "CV: ".count
        return adPart + "CV: " + cut(cleanCV, to: max(0, room))
    }

    static func collapse(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// At most `limit` characters, ending at the last full stop or line within it when there is one.
    static func cut(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        if let stop = head.lastIndex(where: { ".!?;•".contains($0) }), head.distance(from: head.startIndex, to: stop) > limit / 2 {
            return String(head[...stop])
        }
        return head
    }
}
