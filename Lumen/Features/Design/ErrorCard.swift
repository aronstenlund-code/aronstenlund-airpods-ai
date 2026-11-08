import SwiftUI
import UIKit

/// D86 screen 6: problems in Swedish, each with what to do. Never a code or HTTP status; those are only in
/// Settings › Diagnostics.
enum LumenProblem: Equatable, Sendable {
    case microphoneDenied
    case offline
    case airPodsDisconnected
    case overloaded

    var title: String {
        switch self {
        case .microphoneDenied: "Lumen hör dig inte"
        case .offline: "Ingen internetanslutning"
        case .airPodsDisconnected: "AirPods kopplades bort"
        case .overloaded: "Lumen är överbelastad"
        }
    }

    var text: String {
        switch self {
        case .microphoneDenied: "Mikrofonen är avstängd. Slå på den i Inställningar för att fortsätta."
        case .offline: "Lumen behöver internet för att svara. Den fortsätter lyssna och svarar igen när du är uppkopplad."
        case .airPodsDisconnected: "Svaren hörs nu i telefonens högtalare."
        case .overloaded: "Försök igen om en minut."
        }
    }

    /// The button, if any.
    var actionTitle: String? {
        switch self {
        case .microphoneDenied: "Öppna Inställningar"
        case .offline: nil
        case .airPodsDisconnected: "Pausa"
        case .overloaded: "Försök igen"
        }
    }

    /// What is said in the ear at the same time, so the phone can stay in the pocket. Nil: nothing (no microphone
    /// means no audio session; a disconnect is already heard).
    var spoken: String? {
        switch self {
        case .microphoneDenied: nil
        case .offline: "Ingen internetanslutning."
        case .airPodsDisconnected: nil
        case .overloaded: "Försök igen om en minut."
        }
    }

    var symbol: String {
        switch self {
        case .microphoneDenied: "mic.slash"
        case .offline: "wifi.slash"
        case .airPodsDisconnected: "airpods"
        case .overloaded: "hourglass"
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
                    .foregroundStyle(LumenColor.red)
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
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(LumenColor.red.opacity(0.5), lineWidth: 1.5) }
        .accessibilityElement(children: .contain)
    }
}
