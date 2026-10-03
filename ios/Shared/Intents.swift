import AppIntents
import Foundation
import WidgetKit

/// Completes a habit straight from a widget.
struct CompleteHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete habit"
    static let isDiscoverable = false

    @Parameter(title: "Habit") var habitID: String
    @Parameter(title: "Time") var slotID: String

    init() {}

    init(habitID: UUID, slotID: UUID?) {
        self.habitID = habitID.uuidString
        self.slotID = slotID?.uuidString ?? ""
    }

    func perform() async throws -> some IntentResult {
        guard let habit = UUID(uuidString: habitID) else { return .result() }
        var data = DataFile.load()
        let changed = data.complete(habitID: habit, slotID: UUID(uuidString: slotID), day: .today())
        if changed {
            try DataFile.save(data)
            await ReminderScheduler.reschedule(data)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

/// Opens the app on a timed habit's timer.
struct OpenTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start habit timer"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Habit") var habitID: String
    @Parameter(title: "Time") var slotID: String

    init() {}

    init(habitID: UUID, slotID: UUID?) {
        self.habitID = habitID.uuidString
        self.slotID = slotID?.uuidString ?? ""
    }

    func perform() async throws -> some IntentResult {
        SharedDefaults.pendingRoute = "timer|\(habitID)|\(slotID)"
        return .result()
    }
}
