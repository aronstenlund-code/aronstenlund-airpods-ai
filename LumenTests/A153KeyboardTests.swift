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
