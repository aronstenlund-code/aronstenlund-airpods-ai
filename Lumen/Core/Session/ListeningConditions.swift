import Foundation
import UIKit

/// Deangelo 2026-11-27 02:59: listening when something is not as it should be. Each case is one short line on Lyssnar
/// with the way on in it, never a silent stop. The AirPods lost mid-session and the microphone refused are cards
/// (`LumenProblem`), because the listening stops there; these go on.
enum ListeningCondition: Equatable, Sendable {
    /// Listening through the phone: no AirPods (or other headphones) are connected.
    case noAirPods
    /// No network. `phoneModel`: the phone's own model answers meanwhile (A159).
    case offline(phoneModel: Bool)
    /// The battery is low and not charging.
    case lowBattery(percent: Int)
    case lowPowerMode

    static let lowBatteryPercent = 10

    var line: String {
        switch self {
        case .noAirPods:
            String(localized: "Inga AirPods anslutna. Svaren hörs i telefonens högtalare – sätt i AirPods när du vill.")
        case .offline(phoneModel: true):
            String(localized: "Inget nät. Telefonens egen modell svarar så länge.")
        case .offline(phoneModel: false):
            String(localized: "Inget nät. EarMind lyssnar vidare och svarar när du är uppkopplad igen.")
        case .lowBattery(let percent):
            String(localized: "Batteriet är på \(Self.percentText(percent)). Sätt telefonen på laddning så att EarMind kan lyssna vidare.")
        case .lowPowerMode:
            String(localized: "Lågenergiläge är på. EarMind lyssnar som vanligt, men svaren kan dröja lite.")
        }
    }

    var symbol: String {
        switch self {
        case .noAirPods: "speaker.wave.2"
        case .offline: "wifi.slash"
        case .lowBattery: "battery.25"
        case .lowPowerMode: "battery.50"
        }
    }

    /// "8 %" in Swedish, "8%" in English (the phone's own way of writing it).
    static func percentText(_ percent: Int) -> String {
        (Double(percent) / 100).formatted(.percent.locale(Locale(identifier: AppLanguage.current == .sv ? "sv_SE" : "en_US")))
    }

    /// The one line to show while EarMind listens, the most important first: without a network the answers change,
    /// without AirPods where they are heard, and the battery before the low power mode. Nil: nothing to say.
    static func current(externalOutput: Bool, online: Bool, phoneModel: Bool, batteryPercent: Int?, charging: Bool,
                        lowPowerMode: Bool) -> ListeningCondition? {
        if !online { return .offline(phoneModel: phoneModel) }
        if !externalOutput { return .noAirPods }
        if let batteryPercent, !charging, batteryPercent <= lowBatteryPercent { return .lowBattery(percent: batteryPercent) }
        if lowPowerMode { return .lowPowerMode }
        return nil
    }
}

/// What the phone says about the network, the battery and the low power mode. Faked in tests.
@MainActor
protocol DeviceConditions: AnyObject {
    var isOnline: Bool { get }
    /// 0–100, nil when the phone does not say (the Simulator).
    var batteryPercent: Int? { get }
    var isCharging: Bool { get }
    var isLowPowerMode: Bool { get }
    var onChange: (@MainActor () -> Void)? { get set }
    func startWatching()
    func stopWatching()
}

/// The phone's own: `NetworkStatus`, `UIDevice`'s battery and `ProcessInfo`'s low power mode, while EarMind listens.
@MainActor
final class SystemDeviceConditions: DeviceConditions {
    private(set) var isOnline = NetworkStatus.shared.isOnline
    var onChange: (@MainActor () -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var network: Task<Void, Never>?

    var batteryPercent: Int? {
        let level = UIDevice.current.batteryLevel
        return level < 0 ? nil : Int((level * 100).rounded())
    }

    var isCharging: Bool { [.charging, .full].contains(UIDevice.current.batteryState) }
    var isLowPowerMode: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }

    func startWatching() {
        guard observers.isEmpty else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        let center = NotificationCenter.default
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification,
                     Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onChange?() }
            })
        }
        network = Task { [weak self] in
            for await online in NetworkStatus.shared.changes() {
                guard let self else { return }
                self.isOnline = online
                self.onChange?()
            }
        }
    }

    func stopWatching() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        network?.cancel()
        network = nil
    }
}
