import SwiftUI

/// A80/A81 (D142 §3, R11, Kelly Ke49): "Styr med dina AirPods" before the first Starta prov. The user presses once,
/// twice and three times; the app shows what really arrived and only the controls that work. Two or three presses
/// that never arrive mean AirPods 1/2 (one function per earbud): then the earbud settings that give all three.
/// No question about the model.
struct ControlCheckView: View {
    let onStart: () -> Void
    let onLater: () -> Void
    @State private var check: ControlCheck

    /// False for a check set up by the screenshots (Kelly Ke49 §7): it is shown as it is, not started again.
    private let beginsOnAppear: Bool

    init(hub: RemoteCommandHub, sound: URL?, waitSeconds: Double = 8,
         onStart: @escaping () -> Void, onLater: @escaping () -> Void) {
        self.onStart = onStart
        self.onLater = onLater
        self.beginsOnAppear = true
        _check = State(initialValue: ControlCheck(hub: hub, waitSeconds: waitSeconds))
        self.sound = sound
    }

    private let sound: URL?

    #if DEBUG
    /// The screenshots: a check already in the state to show.
    init(staged check: ControlCheck) {
        self.onStart = {}
        self.onLater = {}
        self.beginsOnAppear = false
        self.sound = nil
        _check = State(initialValue: check)
    }
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Styr med dina AirPods")
                        .font(LumenFont.text(28, .bold, relativeTo: .title))
                        .accessibilityAddTraits(.isHeader)
                    if check.heard.isEmpty, sound != nil {
                        Text("Frågan spelas en gång så att trycken kommer fram.")
                            .font(LumenFont.text(16))
                            .foregroundStyle(LumenColor.muted)
                    }
                    controlsList
                    if let step = check.step {
                        waiting(step)
                    } else if check.allWork {
                        done
                    } else {
                        missing
                    }
                }
                .padding(20)
            }
            .lumenScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { check.end(); onLater() } }
                if check.step != nil {
                    ToolbarItem(placement: .primaryAction) { Button("Hoppa över") { check.skip() } }
                }
            }
        }
        .onAppear { if beginsOnAppear { check.begin(sound: sound) } }
        .onDisappear { check.end() }
    }

    private var controlsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(.one, "Hela svaret", "Långt svar")
            row(.two, "Bara första meningen", "Kort svar")
            row(.three, "Vilket tryck som helst fortsätter", "Paus")
        }
    }

    private func row(_ step: ControlCheck.Step, _ press: String, _ meaning: String) -> some View {
        HStack(spacing: 12) {
            Group {
                if check.passed.contains(step) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LumenColor.ok)
                } else if check.missed.contains(step) {
                    Image(systemName: "minus.circle").foregroundStyle(LumenColor.muted)
                } else if check.step == step {
                    Image(systemName: "circle.dotted").foregroundStyle(LumenColor.blue)
                } else {
                    Image(systemName: "circle").foregroundStyle(LumenColor.line)
                }
            }
            .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(String(repeating: "●", count: step.rawValue))  \(meaning)").font(LumenFont.text(17, .semibold))
                Text(status(step, press))
                    .font(LumenFont.text(14))
                    .foregroundStyle(check.step == step ? LumenColor.blue : LumenColor.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Kelly B4: "Kom inte fram" and "Hoppades över" only once the test is done; during it Väntar … and Sen.
    private func status(_ step: ControlCheck.Step, _ press: String) -> String {
        if check.passed.contains(step) { return "\(press) ✓" }
        if check.isDone {
            if check.skipped.contains(step) { return "Hoppades över" }
            if check.missed.contains(step) { return "Kom inte fram" }
        }
        if check.step == step { return "Väntar …" }
        return check.isDone || check.missed.contains(step) ? press : "Sen"
    }

    private func waiting(_ step: ControlCheck.Step) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.prompt).font(LumenFont.text(24, .bold, relativeTo: .title2))
            Text(step.hint).font(LumenFont.text(17)).foregroundStyle(LumenColor.muted)
            Text(String(repeating: "●  ", count: step.rawValue).trimmingCharacters(in: .whitespaces))
                .font(.system(size: 22))
                .foregroundStyle(LumenColor.blue)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LumenColor.soft, in: RoundedRectangle(cornerRadius: LumenCard.radius))
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Allt fungerar", systemImage: "checkmark.circle.fill")
                .font(LumenFont.text(22, .bold, relativeTo: .title2))
                .foregroundStyle(LumenColor.ok)
            Text("Under paus fortsätter vilket tryck som helst.")
                .font(LumenFont.text(17))
            Label("Knapparna på låsskärmen gör samma sak.", systemImage: "lock")
                .font(LumenFont.text(15))
                .foregroundStyle(LumenColor.muted)
            startButton("Starta prov")
            Text("Avsluta på telefonen. Annars börjar listan om.")
                .font(LumenFont.text(15))
                .foregroundStyle(LumenColor.muted)
        }
    }

    private var missing: some View {
        VStack(alignment: .leading, spacing: 12) {
            if check.needsEarbudSettings {
                Text("Dina AirPods har dubbeltryck per lur").font(LumenFont.text(20, .bold, relativeTo: .title3))
                Text("Ställ in dem så här, så fungerar alla tre:")
                    .font(LumenFont.text(17))
                Text("Vänster: Nästa spår → kort svar\nHöger: Spela/pausa → långt svar och paus")
                    .font(LumenFont.text(17, .semibold))
                Text("Inställningar › Bluetooth › ⓘ vid dina AirPods › Dubbeltryck")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
                Button("Öppna Inställningar") { ErrorCard.openSettings() }
                    .buttonStyle(LumenButtonStyle(kind: .secondary, height: 48))
            } else {
                Text("Trycken kom inte fram").font(LumenFont.text(20, .bold, relativeTo: .title3))
                Text("Kolla att båda AirPods sitter i öronen och är anslutna. Knapparna på låsskärmen fungerar alltid.")
                    .font(LumenFont.text(17))
            }
            Button("Prova igen") { check.restart() }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 48))
            startButton("Starta ändå")
        }
    }

    private func startButton(_ title: String) -> some View {
        Button {
            check.end()
            onStart()
        } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(LumenButtonStyle(height: 54))
    }
}
