import Foundation
import Testing
import UIKit
@testable import Lumen

/// A153 (D238, Toby T53): at the largest text Spela ended up behind the keyboard. When the card's own Spela cannot
/// be pressed, Spela stands in the row above the keyboard; when it can, that row has only "Klar". Numbers only: no
/// keyboard, no sound, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A153KeyboardTests {
    // Toby's run 44449376221 (iPhone 17 Pro, the largest text): the button at y 670–714 of 874.
    private let tobysButton: ClosedRange<CGFloat> = 670...714

    @Test func withoutAKeyboardNothingIsHidden() {
        #expect(!SayKeyboard.hidesPlay(button: tobysButton, keyboardTop: nil))
        #expect(!SayKeyboard.hidesPlay(button: nil, keyboardTop: nil))
    }

    @Test func aButtonBehindTheKeyboardIsHidden() {
        #expect(SayKeyboard.hidesPlay(button: tobysButton, keyboardTop: 490), "wholly behind the keys")
        #expect(SayKeyboard.hidesPlay(button: tobysButton, keyboardTop: 700), "half a button is not one to press")
        #expect(SayKeyboard.hidesPlay(button: tobysButton, keyboardTop: 716), "it must clear the row by a few points")
    }

    @Test func aButtonAboveTheKeyboardIsNotHidden() {
        #expect(!SayKeyboard.hidesPlay(button: 300...344, keyboardTop: 490))
        #expect(!SayKeyboard.hidesPlay(button: tobysButton, keyboardTop: 714 + SayKeyboard.margin))
    }

    @Test func aButtonScrolledAwayAboveIsHidden() {
        #expect(SayKeyboard.hidesPlay(button: -60 ... -16, keyboardTop: 490))
    }

    @Test func aButtonThatIsNotMeasuredCountsAsHidden() {
        #expect(SayKeyboard.hidesPlay(button: nil, keyboardTop: 490), "Spela above the keyboard rather than nowhere")
    }

    @Test func theKeyboardsTopIsReadFromTheSystemsNotice() {
        let up = Notification(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                              userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: 490, width: 402, height: 384)])
        #expect(SayKeyboard.top(from: up) == 490)
        // Gone: the keyboard begins at the bottom edge of the screen, below every button.
        let away = Notification(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                                userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: 874, width: 402, height: 384)])
        #expect(SayKeyboard.top(from: away) == 874)
        #expect(!SayKeyboard.hidesPlay(button: tobysButton, keyboardTop: SayKeyboard.top(from: away)))
        let hiding = Notification(name: UIResponder.keyboardWillHideNotification, object: nil,
                                  userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: 490, width: 402, height: 384)])
        #expect(SayKeyboard.top(from: hiding) == nil, "on its way down")
        #expect(SayKeyboard.top(from: Notification(name: UIResponder.keyboardWillChangeFrameNotification)) == nil)
    }

    @Test func theRowSaysTheCostAndIsShorterOnANarrowScreen() {
        // Kelly (2026-11-19): the cost stands in the row above the keyboard.
        #expect(SayKeyboard.costWords("120 krediter", narrow: false) == "120 krediter")
        #expect(SayKeyboard.costWords("120 krediter · du har 88", narrow: false) == "120 krediter · du har 88")
        #expect(SayKeyboard.costWords("120 krediter · du har 88", narrow: true) == "120 krediter")
        #expect(SayKeyboard.costWords("Ingår", narrow: true) == "Ingår")
        #expect(SayKeyboard.playWords("Spela i 10 min", narrow: false, withCost: true) == "Spela i 10 min")
        #expect(SayKeyboard.playWords("Spela i 10 min", narrow: true, withCost: false) == "Spela i 10 min")
        #expect(SayKeyboard.playWords("Spela i 10 min", narrow: true, withCost: true) == "Spela")
        #expect(SayKeyboard.narrowCard < SayKeyboard.widthForAllSuggestions)
    }

    @Test func theStripUnderTheRowReachesFromTheRowsTopToTheContentsEnd() {
        // iPhone 17 Pro, iOS 26 (the pictures of 2026-11-19): the row begins at 491, the content ends at 525.
        #expect(SayKeyboard.stripHeight(bottom: 525, keyboardTop: 491) == 34)
        #expect(SayKeyboard.stripHeight(bottom: nil, keyboardTop: 491) == 34, "a guess until it is measured")
        #expect(SayKeyboard.stripHeight(bottom: 525, keyboardTop: nil) == 34)
        #expect(SayKeyboard.stripHeight(bottom: 525, keyboardTop: 874) == 0, "the keyboard has gone: no strip")
        #expect(SayKeyboard.stripHeight(bottom: 525, keyboardTop: 200) == 72, "never more than a row and a half")
    }

    @Test func theViewsGeometryAnswersFromBoth() {
        let geometry = SayKeyboard.Geometry()
        #expect(!geometry.hidesPlay, "no keyboard yet")
        geometry.keyboardTop = 490
        #expect(geometry.hidesPlay, "a keyboard, and the button not measured")
        geometry.button = 300...344
        #expect(!geometry.hidesPlay)
        geometry.button = tobysButton
        #expect(geometry.hidesPlay)
        geometry.keyboardTop = nil
        #expect(!geometry.hidesPlay)
    }
}
