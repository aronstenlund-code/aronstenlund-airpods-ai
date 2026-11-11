import SwiftUI

/// A54 (D127, Kevin K39, Kelly Ke31): "Hjälp oss välja logga". A sheet when the app opens, after the intro and the
/// first answer (so D124's Start is understood first). The three candidates in the same size, in an order shuffled
/// once per user (the place should not steer the vote), tap to choose, "Rösta" and "Senare". Senare brings it back
/// after 2 days, at most 3 times, then never again. After the vote: thanks, and the percent per logo when there are at
/// least 20 votes (the server decides, K39). One vote per user; nothing else about the user is sent.
enum LogoChoice: String, CaseIterable, Codable, Sendable {
    case a = "A", b = "B", c = "C", d = "D", e = "E", f = "F" // A71 (D129/D130): six candidates, K41

    /// Ke31/Ke40: the names under the icons, nothing that favours one.
    var name: String {
        switch self {
        case .a: "Klotet"
        case .b: "Den gröna formen"
        case .c: "Den orange ringen"
        case .d: "Glasklotet"
        case .e: "Glasringen"
        case .f: "Glasvågen"
        }
    }

    var imageName: String { "LogoVote\(rawValue)" }
}

/// When the sheet comes (pure; UserDefaults keeps it).
struct LogoVoteSchedule: Equatable, Sendable {
    static let laterLimit = 3
    static let laterDelay: TimeInterval = 2 * 86_400

    var voted = false
    var laterCount = 0
    var nextAt: Date?
    /// The order shown to this user, shuffled once.
    var order: [LogoChoice] = []

    /// After the intro and the first answer; never after a vote or the third "Senare".
    func shouldShow(now: Date, hasAnswered: Bool) -> Bool {
        guard hasAnswered, !voted, laterCount < Self.laterLimit else { return false }
        if let nextAt { return now >= nextAt }
        return true
    }

    mutating func later(now: Date) {
        laterCount += 1
        nextAt = now.addingTimeInterval(Self.laterDelay)
    }

    mutating func ensureOrder<G: RandomNumberGenerator>(using generator: inout G) {
        if Set(order) != Set(LogoChoice.allCases) || order.count != LogoChoice.allCases.count {
            order = LogoChoice.allCases.shuffled(using: &generator)
        }
    }

    static let key = "a54.logoVote"

    static func load(_ defaults: UserDefaults = .standard) -> LogoVoteSchedule {
        guard let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(Stored.self, from: data) else {
            return LogoVoteSchedule()
        }
        return LogoVoteSchedule(voted: value.voted, laterCount: value.laterCount, nextAt: value.nextAt,
                                order: value.order.compactMap(LogoChoice.init(rawValue:)))
    }

    func save(_ defaults: UserDefaults = .standard) {
        let stored = Stored(voted: voted, laterCount: laterCount, nextAt: nextAt, order: order.map(\.rawValue))
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: Self.key) }
    }

    private struct Stored: Codable {
        var voted: Bool
        var laterCount: Int
        var nextAt: Date?
        var order: [String]
    }
}

/// `/logo-vote` (K39).
@MainActor
final class LogoVoteClient {
    struct Reply: Decodable, Equatable, Sendable {
        struct Results: Decodable, Equatable, Sendable {
            var total: Int
            var percent: [String: Double]
        }
        var choice: String?
        var results: Results?
    }

    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    /// Nil when it could not be sent (the sheet says so and keeps the choice).
    func vote(_ choice: LogoChoice) async -> Reply? {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.logoVoteURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            request.httpBody = try JSONEncoder().encode(["choice": choice.rawValue])
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                Log.answer.error("logo-vote: HTTP \(response.statusCode, privacy: .public)")
                return nil
            }
            return try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            return nil
        }
    }
}

struct LogoVoteSheet: View {
    let order: [LogoChoice]
    let vote: (LogoChoice) async -> LogoVoteClient.Reply?
    let onVoted: () -> Void
    let onLater: () -> Void
    /// The Simulator screenshot of the thanks.
    var demoReply: LogoVoteClient.Reply? = nil

    @State private var chosen: LogoChoice?
    @State private var isSending = false
    @State private var reply: LogoVoteClient.Reply?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let reply { thanks(reply) } else { ballot }
                }
                .padding(20)
            }
            .lumenScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if reply != nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if reply == nil { buttons }
            }
        }
        .interactiveDismissDisabled(reply == nil) // "Senare" says what a close means
        .onAppear { if let demoReply { reply = demoReply } }
    }

    private var ballot: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hjälp oss välja logga")
                    .font(LumenFont.text(28, .bold, relativeTo: .title))
                    .accessibilityAddTraits(.isHeader)
                Text("Vilken tycker du bäst om? Tryck på en.")
                    .font(LumenFont.text(17))
                    .foregroundStyle(LumenColor.muted)
            }
            // A71: six in a grid, three to a row (two at the largest text sizes).
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                                count: typeSize.isAccessibilitySize ? 2 : 3)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(order, id: \.self) { choice in candidate(choice) }
            }
            .frame(maxWidth: .infinity)
            if failed {
                Text("Rösten kom inte fram. Försök igen om en stund.")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.red)
            }
        }
    }

    private func candidate(_ choice: LogoChoice) -> some View {
        let selected = chosen == choice
        return Button {
            chosen = choice
        } label: {
            VStack(spacing: 8) {
                LogoTile(choice: choice, size: 96)
                    .overlay {
                        RoundedRectangle(cornerRadius: 96 * 0.2237 + 4, style: .continuous)
                            .strokeBorder(selected ? LumenColor.blue : .clear, lineWidth: 3)
                            .padding(-4)
                    }
                Text(choice.name)
                    .font(LumenFont.text(14, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? LumenColor.ink : LumenColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? LumenColor.blue : LumenColor.line)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Logga \(choice.rawValue), \(choice.name)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var buttons: some View {
        VStack(spacing: 6) {
            Button {
                Task { await send() }
            } label: {
                if isSending { ProgressView().tint(LumenColor.onBlue) } else { Text("Rösta") }
            }
            .buttonStyle(LumenButtonStyle(height: 54))
            .disabled(chosen == nil || isSending)
            Button("Senare") {
                onLater()
                dismiss()
            }
            .font(LumenFont.text(17, .semibold))
            .foregroundStyle(LumenColor.muted)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(LumenColor.background)
    }

    private func send() async {
        guard let chosen else { return }
        isSending = true
        failed = false
        let answer = await vote(chosen)
        isSending = false
        guard let answer else {
            failed = true
            return
        }
        onVoted()
        withAnimation { reply = answer }
    }

    @ViewBuilder
    private func thanks(_ reply: LogoVoteClient.Reply) -> some View {
        Text("Tack för din röst")
            .font(LumenFont.text(28, .bold, relativeTo: .title))
            .accessibilityAddTraits(.isHeader)
        if let results = reply.results, results.total > 0 {
            Text("Så här har \(results.total) personer röstat hittills.")
                .font(LumenFont.text(17))
                .foregroundStyle(LumenColor.muted)
            VStack(spacing: 14) {
                ForEach(order, id: \.self) { choice in
                    let percent = results.percent[choice.rawValue] ?? 0
                    HStack(spacing: 12) {
                        LogoTile(choice: choice, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(choice.name).font(LumenFont.text(15, choice.rawValue == reply.choice ? .semibold : .regular))
                                Spacer()
                                Text("\(Int(percent.rounded())) %").font(LumenFont.text(15, .semibold)).monospacedDigit()
                            }
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(LumenColor.soft)
                                    Capsule().fill(LumenColor.blue).frame(width: geometry.size.width * min(1, max(0, percent / 100)))
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(choice.name): \(Int(percent.rounded())) procent")
                }
            }
        } else {
            Text("Vi visar hur alla har röstat när fler har hunnit rösta.")
                .font(LumenFont.text(17))
                .foregroundStyle(LumenColor.muted)
        }
    }
}

/// A71 (Ke40): the app's mark in the header and the intro: the exact app icon, small, with iOS's mask corners (a
/// one-colour symbol could not be the exact picture). Follows the text size where the caller scales `size`.
struct AppMark: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = UIImage(named: "AppMark") {
                Image(uiImage: image).resizable().interpolation(.high)
            } else {
                LumenColor.surface
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A candidate as iOS shows an app icon (Ke31: the mask's corners, continuous).
struct LogoTile: View {
    let choice: LogoChoice
    let size: CGFloat

    var body: some View {
        Group {
            if let image = UIImage(named: choice.imageName) {
                Image(uiImage: image).resizable().interpolation(.high)
            } else {
                LumenColor.surface
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        .accessibilityHidden(true)
    }
}
