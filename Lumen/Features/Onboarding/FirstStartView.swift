import SwiftUI
import UIKit

/// D86 screen 1: the first start, an answer within 30 s. Intro with the short consent card (A2, approved by the
/// Architect: listens only when started, always visible, no audio saved, "Läs mer" for the full text) → iOS asks for the
/// microphone → "Fråga vad som helst", where the first question is answered → "Lägg till prov" (optional).
struct FirstStartView: View {
    enum Step { case intro, consent, firstQuestion, addExam }

    let container: AppContainer
    let onDone: () -> Void
    @State private var step: Step = .intro
    @State private var microphoneDenied = false

    static let doneKey = "design.firstStartDone"

    var body: some View {
        Group {
            switch step {
            case .intro:
                IntroView {
                    // "Testa nu" under the consent card is the consent (the card's three points, "Läs mer" for all).
                    if !container.consent.isGranted { container.consent.grant() }
                    step = .firstQuestion
                }
            case .consent:
                ConsentView(mode: .onboarding {
                    container.consent.grant()
                    step = .firstQuestion
                })
            case .firstQuestion:
                FirstQuestionView(model: container.listening, microphoneDenied: microphoneDenied) {
                    step = .addExam
                }
                .task { await startListening() }
            case .addExam:
                AddExamStep(model: container.listening, onDone: finish)
            }
        }
        .lumenScreen()
        .animation(.default, value: step)
    }

    /// iOS asks for the microphone right here (the session start asks), then Lumen listens in Frågor.
    private func startListening() async {
        guard !container.listening.isListening else { return }
        let granted = await container.session.requestMicrophonePermission()
        microphoneDenied = !granted
        guard granted else { return }
        await container.listening.startListening()
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.doneKey)
        onDone()
    }
}

/// "Fråga högt. Få svaret i örat."
struct IntroView: View {
    let onStart: () -> Void
    @State private var isReadingMore = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The photo (a student with AirPods at a desk with a squared notebook, phone out of sight) needs a
                // freely licensed picture; until then the squared paper and the listening rings stand in for it.
                if !typeSize.isAccessibilitySize { // A12: the picture gives way to the text at the largest sizes
                    IntroHeroView() // A13.6: Elias and the rings (a placeholder until the picture is approved)
                        .containerRelativeFrame(.vertical) { height, _ in min(300, height * 0.3) } // smaller on the SE
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        LumenLogo(size: 24)
                        Text("Lumen").font(LumenFont.text(20, .bold, relativeTo: .title3))
                    }
                    Text("Fråga högt. Få svaret i örat.")
                        .font(LumenFont.text(40, .bold, relativeTo: .largeTitle))
                        .lineSpacing(-4)
                        .accessibilityAddTraits(.isHeader)
                    Text("Telefonen stannar i fickan. Lumen pluggar med dig på din nivå, och du styr allt med rösten.")
                        .font(LumenFont.text(18, relativeTo: .body))
                        .foregroundStyle(LumenColor.muted)
                    consentCard
                }
                .padding(.horizontal, 24)
                .padding(.top, typeSize.isAccessibilitySize ? 64 : 28)
                .padding(.bottom, 28) // "Läs mer" stays clear of the bar
            }
        }
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
                // A12: what the user agrees to sits at the button, so it is on screen when they press it, on every
                // iPhone and text size (the card above can scroll away on the SE).
                Text("Genom att trycka Testa nu godkänner du att Lumen lyssnar bara när du har startat den, att du alltid ser när den lyssnar och att ljud inte sparas. Inget konto.")
                    .font(LumenFont.text(14, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(LumenColor.background)
        }
        .ignoresSafeArea(edges: .top)
    }
}

extension IntroView {
    /// A2: the short consent, three points and "Läs mer".
    var consentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            point("mic", "Lumen lyssnar bara när du har startat den.")
            point("eye", "Du ser alltid när den lyssnar.")
            point("waveform.slash", "Ljud sparas inte.")
            Button("Läs mer") { isReadingMore = true }
                .font(LumenFont.text(15, .semibold))
                .frame(minHeight: 44)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LumenColor.chip, in: RoundedRectangle(cornerRadius: 10))
        .padding(.top, 8)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(LumenColor.blue).frame(width: 22).accessibilityHidden(true)
            Text(text).font(LumenFont.text(16, .medium))
        }
    }
}

/// "Fråga vad som helst": the first question gets its answer here.
struct FirstQuestionView: View {
    @Bindable var model: ListeningModel
    let microphoneDenied: Bool
    let onContinue: () -> Void
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
                Text("iOS frågar om mikrofonen första gången. Lumen sparar aldrig ljud.")
                    .font(LumenFont.text(14, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(LumenColor.background)
        }
    }

    private var hasAnswer: Bool {
        model.conversation.answers.contains { !$0.answer.isEmpty }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ListeningRings(size: 40, active: model.isListening)
                Text(model.isListening ? "Lyssnar" : "Startar …").font(LumenFont.text(17, .semibold))
                Spacer(minLength: 0)
                LevelMeter(levelDBFS: model.isListening && model.isHearing ? model.controller.level.rmsDBFS : nil)
            }
            .accessibilityElement(children: .combine)
            if let turn = model.conversation.streamingAnswer ?? model.conversation.answers.last {
                Text(turn.question).font(appearance.questionFont(22)).foregroundStyle(LumenColor.blue)
                if !turn.answer.isEmpty {
                    Text(turn.answer).font(LumenFont.text(19, .medium))
                }
            } else {
                Text("Vad är fotosyntes?").font(appearance.questionFont(22)).foregroundStyle(LumenColor.blue.opacity(0.5))
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
