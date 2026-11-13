import SwiftUI

/// A80 (D142, Kelly Ke49): the top of Start. "Plugga med AirPods" with the exams (the sound's progress on each) and
/// "Nytt prov" as the screen's one blue button. A tapped exam opens `DrillView` (Starta prov, the questions, Dela).
struct RepetitionHomeSection: View {
    let model: RepetitionModel
    @State private var isCreating = false
    @State private var opened: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Plugga med AirPods")
            if model.drills.isEmpty {
                Text("Fota sidorna eller lägg till text. Earmind gör provfrågor med svar och läser dem i dina AirPods. Du styr med tryck, utan mikrofon.")
                    .font(LumenFont.text(16))
                    .foregroundStyle(LumenColor.muted)
            } else {
                ForEach(model.drills) { drill in
                    Button { opened = drill.id } label: { row(drill) }
                        .buttonStyle(.plain)
                }
            }
            Button {
                isCreating = true
            } label: {
                Label("Nytt prov", systemImage: "plus")
                    .font(LumenFont.text(20, .bold, relativeTo: .title3))
            }
            .buttonStyle(LumenButtonStyle(kind: model.drills.isEmpty ? .primary : .secondary, height: 60))
        }
        .sheet(isPresented: $isCreating) {
            NewDrillView(model: model) { drill in opened = drill.id }
        }
        .navigationDestination(item: $opened) { id in
            DrillView(model: model, drillID: id)
        }
        .task { model.prepareAllAudio() }
    }

    private func row(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        let ready = p.total > 0 && p.ready == p.total
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(drill.title).font(LumenFont.text(18, .semibold)).foregroundStyle(LumenColor.ink)
                Text(ready ? "\(drill.items.count) frågor · ljud klart" : "Ljud: \(p.ready) av \(p.total) klara")
                    .font(LumenFont.text(14))
                    .foregroundStyle(LumenColor.muted)
                    .monospacedDigit()
            }
            Spacer()
            if ready {
                Image(systemName: "play.circle.fill").font(.system(size: 30)).foregroundStyle(LumenColor.blue)
            } else {
                ProgressView(value: Double(p.ready), total: Double(max(p.total, 1))).frame(width: 44)
            }
        }
        .padding(14)
        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: LumenCard.radius))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öppnar provet")
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

struct BetaBadge: View {
    var body: some View {
        Text("BETA")
            .font(LumenFont.text(11, .bold, relativeTo: .caption2))
            .foregroundStyle(LumenColor.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(LumenColor.soft, in: Capsule())
            .accessibilityLabel("Beta")
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
                .alert("Fortsätt där du var?", isPresented: Binding(get: { model.resumeOffer != nil && !model.showsPlayer },
                                                                      set: { if !$0 { model.resumeOffer = nil } })) {
                    if let offer = model.resumeOffer {
                        Button("Fortsätt") {
                            model.resumeOffer = nil
                            Task { await model.start(offer.drill, at: offer.index) }
                        }
                        Button("Börja från fråga 1") {
                            model.resumeOffer = nil
                            Task { await model.start(offer.drill) }
                        }
                        Button("Inte nu", role: .cancel) { model.resumeOffer = nil }
                    }
                } message: {
                    if let offer = model.resumeOffer {
                        Text("\(offer.drill.title), fråga \(offer.index + 1) av \(offer.drill.items.count).")
                    }
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
