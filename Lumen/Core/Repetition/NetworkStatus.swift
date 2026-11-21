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

    private var listeners: [UUID: AsyncStream<Bool>.Continuation] = [:]

    private func update(_ satisfied: Bool, kind: String) {
        lock.lock()
        let changed = self.satisfied != satisfied
        self.satisfied = satisfied
        self.kind = kind
        let targets = changed ? Array(listeners.values) : []
        lock.unlock()
        for listener in targets { listener.yield(satisfied) }
    }

    /// A103: online (true) or not, now and at every change, for a view that says it before the user tries.
    func changes() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            listeners[id] = continuation
            let now = satisfied
            lock.unlock()
            continuation.yield(now)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.listeners[id] = nil
                self.lock.unlock()
            }
        }
    }

    /// A103 (Angela Fable A104, for Kelly): the one wording for "this needs the network and there is none".
    static let noNetworkLine = String(localized: "Ingen internetanslutning. Försök igen när du är uppkopplad.")

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
