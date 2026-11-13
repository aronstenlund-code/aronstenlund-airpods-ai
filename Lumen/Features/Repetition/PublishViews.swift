import SwiftUI

// A83 (D149, D150, Kelly Ke52): Publicera prov, Välj skola, Prov från din skola, Rapportera. System components
// (Form, List, .searchable, .sheet), so A87's Apple style needs little here. The word "övningsprov" is never used.

/// Ke52 "Publicera prov" (the sheet): what is published and what never is, Skola, Ämne, Provdatum, the user-name
/// switch (off), and what is missing above the button.
struct PublishSheet: View {
    let model: RepetitionModel
    let drill: Drill
    @Environment(\.dismiss) private var dismiss
    @State private var school: DrillSchool?
    @State private var subject: String?
    @State private var date: Date?
    @State private var showsName = false
    @State private var name = ""
    @State private var choosingSchool = false
    @State private var isSending = false
    @State private var problem: String?
    @State private var loaded = false

    private var isUpdate: Bool { drill.publication != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Alla som söker på skolan kan lägga till provet och plugga på det. **Frågor, svar och ljud** publiceras. Aldrig foton, dokument eller ditt namn.")
                        .font(.subheadline)
                }
                Section {
                    Button { choosingSchool = true } label: {
                        LabeledContent("Skola", value: school?.name ?? "Välj skola")
                    }
                    .foregroundStyle(.primary)
                    Picker("Ämne", selection: $subject) {
                        Text("Välj ämne").tag(String?.none)
                        ForEach(DrillPublishing.subjects, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    if let date {
                        DatePicker("Provdatum", selection: Binding(get: { date }, set: { self.date = $0 }),
                                   in: DrillPublishing.dateRange(), displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "sv_SE"))
                    } else {
                        Button { date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) } label: {
                            LabeledContent("Provdatum", value: "Välj datum")
                        }
                        .foregroundStyle(.primary)
                    }
                }
                Section {
                    Toggle("Visa ett användarnamn", isOn: $showsName)
                    if showsName {
                        TextField("Användarnamn", text: $name)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    Text(showsName ? "Syns för alla som hittar provet. Skriv inte ditt riktiga namn." : "Av: provet visas utan namn.")
                }
                Section {
                    if let line = missingLine {
                        Text(line).foregroundStyle(.secondary)
                    }
                    if let problem { Text(problem) }
                    Button {
                        send()
                    } label: {
                        Text(isSending ? "Publicerar …" : isUpdate ? "Spara ändringarna" : "Publicera prov")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(missingLine != nil || isSending)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Publicera prov")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } } }
            .sheet(isPresented: $choosingSchool) {
                SchoolPicker(model: model, title: "Välj skola", selected: school) { picked in
                    school = picked
                    choosingSchool = false
                }
            }
            .onAppear(perform: load)
        }
    }

    /// Ke52: "Saknas: skola, ämne, provdatum", or the sound that is not ready.
    private var missingLine: String? {
        if let fields = DrillPublishing.missing(school: school, subject: subject, date: date) { return fields }
        let p = model.progress(drill)
        if p.total == 0 || p.ready < p.total { return "Publiceras när ljudet är klart (\(p.ready) av \(p.total))." }
        return nil
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let p = drill.publication {
            school = p.school
            subject = p.subject
            date = p.examDate
            showsName = p.displayName != nil
            name = p.displayName ?? ""
        } else {
            school = model.mySchool
            subject = DrillPublishing.subject(from: drill.summary.subject)
            name = model.lastDisplayName // the suggestion; the switch stays off (Ke52)
        }
    }

    private func send() {
        guard let school, let subject, let date else { return }
        isSending = true
        problem = nil
        let shownName = showsName ? name : nil
        Task {
            do throws(DrillCloudError) {
                try await model.publish(drill, school: school, subject: subject, examDate: date, displayName: shownName)
                model.importMessage = "Publicerat."
                dismiss()
            } catch {
                if case .offline = error {
                    problem = "Ingen internetanslutning. Försök igen när du är uppkopplad."
                } else if case .refused(let status, _, let message) = error, status == 409 || status == 400 {
                    problem = message
                } else {
                    problem = "Det gick inte att publicera just nu. Försök igen om en stund."
                }
            }
            isSending = false
        }
    }
}

/// Ke52 "Välj skola": search from two letters, the name in bold and the town under it, no free text.
struct SchoolPicker: View {
    let model: RepetitionModel
    let title: String
    var selected: DrillSchool?
    /// "Vilken skola går du på?" the first time: with Hoppa över.
    var onSkip: (() -> Void)?
    let onPick: (DrillSchool) -> Void
    @State private var query = ""
    @State private var results: [DrillSchool] = []
    @State private var problem: String?
    @State private var searching: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if onSkip != nil {
                    Section {
                        Text("Då visas prov från din skola först. Det sparas bara på telefonen.").foregroundStyle(.secondary)
                    }
                }
                Section {
                    if query.trimmingCharacters(in: .whitespaces).count < 2 {
                        Text("Skriv minst två bokstäver.").foregroundStyle(.secondary)
                    } else if let problem {
                        Text(problem).foregroundStyle(.secondary)
                    } else if results.isEmpty, searching == nil {
                        Text("Ingen skola heter så. Sök på orten.").foregroundStyle(.secondary)
                    }
                    ForEach(results) { school in
                        Button { onPick(school) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(school.name).bold().foregroundStyle(.primary)
                                    if let locality = school.locality, !locality.isEmpty {
                                        Text(locality).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if school == selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                        .accessibilityLabel([school.name, school.locality].compactMap { $0 }.joined(separator: ", "))
                    }
                } footer: {
                    Text("Hittar du inte skolan? Sök på orten.")
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Sök skola eller ort")
            .onChange(of: query) { _, q in search(q) }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if let onSkip { Button("Hoppa över", action: onSkip) } else { Button("Avbryt") { dismiss() } }
                }
            }
        }
    }

    private func search(_ q: String) {
        searching?.cancel()
        problem = nil
        guard q.trimmingCharacters(in: .whitespaces).count >= 2 else { results = []; searching = nil; return }
        searching = Task {
            try? await Task.sleep(for: .milliseconds(250)) // while typing
            guard !Task.isCancelled else { return }
            do throws(DrillCloudError) {
                let found = try await model.schools(matching: q)
                guard !Task.isCancelled else { return }
                results = found
            } catch {
                problem = "Skolorna går inte att hämta just nu. Försök igen om en stund."
            }
            searching = nil
        }
    }
}

/// Ke52 "Prov från din skola": the school with Byt, subjects as filters, Kommande prov and Tidigare, Lägg till.
struct SchoolExamsView: View {
    let model: RepetitionModel
    @State private var school: DrillSchool?
    @State private var subject: String?
    @State private var results: [DrillPublicationView] = []
    @State private var problem: String?
    @State private var loading = false
    @State private var choosingSchool = false
    @State private var askingMySchool = false
    @State private var opened: DrillPublicationView?
    @State private var loaded = false

    var body: some View {
        List {
            Section {
                Button { choosingSchool = true } label: {
                    HStack {
                        Text(school?.name ?? "Alla skolor").foregroundStyle(.primary)
                        Spacer()
                        Text("Byt").foregroundStyle(.tint)
                    }
                }
                if !subjectsInResults.isEmpty {
                    Picker("Ämne", selection: $subject) {
                        Text("Alla").tag(String?.none)
                        ForEach(subjectsInResults, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                }
            }
            if let problem {
                Section { Text(problem).foregroundStyle(.secondary) }
            } else if !loading, shown.isEmpty {
                Section {
                    if let subject {
                        Text("Inga prov i \(subject.lowercased()) här än.")
                        Button("Visa alla") { self.subject = nil }
                    } else {
                        Text("Inga prov här än").bold()
                        Text("Publicera ditt nästa prov, så kan klasskompisarna plugga på samma frågor.").foregroundStyle(.secondary)
                    }
                }
            }
            if !upcoming.isEmpty { Section("Kommande prov") { ForEach(upcoming) { row($0) } } }
            if !earlier.isEmpty { Section("Tidigare") { ForEach(earlier) { row($0) } } }
        }
        .overlay { if loading && results.isEmpty { ProgressView() } }
        .navigationTitle("Prov från din skola")
        .refreshable { await load() }
        .task {
            guard !loaded else { return }
            loaded = true
            school = model.mySchool
            if !model.mySchoolAsked { askingMySchool = true }
            await load()
        }
        .sheet(isPresented: $choosingSchool) {
            SchoolPicker(model: model, title: "Välj skola", selected: school) { picked in
                school = picked
                choosingSchool = false
                Task { await load() }
            }
        }
        .sheet(isPresented: $askingMySchool) {
            SchoolPicker(model: model, title: "Vilken skola går du på?", onSkip: {
                model.mySchoolAsked = true
                askingMySchool = false
            }) { picked in
                model.mySchool = picked
                school = picked
                askingMySchool = false
                Task { await load() }
            }
        }
        .sheet(item: $opened) { publication in
            PublicationView(model: model, publication: publication)
        }
    }

    private var shown: [DrillPublicationView] { results.filter { subject == nil || $0.subject == subject } }
    private var subjectsInResults: [String] { Array(Set(results.map(\.subject))).sorted() }

    private var upcoming: [DrillPublicationView] {
        let today = Calendar.current.startOfDay(for: Date())
        return shown.filter { ($0.examDate ?? today) >= today }.sorted { ($0.examDate ?? .distantFuture) < ($1.examDate ?? .distantFuture) }
    }

    private var earlier: [DrillPublicationView] {
        let today = Calendar.current.startOfDay(for: Date())
        return shown.filter { ($0.examDate ?? today) < today }
    }

    private func row(_ p: DrillPublicationView) -> some View {
        let added = model.added(p) != nil
        return HStack(alignment: .center, spacing: 12) {
            Button { opened = p } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.title).font(.headline).foregroundStyle(.primary)
                    Text("\(p.subject) · \(p.examDate.map { DrillPublishing.shortDate($0) } ?? p.exam_date)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(([DrillText.questions(p.items)] + [p.display_name].compactMap { $0 }).joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if added {
                Text("Tillagt ✓").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Button("Lägg till") { opened = p }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Lägg till \(p.title)")
            }
        }
    }

    private func load() async {
        loading = true
        problem = nil
        do throws(DrillCloudError) {
            results = try await model.searchPublications(school: school, subject: nil)
        } catch {
            if case .offline = error {
                problem = "Ingen internetanslutning. Försök igen när du är uppkopplad."
            } else {
                problem = "Något gick fel. Försök igen."
            }
        }
        loading = false
    }
}

/// Ke52 "Ett publicerat prov": what is seen before adding, Lägg till i mina prov, and Rapportera.
struct PublicationView: View {
    let model: RepetitionModel
    let publication: DrillPublicationView
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var added: Drill?
    @State private var problem: String?
    @State private var reporting = false
    @State private var reported = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(publication.title).font(.title2.bold())
                        Text("\(publication.subject) · \(publication.examDate.map { DrillPublishing.shortDate($0) } ?? publication.exam_date) · \(publication.school.name)")
                            .foregroundStyle(.secondary)
                        Text(([DrillText.questions(publication.items)] + [publication.display_name].compactMap { $0 }).joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    if let added {
                        Text("**\(added.title) är tillagt.** Ljudet är redan klart.")
                        Button("Starta prov") {
                            let drill = added
                            dismiss()
                            Task {
                                try? await Task.sleep(for: .milliseconds(600)) // after the sheet is gone
                                await model.start(drill)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Senare") { dismiss() }
                    } else if let existing = model.added(publication) {
                        Text("Du har redan lagt till provet.")
                        Button("Öppna") {
                            model.openDrill = existing.id
                            dismiss()
                        }
                    } else {
                        Button {
                            add()
                        } label: {
                            Text(adding ? "Lägger till …" : "Lägg till i mina prov").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(adding)
                        .listRowBackground(Color.clear)
                    }
                    if let problem { Text(problem).foregroundStyle(.secondary) }
                }
                Section {
                    if reported {
                        Text("Tack. Vi tittar på det.").foregroundStyle(.secondary)
                    } else {
                        Button { reporting = true } label: { Label("Rapportera", systemImage: "flag") }
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Rapportera provet")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Stäng") { dismiss() } } }
            .sheet(isPresented: $reporting) {
                ReportSheet(model: model, publication: publication) { reported = true }
                    .presentationDetents([.medium])
            }
        }
    }

    private func add() {
        adding = true
        problem = nil
        Task {
            do throws(DrillCloudError) {
                added = try await model.addPublication(publication)
            } catch {
                if case .refused(let status, _, let message) = error {
                    problem = status == 404 ? "Provet finns inte längre." : message
                } else {
                    problem = "Ingen internetanslutning. Försök igen när du är uppkopplad."
                }
            }
            adding = false
        }
    }
}

/// Ke52 "Rapportera": four reasons, one check mark, Skicka; no free text.
struct ReportSheet: View {
    let model: RepetitionModel
    let publication: DrillPublicationView
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reason: DrillReportReason?
    @State private var sending = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Vad är fel?") {
                    ForEach(DrillReportReason.allCases, id: \.self) { r in
                        Button { reason = r } label: {
                            HStack {
                                Text(r.label).foregroundStyle(.primary)
                                Spacer()
                                if reason == r { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                    }
                }
                if let problem { Section { Text(problem).foregroundStyle(.secondary) } }
            }
            .navigationTitle("Rapportera provet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skicka") { send() }.disabled(reason == nil || sending)
                }
            }
        }
    }

    private func send() {
        guard let reason else { return }
        sending = true
        Task {
            do throws(DrillCloudError) {
                try await model.report(publication, reason: reason)
                onDone()
                dismiss()
            } catch {
                if case .refused(let status, _, _) = error, status == 409 {
                    problem = "Du har redan rapporterat provet. Tack."
                } else {
                    problem = "Något gick fel. Försök igen."
                }
            }
            sending = false
        }
    }
}

/// Ke52 "Publicerat" on the exam, and "Ta bort publiceringen?".
struct PublishedRow: View {
    let model: RepetitionModel
    let drill: Drill
    let publication: DrillPublication
    @Binding var editing: Bool
    @State private var confirming = false
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Publicerat", systemImage: "checkmark.circle.fill").foregroundStyle(LumenColor.ok)
            Text(DrillPublishing.line(publication)).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 20) {
                Button("Ändra") { editing = true }
                Button("Ta bort publiceringen", role: .destructive) { confirming = true }
            }
            .buttonStyle(.borderless)
            if let problem { Text(problem).font(.subheadline).foregroundStyle(.secondary) }
        }
        .confirmationDialog("Ta bort publiceringen?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Ta bort publiceringen", role: .destructive) {
                Task {
                    do throws(DrillCloudError) {
                        try await model.unpublish(drill)
                        model.importMessage = "Publiceringen är borttagen."
                    } catch {
                        problem = "Något gick fel. Försök igen."
                    }
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Provet försvinner från listan för \(publication.school.name). Ditt eget prov finns kvar.")
        }
    }
}
