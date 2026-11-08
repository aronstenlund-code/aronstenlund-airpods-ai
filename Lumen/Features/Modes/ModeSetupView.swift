import SwiftUI
import UniformTypeIdentifiers

/// D86 (A2): the modes' start screens in the new design: the mode's round colour, a short text, fields and one
/// clear start button.
private struct ModeHeader: View {
    let mode: ConversationMode
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: mode.symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LumenColor.background)
                .frame(width: 56, height: 56)
                .background(mode.color, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(LumenFont.text(30, .bold, relativeTo: .largeTitle))
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(LumenFont.text(16))
                .foregroundStyle(LumenColor.muted)
        }
    }
}

private struct FieldLabel: View {
    let text: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(LumenFont.text(16, .semibold)).accessibilityAddTraits(.isHeader)
            if let detail { Text(detail).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted) }
        }
    }
}

/// Start screen for Intervjuläge: the role or job ad, the CV (D81), practice or preparation.
struct InterviewSetupView: View {
    @Bindable var model: ListeningModel
    @Bindable var settings: ModeSettings
    @Environment(\.dismiss) private var dismiss
    @State private var isPickingCV = false
    @State private var cvNotice: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ModeHeader(mode: .interview, title: "Intervjuläge",
                           text: "Till för träning: en kompis ställer frågan och du hör ett färdigt svar. Använd det inte i en riktig intervju utan att den andra vet om det.")
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Roll eller jobbannons")
                    TextField("Klistra in annonsen eller skriv rollen", text: $settings.interviewSetup, axis: .vertical)
                        .lineLimit(4...10)
                        .textFieldStyle(LumenFieldStyle())
                        .accessibilityLabel("Roll eller jobbannons")
                }
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "CV", detail: "Läses på telefonen och sparas bara här. Högst 2 000 tecken skickas, utan e-post, telefonnummer, personnummer och adress.")
                    if settings.interviewCV.isEmpty {
                        Button("Lägg till CV (PDF eller text)") { isPickingCV = true }
                            .buttonStyle(LumenButtonStyle(kind: .secondary, height: 48))
                    } else {
                        Text(settings.interviewCVName.isEmpty ? "CV inläst" : settings.interviewCVName)
                            .font(LumenFont.text(16, .medium))
                        HStack(spacing: 10) {
                            Button("Byt CV") { isPickingCV = true }
                                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 44))
                            Button("Ta bort CV") {
                                settings.interviewCV = ""
                                settings.interviewCVName = ""
                            }
                            .buttonStyle(LumenButtonStyle(kind: .secondary, height: 44))
                        }
                    }
                    if let cvNotice { Text(cvNotice).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button("Starta övningsintervju") {
                    dismiss()
                    Task { await model.startHandsFree(.interview) }
                }
                .buttonStyle(LumenButtonStyle())
                Button("Förbered frågor och svar") {
                    dismiss()
                    model.prepareInterview()
                }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 48))
            }
            .disabled(!settings.hasInterviewSetup)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(LumenColor.background)
        }
        .lumenScreen()
        .fileImporter(isPresented: $isPickingCV, allowedContentTypes: [.pdf, .plainText, .text]) { result in
            guard case .success(let url) = result else { return }
            if let text = InterviewProfile.text(from: url) {
                settings.interviewCV = text
                settings.interviewCVName = url.lastPathComponent
                cvNotice = "\(text.count) tecken inlästa."
            } else {
                cvNotice = "Ingen text hittades i filen (en inskannad PDF går inte att läsa). Klistra in texten i stället."
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Rizzläge is for adults (D63): asked the first time, remembered on this phone.
struct AgeGateView: View {
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModeHeader(mode: .rizz, title: "Rizz är för 18 år och äldre",
                       text: "Frågan ställs en gång och sparas bara på den här telefonen.")
            Spacer(minLength: 8)
            Button("Jag är 18 år eller äldre") { onAnswer(true) }
                .buttonStyle(LumenButtonStyle())
            Button("Avbryt") { onAnswer(false) }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 48))
        }
        .padding(24)
        .lumenScreen()
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

/// Start screen for the live modes (D42/D43/D63): consent first, then what the suggestions may build on.
struct LiveStartView: View {
    @Bindable var model: ListeningModel
    @Bindable var settings: ModeSettings
    let mode: ConversationMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ModeHeader(mode: mode, title: mode == .rizz ? "Rizzläge" : "Socialt läge",
                           text: "Prova med en kompis och berätta att appen lyssnar. Det ni båda säger går till ElevenLabs och Anthropic för att göra förslag. Orden glöms när sessionen slutar.")
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Om dig", detail: "Valfritt. Förslagen kan bygga på det.")
                    TextField("Intressen, med komma emellan", text: $settings.rizzInterests)
                        .textFieldStyle(LumenFieldStyle())
                        .accessibilityLabel("Intressen")
                    TextField("Profil eller bio", text: $settings.rizzProfile, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(LumenFieldStyle())
                        .accessibilityLabel("Profil eller bio")
                }
                Text("Ett förslag visas på låsskärmen och läses upp i en paus. Säg ”nästa” för ett nytt, ”\(WakeWord.name), mer skämt” för att styra tonen och ”\(WakeWord.name), ge mig tre” för fler.")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            Button("De vet att appen lyssnar. Starta") {
                settings.confirmLiveStart(mode)
                dismiss()
                Task { await model.startHandsFree(mode) }
            }
            .buttonStyle(LumenButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(LumenColor.background)
        }
        .lumenScreen()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
