import SwiftUI

/// D86: the app's main screen. Start (`HomeView`) when nothing is running, Lyssnar (`ListeningScreen`) while a
/// session runs; the slim indicator line is shown above Start while listening, so the microphone is never on
/// unseen. All sheets live here. Raw transcript, sources and milliseconds are only in Settings › Diagnostik.
struct ListeningView: View {
    @Bindable var model: ListeningModel
    let diagnostics: DiagnosticsModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.isActiveSession, model.showsListeningScreen {
                ListeningScreen(model: model) { model.showsListeningScreen = false }
            } else {
                VStack(spacing: 0) {
                    ListeningIndicatorBar(state: model.state,
                                          onStop: { Task { await model.endSession() } },
                                          onResume: { Task { await model.resume() } },
                                          onOpen: { model.showsListeningScreen = true })
                    HomeView(model: model)
                }
            }
        }
        .animation(.default, value: model.isActiveSession)
        .task { await model.prepareBackend() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.prepareBackend() } }
        }
        .onChange(of: model.isActiveSession) { _, active in
            if active { model.showsListeningScreen = true } // a new session opens Lyssnar
        }
        .onChange(of: model.selectedMode) { model.modeSelected() }
        .navigationDestination(isPresented: $model.isShowingDiagnostics) {
            DiagnosticsView(model: diagnostics)
        }
        .sheet(item: $model.showingMyAnswers) { route in
            MyAnswersView(model: model, route: route) // A53 (D126)
        }
        .sheet(isPresented: $model.isShowingAddExam, onDismiss: {
            Task { await model.startProvAfterExamStep() } // Ke35: Starta in Provläge asked for the exam first
        }) {
            AddExamView(model: model, forProvlage: model.startsProvAfterExamStep) { model.isShowingAddExam = false }
        }
        .sheet(item: $model.editingExam) { plan in
            AddExamView(model: model, editing: plan) { model.editingExam = nil } // A42
        }
        .sheet(isPresented: $model.isShowingInterviewSetup) {
            NavigationStack { InterviewSetupView(model: model, settings: model.modeSettings) }
        }
        .sheet(isPresented: $model.isShowingLiveStart) {
            NavigationStack { LiveStartView(model: model, settings: model.modeSettings, mode: model.selectedMode) }
        }
        .sheet(isPresented: $model.isShowingExamSetup) {
            if let materials = model.examMaterials, let client = model.examClient {
                NavigationStack { ExamSetupView(model: model, materials: materials, client: client) }
            }
        }
        .sheet(isPresented: $model.isShowingStudyOnboarding) {
            StudyOnboardingView(initial: model.studyProfile.profile) { answers in
                Task { await model.finishStudyOnboarding(answers) }
            }
        }
        .sheet(isPresented: $model.isShowingAgeGate) {
            AgeGateView { model.answerAgeGate(confirmed: $0) }
        }
        .sheet(isPresented: $model.isShowingNotes) {
            NavigationStack {
                NotesView(store: model.notes)
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Klar") { model.isShowingNotes = false } } }
            }
        }
        .sheet(isPresented: $model.isShowingCommands) {
            NavigationStack {
                CommandsView(store: model.commands)
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Klar") { model.isShowingCommands = false } } }
            }
        }
        .sheet(isPresented: $model.isShowingPrep) {
            NavigationStack {
                PrepView(store: model.prep, goals: model.goals, model: model)
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Klar") { model.isShowingPrep = false } } }
            }
        }
        .sheet(isPresented: $model.isShowingSettings) {
            NavigationStack {
                SettingsView(model: model, diagnostics: diagnostics)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Klar") { model.isShowingSettings = false } } }
            }
        }
        .sheet(isPresented: $model.isShowingPrivacy) {
            NavigationStack {
                ConsentView(mode: .review(grantedAt: model.consent.record?.grantedAt) {
                    model.isShowingPrivacy = false
                    Task { await model.withdrawConsent() }
                })
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Klar") { model.isShowingPrivacy = false } } }
            }
        }
    }
}
