import SwiftUI
import UIKit
import UserNotifications

// A109 (D194, Kelly Ke65 `docs/design/repetition-texter.md` §14): the views of the practice reminder. The app's own
// short question after the first exam that was played through (before iOS's question, shown once), and the section in
// Inställningar (on/off and the time). The logic is A108 (`RepetitionModel.practice`, `LumenNotifications`).

/// "18" or "18:30", as the question says the time.
enum ReminderText {
    static func clock(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60)" : String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

/// Ke65: "Vill du ha en påminnelse?" as a sheet in the system's style. **Påminn mig** asks iOS, **Inte nu** never asks
/// again (Inställningar can turn it on).
struct PracticeReminderQuestion: View {
    let model: RepetitionModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAsking = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .padding(.top, 28)
                    .accessibilityHidden(true)
                Text("Vill du ha en påminnelse?")
                    // Kelly P3: with the largest text the "?" stood alone on a row of its own.
                    .font(typeSize.isAccessibilitySize ? .title3.bold() : .title2.bold())
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("EarMind kan påminna dig klockan \(ReminderText.clock(LumenNotifications.practiceMinutes)) de dagar du inte har pluggat. Högst en gång om dagen.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button {
                    isAsking = true
                    Task {
                        await model.allowPracticeReminders() // iOS's own question comes now
                        dismiss()
                    }
                } label: {
                    FilledButtonLabel { Text("Påminn mig").font(.headline).frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAsking)
                Button("Inte nu") {
                    model.declinePracticeReminders()
                    dismiss()
                }
                .frame(minHeight: 44)
                Text("Du kan ändra tiden eller stänga av det i Inställningar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1) // as `MainActionBar`
            .background(.regularMaterial)
        }
        // Half a screen is enough for the question; with the largest text it needs the whole screen (SE: only the
        // heading showed in the half sheet).
        // Kelly P4: no taller than what it holds (half a screen left an empty band on iPhone 17 Pro).
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(390), .large])
        .interactiveDismissDisabled() // one of the two answers, so the question is not asked again by a swipe
    }
}

/// Ke65: the section PÅMINNELSE in Inställningar: the switch, the time while it is on, and what to do when iOS's
/// notifications are off for the app.
struct PracticeReminderSection<Other: View>: View {
    let model: RepetitionModel
    /// The screenshots: iOS has said no to notifications.
    var stagedDenied: Bool? = nil
    /// A110 (D198): one section "Påminnelser" in Inställningar. The listening modes' older reminder (the study plan)
    /// is the rows after this one, and the footer is one sentence for both (Kelly); no setting is removed.
    var mergedFooter: String? = nil
    @ViewBuilder var other: () -> Other
    @AppStorage(LumenNotifications.practiceEnabledKey) private var isOn = true
    @AppStorage(LumenNotifications.practiceTimeKey) private var minutes = LumenNotifications.practiceHour * 60
    @State private var isDenied = false

    /// The time as a date today, for the picker.
    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (parts.hour ?? LumenNotifications.practiceHour) * 60 + (parts.minute ?? 0)
            Task { await model.reschedulePracticeReminders() }
        }
    }

    var body: some View {
        Section {
            Toggle("Påminn mig att plugga", isOn: $isOn)
                .onChange(of: isOn) { _, on in
                    Task {
                        // Turning it on is the student's own tap, so iOS may ask now if it has not asked.
                        await model.reschedulePracticeReminders(ask: on)
                        await readStatus()
                    }
                }
            if isOn {
                DatePicker("Tid", selection: time, displayedComponents: .hourAndMinute)
                if isDenied {
                    Button("Öppna Inställningar") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
            other()
        } header: {
            Text("Påminnelser")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if isOn && isDenied { Text("Notiser är avstängda för EarMind.") }
                if let mergedFooter {
                    Text(verbatim: mergedFooter)
                } else if !(isOn && isDenied) {
                    Text("Högst en gång om dagen, och bara de dagar du inte har pluggat.")
                }
            }
        }
        .task { await readStatus() }
    }

    private func readStatus() async {
        if let stagedDenied { isDenied = stagedDenied; return }
        isDenied = await LumenNotifications.status() == .denied
    }
}

extension PracticeReminderSection where Other == EmptyView {
    /// The practice reminder alone (the screenshots, and an app without the listening modes' reminder).
    init(model: RepetitionModel, stagedDenied: Bool? = nil) {
        self.init(model: model, stagedDenied: stagedDenied, mergedFooter: nil) { EmptyView() }
    }
}
