import SwiftUI
import Testing
import UIKit
@testable import Lumen

/// A148 (D218 point 4, Kelly Ke79): what VoiceOver says on the new screens, and the colours that carry small text.
@MainActor
@Suite struct A148AccessibilityTests {
    // MARK: What VoiceOver says

    @Test func theCostIsSaidAsACost() {
        #expect(SayText.spokenCost("120 krediter") == "Kostar 120 krediter")
        #expect(SayText.spokenCost("120 krediter · du har 88") == "Kostar 120 krediter, du har 88")
        #expect(SayText.spokenCost(ShopText.included) == ShopText.included, "words that are no number stand as they are")
    }

    @Test func theTempoIsSaidInWords() {
        #expect(SayText.spokenTempo(1) == "Tempo, normal")
        #expect(SayText.spokenTempo(1.25) == "Tempo, 1,25 gånger")
        #expect(SayText.spokenTempo(0.8) == "Tempo, 0,8 gånger")
    }

    @Test func aCapsuleInSenasteSaysTheWholeTextAndItsVoice() {
        let text = "Fotosyntes: koldioxid + vatten + ljus blir socker och syre.\nCellandning: socker + syre blir energi."
        #expect(SayText.capsule(text).hasSuffix("…"), "the screen cuts it")
        let spoken = SayText.spokenCapsule(text, mark: "Astrid")
        #expect(!spoken.contains("…") && spoken.hasPrefix("Fotosyntes: koldioxid") && spoken.hasSuffix("energi., Astrid"))
        #expect(SayText.spokenCapsule("Hej", mark: nil) == "Hej")
    }

    @Test func theCardThatPlaysIsOneSentence() {
        #expect(SayText.spokenPlaying(voice: "Astrid", secondsLeft: 420, paused: false) == "Spelar i AirPods med Astrid, 7 minuter kvar")
        #expect(SayText.spokenPlaying(voice: nil, secondsLeft: 30, paused: false) == "Spelar i AirPods, 1 minut kvar")
        #expect(SayText.spokenPlaying(voice: "Astrid", secondsLeft: 61, paused: true) == "Spelar i AirPods med Astrid, 2 minuter kvar, pausad")
    }

    // MARK: Contrast (WCAG AA: 4.5:1 for small text)

    private func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func contrast(_ text: Color, on background: UIColor, dark: Bool) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let a = luminance(UIColor(text).resolvedColor(with: traits))
        let b = luminance(background.resolvedColor(with: traits))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    @Test func theGreyTextPassesAAOnEveryBackgroundItStandsOn() {
        for dark in [false, true] {
            for background in [UIColor.systemBackground, .secondarySystemBackground, .secondarySystemGroupedBackground,
                               .systemGroupedBackground] {
                #expect(contrast(LumenColor.secondaryText, on: background, dark: dark) >= 4.5)
            }
        }
    }

    @Test func theRedTextPassesAAWhereRaderaKontoStands() {
        for dark in [false, true] {
            #expect(contrast(LumenColor.redText, on: .secondarySystemGroupedBackground, dark: dark) >= 4.5)
        }
    }

    @Test func thePlaceholdersOnTheSayCardPassAA() {
        // The placeholder is the card's text colour at `promptOpacity` over the card.
        let ink = UIColor(SayText.ink), card = UIColor(SayText.field)
        var ir: CGFloat = 0, ig: CGFloat = 0, ib: CGFloat = 0, cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, alpha: CGFloat = 0
        ink.getRed(&ir, green: &ig, blue: &ib, alpha: &alpha)
        card.getRed(&cr, green: &cg, blue: &cb, alpha: &alpha)
        let o = CGFloat(SayText.promptOpacity)
        let mixed = UIColor(red: ir * o + cr * (1 - o), green: ig * o + cg * (1 - o), blue: ib * o + cb * (1 - o), alpha: 1)
        let a = luminance(mixed), b = luminance(card)
        #expect((max(a, b) + 0.05) / (min(a, b) + 0.05) >= 4.5)
    }
}
