import Foundation
import UserNotifications

/// Turns the reminder plan into pending local notifications with Done, +1, Minimum and Snooze buttons.
enum ReminderScheduler {
    enum Category {
        static let check = "SADHANA_CHECK"
        static let count = "SADHANA_COUNT"
        static let timed = "SADHANA_TIMED"
        static let quit = "SADHANA_QUIT"
        static let followUp = "SADHANA_FOLLOW"
        static let ritual = "SADHANA_RITUAL"
    }

    enum Action {
        static let done = "done"
        static let plusOne = "plusOne"
        static let minimum = "minimum"
        static let snooze = "snooze"
        static let start = "start"
        static let holding = "holding"
        static let slip = "slip"
    }

    enum Key {
        static let habit = "habit"
        static let slot = "slot"
        static let day = "day"
        static let kind = "kind"
    }

    static let snoozeMinutes = 15

    static func registerCategories() {
        let done = UNNotificationAction(identifier: Action.done, title: "Done", options: [])
        let plusOne = UNNotificationAction(identifier: Action.plusOne, title: "+1", options: [])
        let minimum = UNNotificationAction(identifier: Action.minimum, title: "Did the minimum", options: [])
        let snooze = UNNotificationAction(identifier: Action.snooze, title: "Snooze \(snoozeMinutes) min", options: [])
        let start = UNNotificationAction(identifier: Action.start, title: "Start timer", options: [.foreground])
        let holding = UNNotificationAction(identifier: Action.holding, title: "Holding strong", options: [])
        let slip = UNNotificationAction(identifier: Action.slip, title: "I slipped", options: [.foreground])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Category.check, actions: [done, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.count, actions: [plusOne, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.timed, actions: [start, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.quit, actions: [holding, slip], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.followUp, actions: [done, minimum, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.ritual, actions: [], intentIdentifiers: []),
        ])
    }

    static func category(for kind: ReminderKind) -> String {
        switch kind {
        case .check: return Category.check
        case .count: return Category.count
        case .timed: return Category.timed
        case .quit: return Category.quit
        case .followUp: return Category.followUp
        case .morning, .evening: return Category.ritual
        }
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Replaces every planned reminder with a fresh plan. Snoozes and timer alerts are left alone.
    static func reschedule(_ data: AppData, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(ReminderPlanner.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let calendar = Calendar.sadhana
        for reminder in ReminderPlanner.plan(data: data, now: now, calendar: calendar) {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.categoryIdentifier = category(for: reminder.kind)
            content.threadIdentifier = reminder.habitID?.uuidString ?? "rituals"
            var info: [String: String] = [Key.day: reminder.day.raw, Key.kind: reminder.kind.rawValue]
            if let habit = reminder.habitID { info[Key.habit] = habit.uuidString }
            if let slot = reminder.slotID { info[Key.slot] = slot.uuidString }
            content.userInfo = info
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    /// Re-sends a reminder in 15 minutes.
    static func snooze(_ content: UNNotificationContent) async {
        guard let copy = content.mutableCopy() as? UNMutableNotificationContent else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(snoozeMinutes * 60), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "snooze.\(UUID().uuidString)", content: copy, trigger: trigger))
    }

    static func scheduleTimerEnd(habitName: String, habitID: UUID, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "\(habitName) complete"
        content.body = "Your session is done. Open Sadhana to see the lamp lit."
        content.sound = .default
        content.userInfo = [Key.habit: habitID.uuidString, Key.kind: "timerEnd"]
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "timer.\(habitID.uuidString)", content: content, trigger: trigger))
    }

    static func cancelTimerEnd(habitID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer.\(habitID.uuidString)"])
    }
}
