import SwiftUI
import UIKit

/// D86 screen 1: the first start, an answer within 30 s. Intro → consent (the documented guardrail, kept) → iOS asks
/// for the microphone → "Fråga vad som helst", where the first question is answered → "Lägg till prov" (optional).
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
                    step = container.consent.isGranted ? .firstQuestion : .consent
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The photo (a student with AirPods at a desk with a squared notebook, phone out of sight) needs a
                // freely licensed picture; until then the squared paper and the listening rings stand in for it.
                ZStack {
                    GridPaper(cornerRadius: 0)
                    VStack(spacing: 14) {
                        ListeningRings(size: 96)
                        Image(systemName: "airpods")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(LumenColor.muted)
                    }
                }
                .frame(height: 300)
                .accessibilityHidden(true)

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
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button("Testa nu", action: onStart)
                    .buttonStyle(LumenButtonStyle())
                Text("Inget konto. Du ställer din första fråga direkt.")
                    .font(LumenFont.text(14, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(LumenColor.background)
        }
        .ignoresSafeArea(edges: .top)
    }
}

/// "Fråga vad som helst": the first question gets its answer here.
struct FirstQuestionView: View {
    @Bindable var model: ListeningModel
    let microphoneDenied: Bool
    let onContinue: () -> Void
    @Environment(AppearanceSettings.self) private var appearance

    var body: some View {
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

                if microphoneDenied {
                    ErrorCard(problem: .microphoneDenied) { ErrorCard.openSettings() }
                } else {
                    card
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Prova också").font(LumenFont.text(15)).foregroundStyle(LumenColor.muted)
                    Text("Vad är 270 gånger 270?").font(appearance.questionFont(20)).foregroundStyle(LumenColor.blue)
                    Text("Hur böjer man ”att vara” på spanska?").font(appearance.questionFont(20)).foregroundStyle(LumenColor.blue)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button("Fortsätt", action: onContinue)
                    .buttonStyle(LumenButtonStyle())
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

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ListeningRings(size: 40, active: model.isListening)
                Text(model.isListening ? "Lyssnar" : "Startar …").font(LumenFont.text(17, .semibold))
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
