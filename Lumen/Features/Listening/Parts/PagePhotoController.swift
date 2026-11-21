import Observation
import UIKit

/// D221 (A138, G7 step 7d): what "Fota sidan" uses of `ListeningModel`: the model's own calls, unchanged.
@MainActor
protocol PagePhotoHost: AnyObject {
    var prep: PrepStore { get }
    var examMaterials: ExamMaterials? { get }
    var examClient: ExamClient? { get }
    var studyProfile: StudyProfileStore { get }
    /// The page's terms are new: the recogniser hears them first from now on.
    func refreshKeyterms()
    func useExamPlan(_ plan: ExamPlan)
    func startPracticeExam() async
    func startQuiz(for plan: ExamPlan) async
    func modeLog(_ line: String)
}

/// A36 (D115; A138, G7 step 7d): a photographed page. Moved unchanged out of `ListeningModel`: the page is read on the
/// phone (Vision); its key terms go to Förberedelser (they follow every question); K15 makes practice questions of
/// it when there is no practice exam to replace; then Provläge quizzes on it.
@MainActor
@Observable
final class PagePhotoController {
    @ObservationIgnored weak var host: (any PagePhotoHost)?
    /// What "Fota sidan" is doing, for the exam card ("Läser sidan …"); nil when nothing is.
    private(set) var status: String?
    private(set) var isReading = false

    func study(_ image: UIImage, for plan: ExamPlan) async {
        guard let host else { return }
        isReading = true
        defer { isReading = false }
        status = String(localized: "Läser sidan …")
        let text = await PagePhoto.text(of: image)
        guard text.count >= PagePhoto.minimumCharacters else {
            status = String(localized: "Jag kunde inte läsa sidan. Fota den rakt uppifrån, i bra ljus.")
            host.modeLog("Page photo: too little text (\(text.count) characters) (A36)")
            return
        }
        let title = PagePhoto.title()
        let terms = host.prep.add(title: title, text: text)?.terms.count ?? 0
        host.refreshKeyterms()
        host.modeLog("Page photo: \(text.count) characters, \(terms) terms (A36)")
        if let examMaterials = host.examMaterials, let examClient = host.examClient, PagePhoto.mayReplace(examMaterials.paper) {
            status = String(localized: "Gör övningsfrågor av sidan …")
            let profile = host.studyProfile.profile
            await examMaterials.read(text: text, name: title, with: examClient,
                                     subject: profile.subject.isEmpty ? plan.subject : profile.subject,
                                     grade: (profile.grade ?? plan.grade)?.rawValue)
        }
        status = nil
        if let examMaterials = host.examMaterials, examMaterials.isReady, examMaterials.paper.name == title {
            host.useExamPlan(plan)
            await host.startPracticeExam() // the page's own questions, one at a time
        } else {
            await host.startQuiz(for: plan) // the quiz, with the page's terms in every question
        }
    }

    func clearStatus() {
        status = nil
    }
}
