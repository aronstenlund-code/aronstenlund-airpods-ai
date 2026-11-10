import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Lumen

/// A26: Kelly's corrections after A18 (R1 the picture fills the intro card, R5 the voice page describes voices).
@Suite struct A26Tests {
    private let picture = CGSize(width: 600, height: 935) // IntroElias@2x

    @Test func thePictureAlwaysFillsTheCardAndTheEarbudIsInside() {
        for card in [CGSize(width: 354, height: 290), CGSize(width: 327, height: 160), CGSize(width: 354, height: 620),
                     CGSize(width: 600, height: 200)] {
            let fill = IntroHeroView.fill(card: card, picture: picture, focus: IntroHeroView.ringOrigin)
            #expect(fill.origin.x <= 0 && fill.origin.y <= 0, "no white above or left of the picture (\(card))")
            #expect(fill.origin.x + fill.size.width >= card.width - 0.5, "no white on the right (\(card))")
            #expect(fill.origin.y + fill.size.height >= card.height - 0.5, "no white below (\(card))")
            #expect(fill.focus.x > 0 && fill.focus.x < card.width, "the earbud is in the card (\(card))")
            #expect(fill.focus.y > 0 && fill.focus.y < card.height, "the earbud is in the card (\(card))")
            #expect(abs(fill.size.width / fill.size.height - picture.width / picture.height) < 0.001, "not stretched")
        }
    }

    @Test func aShortCardMovesThePictureUpSoTheEarbudIsNotAtTheEdge() {
        let card = CGSize(width: 327, height: 160) // the SE
        let fill = IntroHeroView.fill(card: card, picture: picture, focus: IntroHeroView.ringOrigin)
        #expect(fill.origin.y < 0)
        #expect(abs(fill.focus.y - card.height * 0.6) < 0.5)
    }

    @Test func aTallCardKeepsTheTop() {
        let card = CGSize(width: 354, height: 620)
        let fill = IntroHeroView.fill(card: card, picture: picture, focus: IntroHeroView.ringOrigin)
        #expect(fill.origin.y == 0)
    }

    @Test func theHeroIsSmallerOnTheSE() {
        #expect(IntroView.heroHeight(for: 525) < 190)
        #expect(IntroView.heroHeight(for: 700) == 294)
        #expect(IntroView.heroHeight(for: 900) == 320)
    }

    @Test func voicesAreDescribedNotNamed() {
        let adam = VoiceChoice(kind: .elevenLabs, voiceID: "x0u3EW21dbrORJzOq1m9", name: "Adam")
        #expect(VoiceDescription.words(for: adam).title == "Lugn berättarröst")
        #expect(VoiceDescription.words(for: adam, described: "Mansröst, lugn").title == "Mansröst, lugn",
                "the service's description wins")
        #expect(VoiceDescription.words(for: .appleDefault) == .init(title: "iPhonens röst", detail: "Fungerar utan nät"))
        let unknown = VoiceChoice(kind: .elevenLabs, voiceID: "abc1234567", name: "Saga")
        #expect(VoiceDescription.words(for: unknown).title == "Saga", "an unknown voice keeps its name")
    }

    @Test func theCatalogReadsOptionalDescriptions() {
        let json = #"{"voices":[{"name":"Adam","id":"a1","description":"Mansröst, lugn"},{"name":"Saga","id":"s1"}],"default_id":"a1"}"#
        let descriptions = VoiceCatalog.descriptions(Data(json.utf8))
        #expect(descriptions == ["a1": "Mansröst, lugn"])
        #expect(VoiceCatalog.descriptions(Data("nope".utf8)).isEmpty)
    }
}
