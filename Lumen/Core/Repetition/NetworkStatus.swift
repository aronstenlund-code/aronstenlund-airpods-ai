import Foundation
import Network

/// A85 (Aron 22:13): "Ingen internetanslutning" only when the phone really has no network. A dropped connection on
/// 5G (`.networkConnectionLost`) is a failed request, not an offline phone.
final class NetworkStatus: @unchecked Sendable {
    static let shared = NetworkStatus()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var satisfied = true
    private var kind = "unknown"

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let kind = path.usesInterfaceType(.wifi) ? "wifi" : path.usesInterfaceType(.cellular) ? "cellular"
                : path.usesInterfaceType(.wiredEthernet) ? "wired" : "other"
            self?.update(path.status == .satisfied, kind: kind)
        }
        monitor.start(queue: DispatchQueue(label: "earmind.network-status"))
    }

    private func update(_ satisfied: Bool, kind: String) {
        lock.lock()
        self.satisfied = satisfied
        self.kind = kind
        lock.unlock()
    }

    /// True until the monitor has said otherwise (a request is tried rather than refused on a guess).
    var isOnline: Bool {
        lock.lock()
        defer { lock.unlock() }
        return satisfied
    }

    /// "wifi", "cellular" … for the log.
    var interface: String {
        lock.lock()
        defer { lock.unlock() }
        return kind
    }
}
