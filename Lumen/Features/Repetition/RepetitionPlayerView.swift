import SwiftUI

/// A80 (D142), rebuilt in A87 (D160, Kelly Ke53 `apple/spelar.png`): the playing screen, like Spelas nu in Podcaster.
/// "Fråga 2 av 5" and the exam's name on one line, a thin progress line, the question big, what happens now (a ring
/// for the thinking time, "Långt svar"/"Kort svar", "Gör ljudet …", "Pausad"), the three presses as a quiet row and
/// Avsluta as an ordinary button: the only way to end. No buttons for the answers (rule 2): the AirPods steer, the
/// phone ends. While paused the whole screen is a button that goes on.
struct RepetitionPlayerView: View {
    let model: RepetitionModel

    private var session: RepetitionSession { model.session }
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // A106 (D185): a text read aloud has its own screen (the text with the sentence being read marked).
        if let reader = session.reader, let drill = session.drill {
            ReadingPlayerView(model: model, reader: reader, drill: drill)
        } else {
            questions
        }
    }

    private var questions: some View {
        Group {
            if typeSize.isAccessibilitySize { compact } else { regular }
        }
        .safeAreaInset(edge: .bottom) { bottom }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            // Kelly Ke49: while paused, a tap anywhere but Avsluta goes on.
            if session.player?.isPaused == true { session.press(.long) }
        }
    }

    /// Kelly S2 (the largest text, iPhone SE): nothing scrolls and nothing is hidden. The question, then the one line
    /// that says what to do (N1, or how to go on from a pause), then Avsluta. The ring is the text "6 s" on the first
    /// row, and the three presses are not shown here (they are on the control check and in VoiceOver's actions).
    private var compact: some View {
        VStack(spacing: 12) {
            if let player = session.player, let drill = session.drill {
                header(player, drill)
                question(player, drill, compact: true)
                compactLine(player)
            } else {
                Spacer()
                Text(verbatim: endedLine).foregroundStyle(LumenColor.secondaryText)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func compactLine(_ player: RepetitionPlayer) -> some View {
        Group {
            if player.isPaused {
                Text("Tryck på AirPods för att fortsätta")
            } else {
                switch player.phase {
                case .thinking:
                    if player.isFirstLap, player.lap == 0 { Text("Tryck på AirPods för svaret") } // Kelly N1
                case .answer(_, let kind):
                    Text(kind == .long ? String(localized: "Långt svar") : String(localized: "Kort svar")).foregroundStyle(LumenColor.secondaryText)
                case .waitingForAudio:
                    if let soundProblem {
                        // A100 (K62). Kelly: the question stays the biggest thing on the screen, so this long
                        // sentence stops growing at the first accessibility size.
                        Text(verbatim: soundProblem)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    } else {
                        Text("Gör ljudet …").foregroundStyle(LumenColor.secondaryText)
                    }
                case .question, .idle:
                    EmptyView()
                }
            }
        }
        .font(.headline)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    /// The question and what happens now scroll when they are taller than the screen; the presses and Avsluta stay
    /// at the bottom.
    private var regular: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    if let player = session.player, let drill = session.drill {
                        header(player, drill)
                        Spacer(minLength: 0)
                        question(player, drill, compact: false)
                        status(player)
                        Spacer(minLength: 0)
                    } else {
                        Spacer()
                        Text(verbatim: endedLine).foregroundStyle(LumenColor.secondaryText)
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The three presses and Avsluta, fixed at the bottom and capped like the system's bars.
    private var bottom: some View {
        VStack(spacing: 16) {
            // Kelly Q6: no presses to make while the player waits for a sound that cannot be made.
            if !typeSize.isAccessibilitySize, !waitsWithoutSound, let player = session.player, session.drill != nil {
                PressesRow(paused: player.isPaused, lit: lit(player))
            }
            if stepsByHand {
                // A112b (D200, Kelly U4): no sound, so the way to the next question is on the screen, in words.
                HStack(spacing: 12) {
                    Button { session.stepQuestion(by: -1) } label: {
                        Label("Förra frågan", systemImage: "backward.fill").frame(maxWidth: .infinity)
                    }
                    .disabled(session.player?.index == 0) // Kelly: nothing is before the first question
                    Button { session.stepQuestion(by: 1) } label: {
                        Label("Nästa fråga", systemImage: "forward.fill").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .font(.headline)
                .labelStyle(.titleOnly)
            }
            Button {
                model.end()
            } label: {
                Text("Avsluta").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Color.primary)
            .accessibilityHint("Avslutar provet. Du kan fortsätta där du var nästa gång.")
            .accessibilityShowsLargeContentViewer() // A95: the bar is capped at the first accessibility size
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(Color(.systemBackground))
    }

    /// "Ljudet kan inte göras just nu. Försök igen om en stund." while the player waits for a sound that is not
    /// coming (the credits ran out in the middle of an exam).
    private var soundProblem: String? {
        session.drill.flatMap { model.audio.problem(for: $0) }
    }

    /// A112b (D200): reading aloud is off and this question has no sound: the answer is on the screen and the
    /// questions are stepped by hand.
    private var stepsByHand: Bool {
        guard let player = session.player, let drill = session.drill, case .waitingForAudio = player.phase else { return false }
        return model.soundIsNotComing(drill)
    }

    private var waitsWithoutSound: Bool {
        guard let player = session.player, case .waitingForAudio = player.phase else { return false }
        return soundProblem != nil
    }

    /// Ke50 §8: "Sparat på fråga {7}." after Avsluta.
    private var endedLine: String {
        if let saved = RepetitionProgress.load() { return String(localized: "Sparat på fråga \(saved.index + 1).") }
        return String(localized: "Provet är avslutat.")
    }

    private func lit(_ player: RepetitionPlayer) -> RepetitionEvent? {
        switch player.phase {
        case .answer(_, .long): .long
        case .answer(_, .short): .short
        default: player.isPaused ? .pauseToggle : nil
        }
    }

    private func header(_ player: RepetitionPlayer, _ drill: Drill) -> some View {
        // Kelly R-granskning: "Varv" from lap 2.
        let place = String(localized: "Fråga \(player.index + 1) av \(player.count)") + (player.lap > 0 ? String(localized: " · Varv \(player.lap + 1)") : "")
        return VStack(spacing: 8) {
            Group {
                if typeSize.isAccessibilitySize {
                    // Kelly S2: the thinking time as "6 s" on this row, and "Pausad" while paused.
                    Group {
                        if player.isPaused {
                            Text(verbatim: place + String(localized: " · Pausad"))
                        } else if case .thinking = player.phase {
                            ThinkingSeconds(prefix: place, started: player.thinkingStarted ?? Date(),
                                            seconds: player.thinkingSeconds)
                        } else {
                            Text(verbatim: place)
                        }
                    }
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: place).fontWeight(.semibold).monospacedDigit()
                        Spacer(minLength: 8)
                        Text(verbatim: drill.title).lineLimit(1)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(LumenColor.secondaryText)
            ProgressView(value: Double(player.index + 1), total: Double(max(player.count, 1)))
                .tint(Color.primary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func question(_ player: RepetitionPlayer, _ drill: Drill, compact: Bool) -> some View {
        let item = drill.items.indices.contains(player.index) ? drill.items[player.index] : nil
        return VStack(spacing: 14) {
            Text(verbatim: item?.shownQuestion ?? "") // A102: as written on the screen
                .font(.largeTitle.bold())
                .foregroundStyle(player.isPaused ? Color.secondary : Color.primary)
                .multilineTextAlignment(.center)
                // Compact: the question shrinks to the room it has; otherwise it keeps its size and the screen scrolls.
                .minimumScaleFactor(compact ? 0.4 : 0.7)
                .fixedSize(horizontal: false, vertical: !compact)
                .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil)
                .accessibilityAddTraits(.isHeader) // A95
                // Kelly R4: no answer buttons on the screen; VoiceOver still has the three as actions.
                .accessibilityAction(named: "Långt svar") { session.press(.long) }
                .accessibilityAction(named: "Kort svar") { session.press(.short) }
                .accessibilityAction(named: player.isPaused ? String(localized: "Fortsätt") : String(localized: "Paus")) { session.press(.pauseToggle) }
            if !compact, case .answer(_, let kind) = player.phase, let item, !player.isPaused {
                Text(verbatim: kind == .short ? item.shownShort : item.shownLong) // A102
                    .foregroundStyle(LumenColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
                    // Ke79: VoiceOver says which answer it is before the answer.
                    .accessibilityLabel("\(kind == .short ? String(localized: "Kort svar") : String(localized: "Långt svar")): \(kind == .short ? item.shownShort : item.shownLong)")
            } else if case .waitingForAudio = player.phase, let item, model.soundIsNotComing(drill) {
                // A112 (D200): reading aloud is off for now, so the answer is here as text. With the largest text it
                // scrolls in the room it has (it was cut off after two lines on iPhone SE).
                if compact {
                    ScrollView {
                        Text(verbatim: item.shownLong).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                } else {
                    Text(verbatim: item.shownLong)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func status(_ player: RepetitionPlayer) -> some View {
        if player.isPaused {
            VStack(spacing: 8) {
                Image(systemName: "pause.circle.fill").font(.system(size: 56)).foregroundStyle(LumenColor.secondaryText)
                    .accessibilityHidden(true) // A95: "Pausad" is the next line
                Text("Pausad").font(.subheadline.weight(.semibold)).foregroundStyle(LumenColor.secondaryText)
                Text("Tryck på AirPods för att fortsätta")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Fortsätter från början av meningen")
                    .font(.subheadline)
                    .foregroundStyle(LumenColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        } else {
            switch player.phase {
            case .thinking:
                VStack(spacing: 12) {
                    ThinkingRing(started: player.thinkingStarted ?? Date(), seconds: player.thinkingSeconds)
                    if player.isFirstLap, player.lap == 0 {
                        Text("Tryck på AirPods för svaret").font(.headline) // Kelly N1
                    } else {
                        Text("Tänk").font(.headline).foregroundStyle(LumenColor.secondaryText)
                    }
                }
            case .answer(_, let kind):
                Label(kind == .long ? String(localized: "Långt svar") : String(localized: "Kort svar"), systemImage: "waveform")
                    .font(.headline)
                    .foregroundStyle(LumenColor.secondaryText)
                    .accessibilityElement(children: .ignore) // A95: the words, not the symbol's name
                    .accessibilityLabel(kind == .long ? String(localized: "Långt svar") : String(localized: "Kort svar"))
            case .waitingForAudio:
                if let soundProblem {
                    // A100 (K62): no spinner that never ends when the sound cannot be made; Avsluta is below.
                    // A112 (D200): the calm line is quiet; another problem with the sound stays a headline.
                    Text(verbatim: soundProblem)
                        .font(session.drill.map(model.isReadingAloudOff) == true ? .subheadline : .headline)
                        .foregroundStyle(session.drill.map(model.isReadingAloudOff) == true ? Color.secondary : Color.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // A107 (D190): the sound is made at Starta prov, so the wait shows how far it has come.
                    let made = session.drill.map { model.progress($0) }
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Gör ljudet …")
                        }
                        if let made, made.total > 0, made.ready < made.total {
                            ProgressView(value: Double(made.ready), total: Double(made.total))
                                .frame(maxWidth: 220)
                                .accessibilityHidden(true)
                            Text(verbatim: String(localized: "\(made.ready) av \(made.total) klara")).font(.footnote).monospacedDigit()
                        }
                    }
                    .foregroundStyle(LumenColor.secondaryText)
                    .accessibilityElement(children: .combine)
                }
            case .question, .idle:
                Color.clear.frame(height: 1)
            }
        }
    }
}

/// The thinking time as text ("Fråga 1 av 5 · 6 s"), for the accessibility sizes where the ring has no room.
private struct ThinkingSeconds: View {
    let prefix: String
    let started: Date
    let seconds: Double

    var body: some View {
        let prefix = self.prefix
        let started = self.started
        let seconds = self.seconds
        return TimelineView(.periodic(from: started, by: 0.5)) { context in
            let left = min(seconds, max(0, seconds - context.date.timeIntervalSince(started)))
            Text(verbatim: String(localized: "\(prefix) · \(max(1, Int(left.rounded(.up)))) s"))
        }
    }
}

/// The thinking time counting down, with the seconds in the middle. The ring is information, not decoration
/// (SYSTEM §0.5), and it is drawn in the text colour, not the accent.
private struct ThinkingRing: View {
    let started: Date
    let seconds: Double

    var body: some View {
        let started = self.started
        let seconds = self.seconds
        return TimelineView(.periodic(from: started, by: 0.1)) { context in
            let left = min(seconds, max(0, seconds - context.date.timeIntervalSince(started)))
            ZStack {
                Circle().stroke(Color(.systemFill), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: seconds > 0 ? left / seconds : 0)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: "\(max(1, Int(left.rounded(.up))))") // Kelly B3: counts down to 1, never 0
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: 88, height: 88)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Betänketid") // A95: the line under it says "Tänk" or what to press
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Kelly Ke49 §4.1: the presses in the same order everywhere, dots as the symbol (no AirPods pictures, 5.2.5).
struct PressesRow: View {
    var paused = false
    var lit: RepetitionEvent?
    /// A106 (Ke63): the presses of a text read aloud (Paus, Nästa mening, Förra meningen). Nil = the questions'.
    var titles: [(event: RepetitionEvent, dots: Int, title: String)]? = nil
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        let layout = size >= .accessibility1 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 16))
        layout {
            if let titles {
                ForEach(titles, id: \.dots) { item($0.event, $0.dots, $0.title) }
            } else {
                item(.long, 1, String(localized: "Långt svar"))
                item(.short, 2, String(localized: "Kort svar"))
                item(.pauseToggle, 3, paused ? String(localized: "Fortsätt") : String(localized: "Paus"))
            }
        }
        .frame(maxWidth: .infinity)
        // Ke79: once, as one sentence ("Långt svar: 1 tryck. Kort svar: 2 tryck. Paus: 3 tryck."). Combined, each row
        // was read twice (its own label and its texts).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isStaticText) // Ke79 round 5: it is read, not pressed
    }

    private var spoken: String {
        let rows = titles?.map { (dots: $0.dots, title: $0.title) }
            ?? [(1, String(localized: "Långt svar")), (2, String(localized: "Kort svar")), (3, paused ? String(localized: "Fortsätt") : String(localized: "Paus"))]
        return rows.map { String(localized: "\($0.title): \($0.dots) tryck.") }.joined(separator: " ")
    }

    private func item(_ event: RepetitionEvent, _ dots: Int, _ title: String) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: String(repeating: "●", count: dots)).font(.caption2)
            Text(verbatim: title).font(.footnote.weight(lit == event ? .semibold : .regular))
        }
        .foregroundStyle(lit == event ? Color.primary : Color.secondary)
        .accessibilityLabel("\(title), \(dots) tryck på AirPods")
    }
}
