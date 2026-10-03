import ActivityKit
import Foundation
import Observation

/// Runs one timed-habit session at a time, survives the app being closed, and mirrors it on the Lock Screen.
@MainActor
@Observable
final class TimerController {
    static let shared = TimerController()

    struct Session: Codable, Equatable {
        var habitID: UUID
        var slotID: UUID?
        var day: DayKey
        var minutes: Int
        var start: Date
        var end: Date
        /// Seconds left when paused.
        var pausedRemaining: TimeInterval?

        var isPaused: Bool { pausedRemaining != nil }
        var total: TimeInterval { TimeInterval(minutes * 60) }

        func remaining(at now: Date) -> TimeInterval {
            if let pausedRemaining { return pausedRemaining }
            return max(0, end.timeIntervalSince(now))
        }
    }

    private(set) var session: Session?
    /// Set when a session finishes, so the timer screen can show its completion moment.
    private(set) var finished: UUID?

    @ObservationIgnored private var activity: Activity<TimerActivityAttributes>?
    @ObservationIgnored private let storageKey = "activeTimerSession"

    init() {
        if let raw = UserDefaults.standard.data(forKey: storageKey) {
            session = try? JSONDecoder().decode(Session.self, from: raw)
        }
        activity = Activity<TimerActivityAttributes>.activities.first
    }

    func isRunning(habitID: UUID) -> Bool { session?.habitID == habitID }

    func start(habit: Habit, slotID: UUID?, day: DayKey) {
        if let current = session, current.habitID != habit.id { cancel() }
        if session?.habitID == habit.id { return }
        let minutes = max(1, habit.target)
        let now = Date()
        let new = Session(habitID: habit.id, slotID: slotID, day: day, minutes: minutes, start: now, end: now.addingTimeInterval(TimeInterval(minutes * 60)))
        session = new
        finished = nil
        persist()
        Task { await ReminderScheduler.scheduleTimerEnd(habitName: habit.name, habitID: habit.id, at: new.end) }
        startActivity(habit: habit, session: new)
    }

    func togglePause() {
        guard var current = session else { return }
        let now = Date()
        if let remaining = current.pausedRemaining {
            current.end = now.addingTimeInterval(remaining)
            current.pausedRemaining = nil
            if let name = AppStore.shared.habit(current.habitID)?.name {
                let end = current.end, id = current.habitID
                Task { await ReminderScheduler.scheduleTimerEnd(habitName: name, habitID: id, at: end) }
            }
        } else {
            current.pausedRemaining = current.remaining(at: now)
            ReminderScheduler.cancelTimerEnd(habitID: current.habitID)
        }
        session = current
        persist()
        updateActivity(current)
    }

    /// Logs the session. Ending early still counts as the minimum, because showing up matters.
    func finish(store: AppStore, early: Bool = false) {
        guard let current = session, let habit = store.habit(current.habitID) else { cancel(); return }
        let now = Date()
        if early {
            let elapsed = Int((current.total - current.remaining(at: now)) / 60)
            if elapsed >= current.minutes {
                store.complete(habit, slotID: current.slotID, on: current.day, minutes: current.minutes, at: now)
            } else {
                store.logMinimum(habit, on: current.day)
            }
        } else {
            let at = min(now, current.end)
            store.complete(habit, slotID: current.slotID, on: current.day, minutes: current.minutes, at: at)
        }
        finished = current.habitID
        clear()
    }

    func cancel() {
        clear()
    }

    func acknowledgeFinish() { finished = nil }

    /// Called when the app becomes active: a session that ran out while away is logged now.
    func resumeIfNeeded(store: AppStore) {
        guard let current = session, current.pausedRemaining == nil, current.end <= Date() else { return }
        finish(store: store)
    }

    private func clear() {
        if let current = session { ReminderScheduler.cancelTimerEnd(habitID: current.habitID) }
        session = nil
        persist()
        endActivity()
    }

    private func persist() {
        if let session, let raw = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(raw, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    // MARK: Live Activity

    private func startActivity(habit: Habit, session: Session) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endActivity()
        let attributes = TimerActivityAttributes(habitName: habit.name, symbol: habit.symbol, colorName: habit.color.rawValue, minutes: session.minutes)
        let state = TimerActivityAttributes.ContentState(start: session.start, end: session.end, pausedRemaining: nil)
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: session.end.addingTimeInterval(60)))
    }

    private func updateActivity(_ session: Session) {
        guard let activity else { return }
        let state = TimerActivityAttributes.ContentState(start: session.start, end: session.end, pausedRemaining: session.pausedRemaining)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private func endActivity() {
        let all = Activity<TimerActivityAttributes>.activities
        activity = nil
        for running in all {
            Task { await running.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
