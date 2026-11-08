import SwiftUI

/// D81: "Lär dig min röst", the speaker labels, and deleting the profile. The profile stays on this phone.
struct VoiceProfileSection: View {
    @Bindable var model: ListeningModel
    @Bindable var speakers: SpeakerIdentifier
    @State private var isEnrolling = false
    @State private var secondsLeft = 0
    @State private var notice: String?
    @State private var isConfirmingDelete = false

    static let readingText = "Hej Lumen. Det här är min röst. Jag läser den här texten i lugn takt så att du kan känna igen mig. Solen gick upp över sjön, och fåglarna började sjunga i träden. Nu vet du hur jag låter."

    var body: some View {
        Section {
            if isEnrolling {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Läs högt i vanlig samtalsröst (\(secondsLeft) s kvar):")
                        .font(.footnote.weight(.semibold))
                    Text(Self.readingText)
                        .font(.body)
                    ProgressView(value: Double(Int(ListeningModel.enrollSeconds) - secondsLeft), total: ListeningModel.enrollSeconds)
                }
            } else if let profile = speakers.profiles.profile {
                LabeledContent("Röstprofil", value: profile.createdAt.formatted(date: .abbreviated, time: .shortened))
                Button("Lär dig min röst igen") { Task { await enroll() } }
                Button("Radera röstprofilen", role: .destructive) { isConfirmingDelete = true }
            } else {
                Button("Lär dig min röst (10 s)") { Task { await enroll() } }
                    .disabled(!model.consent.isGranted)
            }
            Toggle("Visa vem som pratar (Du / Talare 1, 2)", isOn: $speakers.showsLabels)
            if case .loading = speakers.loader.status {
                Text("Röstmodellen laddas ner (en gång, cirka 30 MB).").font(.footnote).foregroundStyle(.secondary)
            } else if case .unavailable(let why) = speakers.loader.status {
                Text("Röstmodellen kunde inte laddas: \(why). Lumen använder ljudnivån i stället.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
        } header: {
            Text("Din röst")
        } footer: {
            Text("Röstprofilen är ett tal-avtryck av din röst, inte en inspelning. Den sparas bara på den här telefonen (inte i iCloud) och skickas aldrig. Med den svarar Auto inte på dina egna ord, Intervjuläge svarar bara intervjuaren, Rizzläge vet vem som pratar, minnet sparar bara det du själv sa, och bara din röst kan avbryta Lumen. Utan profil avgör ljudnivån som förut. Talare 1, 2 … är bara en etikett för sessionen; ingen identifieras.

Röstmodell: WeSpeaker (CC BY 4.0) via pyannote, och pyannote segmentation-3.0 (MIT, © 2023 CNRS), ändrade Core ML-konverteringar av Fluid Inference.")
        }
        .confirmationDialog("Radera röstprofilen?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Radera", role: .destructive) {
                model.deleteVoiceProfile()
                notice = "Röstprofilen är raderad."
            }
        }
    }

    private func enroll() async {
        notice = nil
        isEnrolling = true
        secondsLeft = Int(ListeningModel.enrollSeconds)
        let countdown = Task { @MainActor in
            while secondsLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                secondsLeft -= 1
            }
        }
        let result = await model.enrollVoice()
        countdown.cancel()
        isEnrolling = false
        switch result {
        case .saved(let seconds)?: notice = "Sparad (\(Int(seconds)) s tal). Lumen känner igen din röst nu."
        case .tooLittleSpeech?: notice = "För lite tal hördes. Försök igen och läs hela texten högt."
        case .modelsUnavailable?: notice = "Röstmodellen kunde inte laddas. Försök igen med internet."
        case nil: notice = "Mikrofonen kunde inte starta."
        }
    }
}

/// D81: the study cards, with the exam they belong to. Deleted one by one or all at once.
struct StudyCardsView: View {
    @Bindable var store: StudyCardStore

    var body: some View {
        List {
            let cards = store.current()
            if cards.isEmpty {
                Text("Inga studiekort än. Frågorna du ställer i Provläge blir kort, med svaret i korthet, fram till provet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.question).font(.subheadline.weight(.semibold))
                    Text(card.answer).font(.footnote)
                    HStack {
                        if let subject = card.subject { Text(subject) }
                        if let exam = card.examDate { Text("prov \(exam.formatted(date: .abbreviated, time: .omitted))") }
                        if card.right + card.wrong > 0 { Text("\(card.right) rätt · \(card.wrong) fel") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                for index in offsets { store.delete(cards[index].id) }
            }
            if !cards.isEmpty {
                Button("Radera alla studiekort", role: .destructive) { store.deleteAll() }
            }
        }
        .navigationTitle("Studiekort")
        .navigationBarTitleDisplayMode(.inline)
    }
}
