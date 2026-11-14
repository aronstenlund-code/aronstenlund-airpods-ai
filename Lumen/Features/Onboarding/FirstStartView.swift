import SwiftUI
import UIKit

/// A94 (Kelly Ke55, `docs/design/forsta-starten.md`): from the download to the first question in the ear, at most
/// three screens before the camera. Välkommen (the repetition mode's consent: material is sent once to make the
/// questions and the sound) → Nytt prov, where Fota sidor opens the document camera. Nothing here listens: the modes
/// that listen are BETA under Fler lägen and ask for the listening consent (`ConsentView`) and the microphone the
/// first time one is started. Fortsätt never grants the listening consent (CLAUDE.md guardrails).
struct FirstStartView: View {
    enum Step { case welcome, newDrill }

    let container: AppContainer
    /// Finished the old first start: only Välkommen, once (Ke55's consent point 3), then Start.
    var returning = false
    let onDone: () -> Void
    @State private var step: Step = .welcome

    static let doneKey = "design.firstStartDone"

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeView {
                    container.consent.grantWelcome()
                    if returning || container.listening.repetition == nil { finish() } else { step = .newDrill }
                }
            case .newDrill:
                if let repetition = container.listening.repetition {
                    NewDrillView(model: repetition, onLater: { finish() }) { drill in
                        repetition.openDrill = drill.id // Start opens the new exam's question list
                        finish()
                    }
                }
            }
        }
        .animation(.default, value: step)
    }

    /// Start, with nothing listening. The opening's sheets are done (A66).
    private func finish() {
        container.listening.openingSheetShown = true
        UserDefaults.standard.set(true, forKey: Self.doneKey)
        onDone()
    }
}

/// "Fråga högt. Få svaret i örat."
/// A26 (Kelly R2, `docs/design/bilder/system/intro.png`): one sentence under the title and the three promises as a calm
/// list, so all three and "Läs mer" are above "Testa nu" on the SE too (the protections must be seen, GRANSKNING 9).
struct IntroView: View {
    let onStart: () -> Void
    @State private var isReadingMore = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !typeSize.isAccessibilitySize { // A12: the picture gives way to the text at the largest sizes
                    IntroHeroView() // A13.6: Elias and the rings
                        .containerRelativeFrame(.vertical) { height, _ in Self.heroHeight(for: height) }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        AppMark(size: 26) // A71 (Ke40)
                        Text("EarMind").font(LumenFont.text(18, .bold, relativeTo: .title3))
                    }
                    Text("Fråga högt. Få svaret i örat.")
                        .font(LumenFont.text(34, .bold, relativeTo: .largeTitle))
                        .lineSpacing(-3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Telefonen stannar i fickan.")
                        .font(LumenFont.text(18, relativeTo: .body))
                        .foregroundStyle(LumenColor.muted)
                    promises
                }
                .padding(.horizontal, 24)
                .padding(.top, typeSize.isAccessibilitySize ? 24 : 18)
                .padding(.bottom, 12)
            }
        }
        .background(LumenColor.background) // A26 R3: the whole screen is `background`, also behind the scroll view
        .sheet(isPresented: $isReadingMore) {
            NavigationStack {
                ConsentView(mode: .readMore)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Klar") { isReadingMore = false } } }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button("Testa nu", action: onStart)
                    .buttonStyle(LumenButtonStyle())
                    .accessibilityHint("Godkänner punkterna ovan och startar mikrofonen")
                // A12: what the user agrees to sits at the button. A26: the points are above it on every iPhone now,
                // so the line names them instead of repeating them (Kelly's intro.png).
                Text("Inget konto. Testa nu betyder att du godkänner punkterna ovan.")
                    .font(LumenFont.text(14, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(LumenColor.background)
        }
    }

    /// The hero's height from the visible height: smaller on the SE so the three promises stay above the button.
    nonisolated static func heroHeight(for visible: CGFloat) -> CGFloat {
        visible < 600 ? visible * 0.34 : min(320, visible * 0.42)
    }
}

extension IntroView {
    /// A2's short consent: three points and "Läs mer" (A26: a list, not a card).
    var promises: some View {
        VStack(alignment: .leading, spacing: 4) {
            point("mic", "Lyssnar bara när du har startat den")
            point("eye", "Du ser alltid när den lyssnar")
            point("waveform.slash", "Ljudet blir text och sparas inte av EarMind. Sömnläget sparar klippen bara på din telefon.") // A73 (D138)
            // A41 (D116): what is sent for analysis is part of what "Testa nu" agrees to.
            point("paperplane", "Frågor och svar skickas till oss")
            Button("Läs mer") { isReadingMore = true } // the word Toby's screen tour looks for
                .font(LumenFont.text(16, .semibold))
                .foregroundStyle(LumenColor.blue)
                .frame(minHeight: 44)
                .padding(.leading, 32)
        }
        .padding(.top, 6)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            icon(symbol)
            Text(text).font(LumenFont.text(16, .medium))
        }
        .frame(minHeight: 30)
    }

    private func icon(_ symbol: String) -> some View {
        Image(systemName: symbol).foregroundStyle(LumenColor.muted).frame(width: 22).accessibilityHidden(true)
    }
}

/// "Fråga vad som helst": the first question gets its answer here.
struct FirstQuestionView: View {
    @Bindable var model: ListeningModel
    let microphoneDenied: Bool
    var starting = false
    /// A26 R4: "Lyssna igen" when the microphone is not on (it says "Pausad" then, never "Startar …" for ever).
    var onListen: () -> Void = {}
    let onContinue: () -> Void
    /// A33 (D109): after the first answer has been spoken, the first start goes on by itself to "Har du prov snart?",
    /// which Lumen asks aloud.
    @State private var advanced = false
    @Environment(AppearanceSettings.self) private var appearance

    var body: some View {
        if microphoneDenied {
            MicrophoneDeniedView(onSkip: onContinue) // A18 (Kelly Ke10): the whole screen fixes the microphone
        } else {
            questionScreen
        }
    }

    private var questionScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Fråga vad som helst")
                        .font(LumenFont.text(36, .bold, relativeTo: .largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    Text("Sätt i AirPods och säg en fråga högt. Utan AirPods hörs svaret i telefonen.")
                        .font(LumenFont.text(17))
                        .foregroundStyle(LumenColor.muted)
                }
                .padding(.horizontal, 4)

                card

            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(LumenColor.background) // A26 R3
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                // A18 (Kelly Ke9): no blue button before the first answer, so the question is the obvious thing to do.
                if hasAnswer {
                    Button("Fortsätt", action: onContinue)
                        .buttonStyle(LumenButtonStyle())
                        .transition(.opacity)
                } else {
                    Button("Hoppa över", action: onContinue)
                        .font(LumenFont.text(17, .semibold))
                        .foregroundStyle(LumenColor.muted)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                Text("iOS frågar om mikrofonen första gången. Ljudet blir text och sparas inte av EarMind. Sömnläget sparar klippen bara på din telefon.") // A73 (D138) // A30 (Kelly Ke20): the intro's words
                    .font(LumenFont.text(14, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(LumenColor.background)
        }
        .onChange(of: model.speaker.status) { _, status in
            guard status == .idle, hasAnswer, !advanced, model.conversation.streamingAnswer == nil else { return }
            advanced = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                guard model.conversation.streamingAnswer == nil, !model.speaker.isSpeaking else {
                    advanced = false // a second question came: wait for its answer
                    return
                }
                onContinue()
            }
        }
    }

    private var isPaused: Bool { !model.isListening && !starting && !model.isStarting }

    /// A26 R4 (Kelly): the badge says what is true.
    private var badgeTitle: String {
        if model.isListening { return "Lyssnar" }
        return isPaused ? "Pausad" : "Startar …"
    }

    private var hasAnswer: Bool {
        model.conversation.answers.contains { !$0.answer.isEmpty }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                StatusBadge(title: badgeTitle, active: model.isListening,
                            levelDBFS: model.isListening && model.isHearing ? model.controller.level.rmsDBFS : nil)
                Spacer(minLength: 8)
                if isPaused {
                    Button("Lyssna igen", action: onListen)
                        .font(LumenFont.text(15, .semibold))
                        .foregroundStyle(LumenColor.blue)
                        .frame(minHeight: 44)
                }
            }
            if let turn = model.conversation.streamingAnswer ?? model.conversation.answers.last {
                Text(turn.question).font(appearance.questionFont(22)).foregroundStyle(LumenColor.muted)
                if !turn.answer.isEmpty {
                    Text(turn.answer).font(LumenFont.text(20)).lineSpacing(5)
                }
            } else {
                Text("Säg till exempel: ”Vad är fotosyntes?”").font(LumenFont.text(17)).foregroundStyle(LumenColor.muted)
                    .accessibilityLabel("Till exempel: Vad är fotosyntes?")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .gridPaper()
        .animation(.easeOut(duration: 0.2), value: hasAnswer)
    }
}

/// The last first-start step: add an exam, or skip.
struct AddExamStep: View {
    @Bindable var model: ListeningModel
    let onDone: () -> Void

    var body: some View {
        AddExamView(model: model, isFirstStart: true, onClose: onDone)
    }
}
