import SwiftUI

/// A80 (D142, Kelly Ke49 "Hem med prov" / "Hem utan prov"): the top of Start. Without an exam: "Plugga med AirPods"
/// and the blue Nytt prov. With exams: the latest exam's card with **Starta prov** as the one blue button (one tap the
/// next time), "Frågor och svar" and "Dela" as text buttons, the other exams in a list, and Nytt prov as a secondary
/// button. "Har du fått ett prov?" takes a pasted link or code (K47, until universal links exist).
struct RepetitionHomeSection: View {
    let model: RepetitionModel
    @State private var isCreating = false
    @State private var opened: UUID?
    /// "Dela" on the card: the exam at its Dela section.
    @State private var sharing: UUID?
    @State private var askingCode = false
    @State private var pastedCode = ""
    @AppStorage("repetition.controlsChecked") private var controlsChecked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let latest = model.drills.first {
                latestCard(latest)
                if model.drills.count > 1 { SectionLabel("Andra prov").padding(.top, 4) }
                ForEach(model.drills.dropFirst()) { drill in row(drill) }
                Button {
                    isCreating = true
                } label: {
                    Label("Nytt prov", systemImage: "plus").font(LumenFont.text(18, .semibold, relativeTo: .headline))
                }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 54))
            } else {
                emptyCard
            }
            Button("Har du fått ett prov? Klistra in länken") { askingCode = true }
                .font(LumenFont.text(15))
                .foregroundStyle(LumenColor.blue)
        }
        .sheet(isPresented: $isCreating) {
            NewDrillView(model: model) { drill in opened = drill.id }
        }
        .navigationDestination(item: $opened) { id in
            DrillView(model: model, drillID: id)
        }
        .navigationDestination(item: $sharing) { id in
            DrillView(model: model, drillID: id, showsShare: true)
        }
        .alert("Öppna ett delat prov", isPresented: $askingCode) {
            TextField("Länk eller kod", text: $pastedCode)
            Button("Öppna") {
                if let code = DrillShareClient.code(inText: pastedCode) { model.open(code: code) } else {
                    model.importMessage = "Det ser inte ut som en länk till ett prov."
                }
                pastedCode = ""
            }
            Button("Avbryt", role: .cancel) { pastedCode = "" }
        } message: {
            Text("Klistra in länken du fick, så läggs provet till hos dig med samma ljud.")
        }
        .onChange(of: model.openDrill) { _, id in
            if let id { opened = id; model.openDrill = nil }
        }
        .task { model.prepareAllAudio() }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kom förberedd till provet") // A86 (Aron 22:19)
                .font(LumenFont.text(24, .bold, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
            Text("Fota ditt material. Earmind gör frågor och svar och läser upp dem i örat. Du styr med tryck på AirPods, utan mikrofon.")
                .font(LumenFont.text(16))
                .foregroundStyle(LumenColor.muted)
            Button {
                isCreating = true
            } label: {
                Label("Nytt prov", systemImage: "plus").font(LumenFont.text(22, .bold, relativeTo: .title2))
            }
            .buttonStyle(LumenButtonStyle(height: 72))
        }
        .padding(16)
        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: LumenCard.radius))
    }

    private func latestCard(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        let ready = p.total > 0 && p.ready == p.total
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("Nästa prov")
                Text(drill.title)
                    .font(LumenFont.text(22, .bold, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                Text(ready ? "\(DrillText.questions(drill.items.count)) · cirka \(DrillText.minutesPerLap(drill)) min per varv"
                     : "\(DrillText.questions(drill.items.count)) · Ljud: \(p.ready) av \(p.total) klara")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
                    .monospacedDigit()
            }
            Button {
                start(drill)
            } label: {
                Label("Starta prov", systemImage: "play.fill").font(LumenFont.text(22, .bold, relativeTo: .title2))
            }
            .buttonStyle(LumenButtonStyle(height: 72))
            .disabled(!model.canStart(drill))
            .accessibilityHint("Spelar frågorna i dina AirPods. Earmind använder inte mikrofonen.")
            HStack(spacing: 20) {
                Button("Frågor och svar") { opened = drill.id }
                Button("Dela") { sharing = drill.id }
            }
            .font(LumenFont.text(16, .semibold))
            .foregroundStyle(LumenColor.blue)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: LumenCard.radius))
    }

    /// One tap when the AirPods check was done and there is nothing to go on from; otherwise the exam's screen asks.
    private func start(_ drill: Drill) {
        if controlsChecked, model.savedIndex(drill) == nil {
            Task { await model.start(drill) }
        } else {
            opened = drill.id
        }
    }

    /// Kelly R7: the row opens the exam, ▶ starts it directly.
    private func row(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        let ready = p.total > 0 && p.ready == p.total
        return HStack(spacing: 12) {
            Button { opened = drill.id } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drill.title).font(LumenFont.text(18, .semibold)).foregroundStyle(LumenColor.ink)
                    Text(ready ? "\(DrillText.questions(drill.items.count)) · ljud klart" : "Ljud: \(p.ready) av \(p.total) klara")
                        .font(LumenFont.text(14))
                        .foregroundStyle(LumenColor.muted)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öppnar provet")
            Button { start(drill) } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(LumenColor.blue.opacity(model.canStart(drill) ? 1 : 0.35))
            }
            .buttonStyle(.plain)
            .disabled(!model.canStart(drill))
            .accessibilityLabel("Starta \(drill.title)")
        }
        .padding(14)
        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: LumenCard.radius))
    }
}

/// A80 (D142): the listening modes are BETA, under the repetition.
struct BetaModesHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                SectionLabel("Fler lägen")
                BetaBadge()
            }
            Text("De här lägena lyssnar på vad du säger. De är i BETA och blir bättre hela tiden.")
                .font(LumenFont.text(15))
                .foregroundStyle(LumenColor.muted)
        }
        .padding(.top, 8)
    }
}

/// Kelly Ke49 §4.4: a grey outline, 11 pt bold capitals, corner 6. A label, not a warning: no colour, no icon.
struct BetaBadge: View {
    var body: some View {
        Text("BETA")
            .font(LumenFont.text(11, .bold, relativeTo: .caption2))
            .foregroundStyle(LumenColor.muted)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LumenColor.muted, lineWidth: 1))
            .accessibilityLabel("Beta, under utveckling")
    }
}

/// A78/A80: the playing screen over everything, "Fortsätt där du var?" after iOS closed the app, and a shared exam
/// opened from a link (A81).
struct RepetitionOverlay: ViewModifier {
    let model: RepetitionModel?
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        if let model {
            content
                .fullScreenCover(isPresented: Binding(get: { model.showsPlayer }, set: { if !$0 { model.showsPlayer = false } })) {
                    RepetitionPlayerView(model: model)
                }
                .sheet(item: Binding(get: { model.showsPlayer ? nil : model.resumeOffer },
                                     set: { if $0 == nil { model.resumeOffer = nil } })) { offer in
                    ResumeSheet(model: model, offer: offer)
                        .presentationDetents([.medium])
                }
                .alert(model.importMessage ?? "", isPresented: Binding(get: { model.importMessage != nil },
                                                                      set: { if !$0 { model.importMessage = nil } })) {
                    Button("Okej") { model.importMessage = nil }
                }
                .onOpenURL { url in _ = model.handle(url) }
                .task { model.checkResume() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, !model.session.isActive, model.showsPlayer { model.showsPlayer = false }
                }
        } else {
            content
        }
    }
}

/// Kelly Ke49 "Fortsätt där du var?": a sheet from below with the exam, the question and two buttons.
struct ResumeSheet: View {
    let model: RepetitionModel
    let offer: RepetitionModel.ResumeOffer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fortsätt där du var?")
                .font(LumenFont.text(24, .bold, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
            Text("\(offer.drill.title), fråga \(offer.index + 1) av \(offer.drill.items.count).")
                .font(LumenFont.text(16))
                .foregroundStyle(LumenColor.muted)
            if offer.drill.items.indices.contains(offer.index) {
                Text(offer.drill.items[offer.index].question).font(LumenFont.text(20, .semibold))
            }
            Spacer(minLength: 0)
            Button {
                go(at: offer.index)
            } label: {
                Text("Fortsätt").frame(maxWidth: .infinity)
            }
            .buttonStyle(LumenButtonStyle(height: 56))
            Button {
                go(at: 0)
            } label: {
                Text("Börja från fråga 1").frame(maxWidth: .infinity)
            }
            .buttonStyle(LumenButtonStyle(kind: .secondary, height: 52))
            Button("Inte nu") { model.resumeOffer = nil }
                .font(LumenFont.text(16, .semibold))
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .lumenScreen()
    }

    /// The sheet closes first: SwiftUI does not open the playing screen while a sheet is closing (handover).
    private func go(at index: Int) {
        let drill = offer.drill
        model.resumeOffer = nil
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await model.start(drill, at: index)
        }
    }
}
