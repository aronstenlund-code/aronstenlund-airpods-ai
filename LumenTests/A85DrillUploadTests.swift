import Foundation
import Testing
import UIKit
@testable import Lumen

/// A85 (Aron 22:13): "Ingen internetanslutning" on 5G after two photos. The pages are pixels, not points; a dropped
/// connection is tried again and is not "offline"; the server's refusals are shown as they are.
@MainActor
@Suite struct A85DrillUploadTests {
    @Test func aPhotoBecomesAtMost1600PixelsWhateverTheScreenScale() throws {
        // A 4 032 × 3 024 photo, drawn as a 3× image (what the camera and the document scanner give).
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 1_344, height: 1_008), format: format).image { context in
            for i in 0..<200 { // stripes like a photographed screen
                UIColor(white: CGFloat(i % 2), alpha: 1).setFill()
                context.fill(CGRect(x: CGFloat(i) * 6.72, y: 0, width: 3.36, height: 1_008))
            }
        }
        let data = try #require(ExamMaterials.jpeg(photo))
        let page = try #require(UIImage(data: data))
        #expect(max(page.size.width * page.scale, page.size.height * page.scale) <= 1_600)
        #expect(data.count <= ExamMaterials.maxPageBytes, "\(data.count) bytes")
    }

    @Test func aDroppedConnectionIsTriedAgain() {
        #expect(DrillClient.isTransient(.networkConnectionLost))
        #expect(DrillClient.isTransient(.timedOut))
        #expect(!DrillClient.isTransient(.notConnectedToInternet))
        #expect(!DrillClient.isTransient(.cancelled))
    }

    @Test func theServersRefusalIsShown() {
        let body = Data(#"{"error":{"code":"payload_too_large","message":"Bilderna är för stora.","fallback":false}}"#.utf8)
        #expect(DrillClient.refusal(status: 413, data: body) == .refused("Bilderna är för stora."))
        #expect(DrillClient.refusal(status: 413, data: body).userMessage == "Bilderna är för stora.")
        #expect(DrillClient.refusal(status: 502, data: Data()) == .server("HTTP 502"))
        #expect(DrillMakingError.server("URLError -1005").userMessage == "Det gick inte att skapa frågorna. Försök igen.")
        #expect(DrillMakingError.offline.userMessage.hasPrefix("Ingen internetanslutning"))
    }
}
