import Foundation
import Testing
import UIKit
@testable import Lumen

/// A36 (D115): "Fota sidan": the page is read on the phone, and may replace only a photographed page.
@Suite struct PagePhotoTests {
    @Test func onlyAPageOrNothingIsReplaced() {
        #expect(PagePhoto.mayReplace(ExamPaper()))
        let task = ExamTask(no: "1", text: "t", points: .zero, answer: "", assessment: "")
        #expect(PagePhoto.mayReplace(ExamPaper(tasks: [task], name: PagePhoto.title())))
        #expect(!PagePhoto.mayReplace(ExamPaper(tasks: [task], name: "Övningsprov")), "an uploaded practice exam stays")
    }

    @Test func aPrintedPageIsReadOnThePhone() async {
        let size = CGSize(width: 1_400, height: 500)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let text = "Fotosyntesen omvandlar ljusenergi till kemisk energi.\nKlorofyllet i bladen fångar ljuset."
            text.draw(in: CGRect(x: 40, y: 60, width: 1_320, height: 400),
                      withAttributes: [.font: UIFont.systemFont(ofSize: 44), .foregroundColor: UIColor.black])
        }
        let read = await PagePhoto.text(of: image).lowercased()
        #expect(read.contains("fotosyntes"), "read: \(read)")
        #expect(read.count >= PagePhoto.minimumCharacters)
    }
}
