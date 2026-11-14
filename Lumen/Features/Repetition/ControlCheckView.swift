import SwiftUI

/// A80/A81 (D142 §3, R11), rebuilt in A87 (D160, Kelly Ke53 `apple/kontroller.png`): "Styr med dina AirPods" before
/// the first Starta prov, laid out like the system's own introductions (pairing AirPods, Face ID): a picture with the
/// presses to make, one instruction, one line under it and the three steps as a list. The user presses once, twice
/// and three times; the app shows what really arrived. **Starta prov** is fixed at the bottom (grey until the check
/// is done) with Hoppa över as a text button under it. Two or three presses that never arrive mean AirPods 1/2 (one
/// function per earbud): then the earbud settings that give all three. No question about the model.
struct ControlCheckView: View {
    let onStart: () -> Void
    let onLater: () -> Void
    @State private var check: ControlCheck
    @Environment(\.dynamicTypeSize) private var typeSize

    /// False for a check set up by the screenshots (Kelly Ke49 §7): it is shown as it is, not started again.
    private let beginsOnAppear: Bool

    init(hub: RemoteCommandHub, sound: URL?, waitSeconds: Double = 8, help: RepetitionModel? = nil,
         onStart: @escaping () -> Void, onLater: @escaping () -> Void) {
        self.onStart = onStart
        self.onLater = onLater
        self.helpModel = help
        self.beginsOnAppear = true
        _check = State(initialValue: ControlCheck(hub: hub, waitSeconds: waitSeconds))
        self.sound = sound
    }

    private let sound: URL?
    /// A92 (D166): the exam mode, for "Fråga om Earmind" in the toolbar. Nil = no ? button.
    private let helpModel: RepetitionModel?
    @State private var showsHelp = false

    #if DEBUG
    /// The screenshots: a check already in the state to show.
    init(staged check: ControlCheck) {
        self.onStart = {}
        self.onLater = {}
        self.helpModel = nil
        self.beginsOnAppear = false
        self.sound = nil
        _check = State(initialValue: check)
    }
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // With the accessibility sizes the instruction itself comes first: the picture only repeats it.
                    if !typeSize.isAccessibilitySize { hero }
                    VStack(spacing: 8) {
                        Text(verbatim: title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(verbatim: detail)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    if check.isDone, !check.allWork, check.needsEarbudSettings {
                        Button("Öppna Inställningar") { ErrorCard.openSettings() }
                            .buttonStyle(.bordered)
                    }
                    steps
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) { actions }
            .navigationTitle("Styr med dina AirPods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { check.end(); onLater() } }
                if helpModel?.help != nil { // A92 (Kelly Ke57)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsHelp = true
                        } label: {
                            Label("Fråga om Earmind", systemImage: "questionmark.circle")
                        }
                    }
                }
            }
        }
        // The check waits a few seconds per press: after the help it starts again from the first press.
        .sheet(isPresented: $showsHelp, onDismiss: { if beginsOnAppear { check.restart() } }) {
            if let helpModel { HelpChatView(model: helpModel, suggestion: "Hur fungerar trycken?") }
        }
        // SYSTEM §0.6: haptics only when something really happened: a press arrived.
        .sensoryFeedback(.success, trigger: check.passed.count) { old, new in new > old }
        .onAppear { if beginsOnAppear { check.begin(sound: sound) } }
        // A95: the instruction changes by itself when a press arrives; VoiceOver says the new one.
        .onChange(of: title) { _, now in AccessibilityNotification.Announcement(now).post() }
        .onDisappear { check.end() }
    }

    // MARK: The picture, the instruction and the line under it

    /// The presses to make now as dots (Ke49 §4.1: dots, no AirPods pictures), a check mark when all three arrived.
    private var hero: some View {
        ZStack {
            Circle().fill(Color(.secondarySystemBackground))
            if let step = check.step {
                HStack(spacing: 10) {
                    ForEach(0..<step.rawValue, id: \.self) { _ in
                        Circle().fill(.tint).frame(width: 16, height: 16)
                    }
                }
            } else {
                Image(systemName: check.allWork ? "checkmark" : "hand.tap")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(check.allWork ? Color.green : Color.secondary)
            }
        }
        .frame(width: 132, height: 132)
        .accessibilityHidden(true)
    }

    private var title: String {
        if let step = check.step { return step.prompt }
        if check.allWork { return "Allt fungerar" }
        return check.needsEarbudSettings ? "Dina AirPods har dubbeltryck per lur" : "Trycken kom inte fram"
    }

    private var detail: String {
        if let step = check.step {
            // Kelly N2: say why a question starts playing.
            return sound != nil && check.heard.isEmpty ? "\(step.hint). Frågan spelas en gång så att trycken kommer fram."
                : "\(step.hint)."
        }
        if check.allWork { return "Under paus fortsätter vilket tryck som helst. Knapparna på låsskärmen gör samma sak." }
        if check.needsEarbudSettings {
            return "Ställ in Vänster på Nästa spår och Höger på Spela/pausa, så fungerar alla tre. "
                + "Inställningar › Bluetooth › ⓘ vid dina AirPods › Dubbeltryck."
        }
        return "Kolla att båda AirPods sitter i öronen och är anslutna. Knapparna på låsskärmen fungerar alltid."
    }

    // MARK: The three steps

    /// A90 (Aron 23:13): the controls in exactly these words, one sentence per row.
    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medan frågan spelas:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
            VStack(spacing: 0) {
                row(.one, "tryck 1 gång för frågans A-svar.") // Kelly K1: lower case after the colon, as Aron wrote it
                Divider().padding(.leading, 52)
                row(.two, "Tryck 2 gånger för ett kort A-svar på en till två meningar.")
                Divider().padding(.leading, 52)
                row(.three, "Tryck 3 gånger för att pausa. Tryck igen för att fortsätta.")
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func row(_ step: ControlCheck.Step, _ text: String) -> some View {
        HStack(spacing: 12) {
            Group {
                if check.passed.contains(step) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if check.missed.contains(step) {
                    Image(systemName: "minus.circle").foregroundStyle(.secondary)
                } else if check.step == step {
                    ProgressView()
                } else {
                    Image(systemName: "circle").foregroundStyle(.tertiary)
                }
            }
            .font(.title3)
            .frame(width: 28)
            .accessibilityHidden(true) // A95: the state is read as words ("Kom fram", "Väntar på ditt tryck")
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: text)
                if let result = outcome(step) {
                    Text(verbatim: result)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityValue(check.step == step ? "Väntar på ditt tryck" : "")
    }

    /// Kelly B4: "Kom inte fram" and "Hoppades över" only once the test is done; "Kom fram" as soon as it did.
    private func outcome(_ step: ControlCheck.Step) -> String? {
        if check.passed.contains(step) { return "Kom fram" }
        guard check.isDone else { return nil }
        if check.skipped.contains(step) { return "Hoppades över" }
        if check.missed.contains(step) { return "Kom inte fram" }
        return nil
    }

    // MARK: The buttons, fixed at the bottom

    private var actions: some View {
        VStack(spacing: 4) {
            Button {
                check.end()
                onStart()
            } label: {
                FilledButtonLabel { // A95
                    Text(verbatim: check.isDone && !check.allWork ? "Starta ändå" : "Starta prov")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!check.isDone)
            if check.step != nil {
                Button("Hoppa över") { check.skip() }
                    .frame(minHeight: 44)
            } else if check.allWork {
                Text("Avsluta på telefonen. Annars börjar listan om.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            } else {
                Button("Prova igen") { check.restart() }
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1) // as `MainActionBar`
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() } // Kelly S4
    }
}
