import Foundation
import WidgetKit

/// A44 (N2): the home screen widget's snapshot. Written when the plan, the streak or the exams change; the widget
/// reloads only when something it shows has changed.
extension ListeningModel {
    func updateWidget(now: Date = Date()) {
        let nearest = examPlans?.upcoming(now: now).first
        let snapshot = ExamWidgetSnapshot(examName: nearest?.name, examDate: nearest?.date,
                                          streak: streak.current, doneToday: streak.doneToday,
                                          readyPct: nearest.flatMap { readiness(for: $0)?.readyPct }, updatedAt: now)
        let old = ExamWidgetSnapshot.load()
        guard Self.widgetChanged(old, snapshot) else { return }
        snapshot.save()
        WidgetCenter.shared.reloadTimelines(ofKind: ExamWidgetSnapshot.kind)
    }

    /// The time alone is no change, except a new day (the streak's "today" moves).
    nonisolated static func widgetChanged(_ old: ExamWidgetSnapshot?, _ new: ExamWidgetSnapshot, calendar: Calendar = .current) -> Bool {
        guard var old else { return true }
        if !calendar.isDate(old.updatedAt, inSameDayAs: new.updatedAt) { return true }
        old.updatedAt = new.updatedAt
        return old != new
    }

    /// "Förhör mig" on the widget: the quiz for the nearest exam, or Provläge without one.
    func quizFromShortcut() async {
        await controller.waitForForeground()
        if let nearest = examPlans?.upcoming().first {
            await startQuiz(for: nearest)
        } else if !study.isActive {
            await startStudy()
        }
    }
}
