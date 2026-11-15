import SwiftUI
import UIKit

// A106 (D185, Kelly Ke63 `docs/design/lasa.md`): the views of a text read aloud. The text itself (`SentenceText`),
// the texts' words in one place (`ReadingText`), and the player (`ReadingPlayerView`): like the lyrics in Musik that
// follow the song. The sentence being read is the one thing that is lit, the text scrolls with it, a tap on a
// sentence reads from there, and the system's player buttons do what the AirPods' presses do.

/// The words about a text, the same on Start, on the text's own screen and in Nytt prov (Ke63 §5).
enum ReadingText {
    static func sentences(_ n: Int) -> String { n == 1 ? "1 mening" : "\(n) meningar" }

    /// "cirka {m} min": about 15 characters a second at the normal tempo.
    static func minutes(_ parts: [ReadingParagraph]) -> Int {
        let chars = parts.reduce(0) { $0 + $1.sentences.reduce(0) { $0 + $1.count } }
        return max(1, Int((Double(chars) / 900).rounded(.up)))
    }

    static func minutes(_ drill: Drill) -> Int { minutes(drill.readingParts) }

    /// "Texten räknas som 1 fråga."
    static func countsAs(_ n: Int) -> String { "Texten räknas som \(DrillText.questions(n))." }
}

/// The text with its headings, every sentence a place to tap. With `current` the sentence being read is full colour,
/// semibold and has a soft tint behind it (grey while paused), and the others are quiet; without it (the text's own
/// screen) everything is the text colour. `scrolls`: the player's text, which keeps the sentence being read in the
/// upper third until the user scrolls away (`follows` turns false).
struct SentenceText: UIViewRepresentable {
    let parts: [ReadingParagraph]
    var current: Int? = nil
    var paused = false
    var large = false
    var scrolls = false
    var follows: Binding<Bool>? = nil
    let onTap: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let view = FollowingTextView(usingTextLayoutManager: false)
        view.isEditable = false
        view.isSelectable = false
        view.backgroundColor = .clear
        view.textContainerInset = scrolls ? UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0) : .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = scrolls
        view.showsVerticalScrollIndicator = false
        view.adjustsFontForContentSizeCategory = false
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        view.addGestureRecognizer(tap)
        view.onLayout = { [weak coordinator = context.coordinator, weak view] in
            guard let coordinator, let view else { return }
            coordinator.scrollIfWanted(view)
        }
        // VoiceOver: one text; the sentence buttons under it (the player) and Starta prov move the place.
        view.accessibilityTraits = .staticText
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        coordinator.follows = follows
        let size = context.environment.dynamicTypeSize
        if coordinator.parts != parts || coordinator.typeSize != size || coordinator.large != large {
            coordinator.parts = parts
            coordinator.typeSize = size
            coordinator.large = large
            coordinator.build(in: view)
            coordinator.shown = nil
        }
        let state = Coordinator.Shown(current: current, paused: paused)
        if coordinator.shown != state {
            let moved = coordinator.shown?.current != current
            coordinator.shown = state
            coordinator.colour(view)
            if moved { coordinator.wantsScroll = true }
        }
        if scrolls, follows?.wrappedValue != false, coordinator.wasFollowing == false { coordinator.wantsScroll = true }
        coordinator.wasFollowing = follows?.wrappedValue != false
        coordinator.scrollIfWanted(view)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard !scrolls, let width = proposal.width, width > 0, width.isFinite else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        struct Shown: Equatable {
            var current: Int?
            var paused: Bool
        }

        var parts: [ReadingParagraph] = []
        var typeSize: DynamicTypeSize?
        var large = false
        var shown: Shown?
        var onTap: ((Int) -> Void)?
        var follows: Binding<Bool>?
        var wasFollowing = true
        var wantsScroll = false
        /// Every sentence's place in the text, in reading order.
        private var ranges: [NSRange] = []
        private var headings: Set<Int> = []

        private var bodyFont: UIFont { UIFont.preferredFont(forTextStyle: large ? .title3 : .body) }
        private var currentFont: UIFont { Self.weighted(bodyFont, .semibold) }
        private var headingFont: UIFont { Self.weighted(UIFont.preferredFont(forTextStyle: large ? .title2 : .title3), .bold) }

        private static func weighted(_ font: UIFont, _ weight: UIFont.Weight) -> UIFont {
            let descriptor = font.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }

        /// The whole text once: headings bold with room above them, paragraphs with room between them.
        func build(in view: UITextView) {
            let text = NSMutableAttributedString()
            ranges = []
            headings = []
            for (p, part) in parts.enumerated() {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 3
                style.paragraphSpacing = part.isHeading ? 4 : 14
                if part.isHeading, p > 0 { style.paragraphSpacingBefore = 8 }
                let font = part.isHeading ? headingFont : bodyFont
                for (s, sentence) in part.sentences.enumerated() {
                    if s > 0 { text.append(NSAttributedString(string: " ", attributes: [.font: font, .paragraphStyle: style])) }
                    let start = text.length
                    text.append(NSAttributedString(string: sentence, attributes: [.font: font, .paragraphStyle: style,
                                                                                  .foregroundColor: UIColor.label]))
                    if part.isHeading { headings.insert(ranges.count) }
                    ranges.append(NSRange(location: start, length: text.length - start))
                }
                if p < parts.count - 1 {
                    text.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: style]))
                }
            }
            view.attributedText = text
            view.invalidateIntrinsicContentSize()
        }

        /// Only the colours, the weight and the mark change when the sentence does; the place on the screen stays.
        func colour(_ view: UITextView) {
            let storage = view.textStorage
            let current = shown?.current
            let quiet = UIColor.secondaryLabel
            storage.beginEditing()
            for (i, range) in ranges.enumerated() where range.location + range.length <= storage.length {
                let heading = headings.contains(i)
                let font = heading ? headingFont : (i == current ? currentFont : bodyFont)
                storage.addAttribute(.font, value: font, range: range)
                storage.addAttribute(.foregroundColor, value: current == nil || i == current ? UIColor.label : quiet, range: range)
                if i == current {
                    storage.addAttribute(.backgroundColor, value: shown?.paused == true ? UIColor.systemFill : Self.mark, range: range)
                } else {
                    storage.removeAttribute(.backgroundColor, range: range)
                }
            }
            storage.endEditing()
        }

        /// Ke63 `tintsoft`: the accent, soft, behind the sentence being read.
        private static let mark = UIColor { traits in
            let accent = UIColor(named: "AccentColor") ?? UIColor.systemBlue
            return accent.resolvedColor(with: traits).withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.30 : 0.14)
        }

        /// The sentence being read in the upper third (Ke63 §3.2), once the text has its size.
        func scrollIfWanted(_ view: UITextView) {
            guard wantsScroll, view.isScrollEnabled, follows?.wrappedValue != false, view.bounds.height > 0,
                  let current = shown?.current, ranges.indices.contains(current) else { return }
            let range = ranges[current]
            guard let start = view.position(from: view.beginningOfDocument, offset: range.location),
                  let end = view.position(from: start, offset: range.length),
                  let textRange = view.textRange(from: start, to: end) else { return }
            let rect = view.firstRect(for: textRange)
            guard rect.minY.isFinite, !rect.isNull else { return }
            wantsScroll = false
            let top = -view.adjustedContentInset.top
            let bottom = max(top, view.contentSize.height + view.adjustedContentInset.bottom - view.bounds.height)
            let y = min(max(rect.minY - view.bounds.height / 3, top), bottom)
            view.setContentOffset(CGPoint(x: 0, y: y), animated: !UIAccessibility.isReduceMotionEnabled && view.window != nil)
        }

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? UITextView else { return }
            let point = recognizer.location(in: view)
            guard let position = view.closestPosition(to: point) else { return }
            let offset = view.offset(from: view.beginningOfDocument, to: position)
            // The space after a sentence belongs to it; a tap under the last line is no sentence.
            guard let i = ranges.firstIndex(where: { offset >= $0.location && offset <= $0.location + $0.length }) else { return }
            onTap?(i)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if follows?.wrappedValue == true { follows?.wrappedValue = false }
        }
    }
}

/// Tells when it has been laid out, so the first scroll to the sentence waits for the text's size.
final class FollowingTextView: UITextView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

/// Ke63 `spelare.png`: Avsluta and the name, "Mening 5 av 9" with the heading and a thin line, the text, the system's
/// three player buttons and the presses as a quiet row. No microphone.
struct ReadingPlayerView: View {
    let model: RepetitionModel
    let reader: ReadingPlayer
    let drill: Drill
    @State private var follows = true
    @Environment(\.dynamicTypeSize) private var typeSize

    private var session: RepetitionSession { model.session }

    var body: some View {
        VStack(spacing: 0) {
            top
            if reader.isAtEnd {
                ended
            } else {
                text
            }
        }
        .safeAreaInset(edge: .bottom) { bottom }
        .background(Color(.systemBackground))
        .onChange(of: reader.currentHeading) { follows = true } // Ke63 §3.2: the next heading takes the text back
    }

    // MARK: Top

    private var place: String { "Mening \(min(reader.sentenceIndex + 1, reader.sentenceCount)) av \(reader.sentenceCount)" }

    private var top: some View {
        VStack(spacing: 10) {
            ZStack {
                Text(verbatim: drill.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 84)
                    .accessibilityHidden(typeSize.isAccessibilitySize)
                    .opacity(typeSize.isAccessibilitySize ? 0 : 1)
                HStack {
                    Button("Avsluta") { model.end() }
                        .accessibilityHint("Avslutar uppläsningen. Du fortsätter från samma mening nästa gång.")
                    Spacer()
                }
            }
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: place).monospacedDigit()
                    Spacer(minLength: 8)
                    if let heading = reader.currentHeading, !typeSize.isAccessibilitySize {
                        Text(verbatim: heading).lineLimit(1)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                ProgressView(value: Double(min(reader.sentenceIndex + 1, reader.sentenceCount)),
                             total: Double(max(reader.sentenceCount, 1)))
                    .tint(Color.primary)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: The text

    private var text: some View {
        SentenceText(parts: reader.parts, current: reader.sentenceIndex, paused: reader.isPaused, large: true,
                     scrolls: true, follows: $follows) { sentence in
            follows = true
            session.read(from: sentence)
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .bottomTrailing) {
            if !follows {
                Button {
                    follows = true
                } label: {
                    Label("Till meningen", systemImage: "arrow.up.and.down.text.horizontal")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .background(.regularMaterial, in: Capsule())
                .padding(.trailing, 16)
                .padding(.bottom, 12)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .accessibilityLabel(reader.currentSentence ?? "")
        .accessibilityAction(named: "Nästa mening") { session.press(.short) }
        .accessibilityAction(named: "Förra meningen") { session.press(.pauseToggle) }
    }

    /// Ke63 `spelare-slut.png`: the text does not start over by itself.
    private var ended: some View {
        ContentUnavailableView {
            Label("Slut på texten", systemImage: "text.alignleft")
        } description: {
            Text("Du har lyssnat igenom hela \(drill.title).")
        } actions: {
            Button {
                follows = true
                session.readFromStart()
            } label: {
                FilledButtonLabel { Text("Börja om").font(.headline).padding(.horizontal, 24) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Bottom

    /// What the screen says under the text: paused, waiting for the sound, or nothing.
    private var statusLine: String? {
        if reader.isAtEnd { return nil }
        if reader.isPaused { return "Pausad. Fortsätter från början av meningen." }
        if reader.phase == .waitingForAudio {
            if let problem = model.audio.problem(for: drill) { return problem }
            return model.isOffline ? "Ingen internetanslutning. Resten av texten kommer när du är uppkopplad." : "Gör ljud …"
        }
        return nil
    }

    private var bottom: some View {
        VStack(spacing: 12) {
            if let statusLine {
                Text(verbatim: statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !reader.isAtEnd {
                HStack(spacing: 44) {
                    control("backward.fill", "Förra meningen", size: 26) { session.press(.pauseToggle) }
                    control(reader.isPaused ? "play.fill" : "pause.fill", reader.isPaused ? "Fortsätt" : "Pausa", size: 44) {
                        session.press(.long)
                    }
                    .frame(minWidth: 64, minHeight: 64)
                    control("forward.fill", "Nästa mening", size: 26) { session.press(.short) }
                }
                .foregroundStyle(Color.primary)
            }
            PressesRow(titles: presses)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(Color(.systemBackground))
    }

    /// Ke63 §5: what the AirPods' presses do now.
    private var presses: [(event: RepetitionEvent, dots: Int, title: String)] {
        let previous: (event: RepetitionEvent, dots: Int, title: String) = (.pauseToggle, 3, "Förra meningen")
        if reader.isAtEnd { return [(event: .long, dots: 1, title: "Börja om"), previous] }
        return [(event: .long, dots: 1, title: reader.isPaused ? "Fortsätt" : "Paus"),
                (event: .short, dots: 2, title: "Nästa mening"), previous]
    }

    private func control(_ symbol: String, _ label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
