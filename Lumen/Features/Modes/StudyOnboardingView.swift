import SwiftUI

/// D83: Provläge's first start. One question per screen, multiple choice, "Hoppa över" on each screen and
/// "Hoppa över allt". The answers go into Minne and with every Provläge call.
struct StudyOnboardingView: View {
    let onDone: (StudyProfile) -> Void
    @State private var profile: StudyProfile
    @State private var step = 0
    @State private var pickingDate = false
    @State private var laterDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var customSubject = ""
    @Environment(\.dismiss) private var dismiss

    private static let steps = 5

    init(initial: StudyProfile, onDone: @escaping (StudyProfile) -> Void) {
        self.onDone = onDone
        _profile = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                ProgressView(value: Double(step + 1), total: Double(Self.steps))
                Text(title).font(.title2.bold())
                ScrollView {
                    VStack(spacing: 10) { options }
                }
                Spacer(minLength: 0)
                HStack {
                    Button("Hoppa över allt") { finish() }
                    Spacer()
                    Button("Hoppa över") { next() }
                }
                .font(.subheadline)
            }
            .padding(24)
            .navigationTitle("Provläge")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private var title: String {
        switch step {
        case 0: "När har du ditt prov?"
        case 1: "Vilken årskurs går du i?"
        case 2: "Vilket ämne?"
        case 3: "Kontrollfrågor?"
        default: "Hur långa förklaringar?"
        }
    }

    @ViewBuilder
    private var options: some View {
        switch step {
        case 0:
            choice("Idag") { setExam(.today) }
            choice("Imorgon") { setExam(.tomorrow) }
            choice("Inom en vecka") { setExam(.withinWeek) }
            choice("Senare") { pickingDate = true }
            if pickingDate {
                DatePicker("Datum", selection: $laterDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "sv_SE"))
                Button("Välj datumet") {
                    profile.examDate = Calendar.current.startOfDay(for: laterDate)
                    profile.noExam = false
                    next()
                }
                .buttonStyle(.borderedProminent)
            }
            choice("Inget prov just nu") {
                profile.noExam = true
                profile.examDate = nil
                next()
            }
        case 1:
            ForEach(StudyProfile.Grade.allCases, id: \.self) { grade in
                choice(StudyProfile.gradeName(grade)) {
                    profile.grade = grade
                    if ![.gy1, .gy2, .gy3].contains(grade) { next() }
                }
            }
            if let grade = profile.grade, [.gy1, .gy2, .gy3].contains(grade) {
                TextField("Kurs (valfritt), t.ex. Matematik 1c", text: $profile.course)
                    .textFieldStyle(.roundedBorder)
                Button("Nästa") { next() }.buttonStyle(.borderedProminent)
            }
        case 2:
            ForEach(StudyProfile.subjects, id: \.self) { subject in
                choice(subject) {
                    profile.subject = subject
                    next()
                }
            }
            TextField("Annat ämne", text: $customSubject)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    let subject = customSubject.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !subject.isEmpty else { return }
                    profile.subject = subject
                    next()
                }
        case 3:
            ForEach(StudyProfile.CheckQuestions.allCases, id: \.self) { check in
                choice(StudyProfile.checkName(check)) {
                    profile.checkQuestions = check
                    next()
                }
            }
        default:
            ForEach(StudyProfile.Explanations.allCases, id: \.self) { length in
                choice(StudyProfile.explanationName(length)) {
                    profile.explanations = length
                    next()
                }
            }
        }
    }

    private func choice(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }

    private func setExam(_ when: StudyProfile.ExamWhen) {
        profile.examDate = StudyProfile.examDate(for: when, now: Date())
        profile.noExam = false
        next()
    }

    private func next() {
        pickingDate = false
        if step + 1 >= Self.steps { finish() } else { step += 1 }
    }

    private func finish() {
        dismiss()
        onDone(profile)
    }
}
