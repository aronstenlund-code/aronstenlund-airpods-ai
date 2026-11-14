import SwiftUI
import UIKit

/// D86 screen 6: problems in Swedish, each with what to do. Never a code or HTTP status; those are only in
/// Settings › Diagnostics.
enum LumenProblem: Equatable, Sendable {
    case microphoneDenied
    case offline
    case airPodsDisconnected
    /// A5: /answer failed (credits out, the provider down, too slow): "Jag kan inte svara just nu".
    case overloaded
    /// A5: the chosen voice (ElevenLabs) failed; answers are read with the iPhone's voice meanwhile.
    case voiceUnavailable
    /// A11: no speech recognition runs (Scribe and the phone both failed); Lumen retries by itself.
    case cannotHear

    var title: String {
        switch self {
        case .microphoneDenied: "EarMind hör dig inte"
        case .offline: "Ingen internetanslutning"
        case .airPodsDisconnected: "AirPods kopplades bort"
        case .overloaded: "EarMind kan inte svara just nu"
        case .voiceUnavailable: "Rösten fungerar inte just nu"
        case .cannotHear: "Jag hör inte just nu"
        }
    }

    var text: String {
        switch self {
        case .microphoneDenied: "Mikrofonen är avstängd. Slå på den i Inställningar för att fortsätta."
        case .offline: "EarMind behöver internet för att svara. Den fortsätter lyssna och svarar igen när du är uppkopplad."
        case .airPodsDisconnected: "Svaren hörs nu i telefonens högtalare."
        case .overloaded: "Försök igen om en stund."
        case .voiceUnavailable: "Svaren läses med iPhonens röst tills den fungerar igen."
        case .cannotHear: "Taligenkänningen gick ner. EarMind försöker igen av sig själv."
        }
    }

    /// The button, if any.
    var actionTitle: String? {
        switch self {
        case .microphoneDenied: "Öppna Inställningar"
        case .offline: nil
        case .airPodsDisconnected: "Pausa"
        case .overloaded: "Försök igen"
        case .voiceUnavailable: nil
        case .cannotHear: nil
        }
    }

    /// What is said in the ear at the same time, so the phone can stay in the pocket. Nil: nothing (no microphone
    /// means no audio session; a disconnect is already heard).
    var spoken: String? {
        switch self {
        case .microphoneDenied: nil
        case .offline: "Ingen internetanslutning."
        case .airPodsDisconnected: nil
        case .overloaded: "Jag kan inte svara just nu, försök igen om en stund."
        case .voiceUnavailable: nil
        case .cannotHear: "Jag hör inte just nu, försöker igen."
        }
    }

    var symbol: String {
        switch self {
        case .microphoneDenied: "mic.slash"
        case .offline: "wifi.slash"
        case .airPodsDisconnected: "airpods"
        case .overloaded: "exclamationmark.bubble"
        case .voiceUnavailable: "speaker.slash"
        case .cannotHear: "ear.trianglebadge.exclamationmark"
        }
    }
}

extension LumenProblem {
    /// Kelly Ke28 F4: Lumen cannot answer (no network, the service, the microphone, the recogniser). The voice falling
    /// back to the iPhone's, or the AirPods going, still gets answers: no red.
    nonisolated var stopsAnswers: Bool {
        switch self {
        case .voiceUnavailable, .airPodsDisconnected: false
        default: true
        }
    }
}

struct ErrorCard: View {
    let problem: LumenProblem
    var action: (() -> Void)?

    @MainActor static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: problem.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(problem.stopsAnswers ? LumenColor.red : LumenColor.muted)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(problem.title).font(LumenFont.text(17, .semibold, relativeTo: .headline))
                    Text(problem.text).font(LumenFont.text(15)).foregroundStyle(LumenColor.muted)
                }
            }
            if let title = problem.actionTitle, let action {
                Button(title, action: action)
                    .buttonStyle(LumenButtonStyle(kind: .secondary, height: 48))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LumenColor.background, in: RoundedRectangle(cornerRadius: 10))
        // Kelly Ke28 F4: red only when Lumen cannot answer; the voice or the AirPods get a neutral card.
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(problem.stopsAnswers ? LumenColor.red.opacity(0.5) : LumenColor.line, lineWidth: problem.stopsAnswers ? 1.5 : 1)
        }
        .accessibilityElement(children: .contain)
    }
}
