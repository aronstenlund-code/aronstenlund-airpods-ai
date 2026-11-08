import SwiftUI
import UniformTypeIdentifiers

/// Start screen for Intervjuläge: the role or job ad, the CV (D81), practice or preparation.
struct InterviewSetupView: View {
    @Bindable var model: ListeningModel
    @Bindable var settings: ModeSettings
    @Environment(\.dismiss) private var dismiss
    @State private var isPickingCV = false
    @State private var cvNotice: String?

    var body: some View {
        Form {
            Section("Role or job ad") {
                TextEditor(text: $settings.interviewSetup)
                    .frame(minHeight: 140)
            }
            Section {
                if settings.interviewCV.isEmpty {
                    Button("Lägg till CV (PDF eller text)") { isPickingCV = true }
                } else {
                    LabeledContent("CV", value: settings.interviewCVName.isEmpty ? "Inläst" : settings.interviewCVName)
                    Button("Byt CV") { isPickingCV = true }
                    Button("Ta bort CV", role: .destructive) {
                        settings.interviewCV = ""
                        settings.interviewCVName = ""
                    }
                }
                if let cvNotice { Text(cvNotice).font(.footnote).foregroundStyle(.secondary) }
            } header: {
                Text("CV")
            } footer: {
                Text("CV:t läses på telefonen och sparas bara här. Med varje intervjufråga skickas en kort sammanfattning av jobbannonsen och CV:t, högst 2 000 tecken, utan e-post, telefonnummer, personnummer och adress.")
            }
            Section {
                Button("Start practice interview") {
                    dismiss()
                    Task { await model.startHandsFree(.interview) }
                }
                Button("Prepare questions and answers") {
                    dismiss()
                    model.prepareInterview()
                }
            } footer: {
                Text("Intervjuläge är till för träning: en kompis ställer frågan och du hör ett färdigt svar. Använd det inte i en riktig intervju utan att den andra vet om det.")
            }
            .disabled(!settings.hasInterviewSetup)
        }
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
        .navigationTitle("Intervjuläge")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Rizzläge is for adults (D63): asked the first time, remembered on this phone.
struct AgeGateView: View {
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rizzläge is only for people aged 18 or older")
                .font(.title2.bold())
            Spacer()
            Button {
                onAnswer(true)
            } label: {
                Text("I am 18 or older").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            Button {
                onAnswer(false)
            } label: {
                Text("Cancel").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
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
        Form {
            Section {
                Label("Try it with a friend", systemImage: "person.2.fill")
                    .font(.headline)
                Text("Tell them the app is listening. What you both say goes to ElevenLabs and Anthropic to create suggestions. The words are forgotten when the session ends.")
                    .font(.subheadline)
            }
            Section("About you") {
                TextField("Interests, separated by commas", text: $settings.rizzInterests)
                TextField("Profile or bio", text: $settings.rizzProfile, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section {
                Button("They know the app is listening. Start") {
                    settings.confirmLiveStart(mode)
                    dismiss()
                    Task { await model.startHandsFree(mode) }
                }
                .font(.headline)
            } footer: {
                Text("Ett förslag visas på låsskärmen och läses upp i en paus. Säg \"nästa\" för ett nytt, \"\(WakeWord.name), mer skämt\" för att styra tonen och \"\(WakeWord.name), ge mig tre\" för fler.")
            }
        }
        .navigationTitle(mode == .rizz ? "Rizzläge" : "Socialt läge")
        .navigationBarTitleDisplayMode(.inline)
    }
}
