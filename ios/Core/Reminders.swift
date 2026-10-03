import Foundation

public enum ReminderKind: String, Codable, Sendable {
    case check, count, timed, quit, followUp, morning, evening
}

/// A local notification the app wants pending. The scheduler turns these into real requests.
public struct PlannedReminder: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var title: String
    public var body: String
    public var kind: ReminderKind
    public var habitID: UUID?
    public var slotID: UUID?
    public var day: DayKey
}

public enum ReminderPlanner {
    /// iOS keeps at most 64 pending notifications per app; a few are left for snoozes and timers.
    public static let limit = 58
    /// Identifier prefix for planned reminders, so rescheduling never touches snoozes or timers.
    public static let prefix = "plan."

    /// Upcoming reminders over the next days, soonest first, skipping anything already done.
    public static func plan(data: AppData, now: Date, horizonDays: Int = 7, calendar: Calendar = .hexis) -> [PlannedReminder] {
        let today = DayKey(now, calendar: calendar)
        let engine = Engine(data: data, today: today)
        let prefs = data.preferences
        let atRisk = Set(engine.atRiskHabits().map(\.id))
        var out: [PlannedReminder] = []

        for offset in 0..<max(1, horizonDays) {
            let day = today.adding(offset)
            let record = data.record(for: day)

            if prefs.morningRitual && !record.hasSankalpa {
                let fire = day.date(at: prefs.morningTime, calendar: calendar)
                if fire > now {
                    out.append(PlannedReminder(id: "\(prefix)morning.\(day.raw)", fireDate: fire, title: "Set your Sankalpa",
                                               body: "One intention and one habit that can't slip today. It takes 20 seconds.",
                                               kind: .morning, habitID: nil, slotID: nil, day: day))
                }
            }
            if prefs.eveningReview && record.review == nil {
                let fire = day.date(at: prefs.eveningTime, calendar: calendar)
                if fire > now {
                    out.append(PlannedReminder(id: "\(prefix)evening.\(day.raw)", fireDate: fire, title: "Evening review",
                                               body: "Seneca asked himself three questions every night. Take two minutes for yours.",
                                               kind: .evening, habitID: nil, slotID: nil, day: day))
                }
            }

            for habit in data.activeHabits where habit.isScheduled(on: day) {
                let progress = engine.progress(habit, on: day)
                let risky = offset == 0 && atRisk.contains(habit.id)
                switch habit.kind {
                case .check, .timed:
                    if progress.minimumLogged { continue }
                    let done = engine.doneSlotIDs(habit, on: day)
                    for slot in habit.sortedSlots where slot.remind && !done.contains(slot.id) {
                        let fire = day.date(at: slot.time, calendar: calendar)
                        let base = "\(habit.id.uuidString).\(slot.id.uuidString).\(day.raw)"
                        if fire > now {
                            let text = ReminderText.main(habit, atRisk: risky)
                            out.append(PlannedReminder(id: "\(prefix)\(habit.kind.rawValue).\(base)", fireDate: fire, title: text.title, body: text.body,
                                                       kind: habit.kind == .timed ? .timed : .check, habitID: habit.id, slotID: slot.id, day: day))
                        }
                        if prefs.followUps {
                            let follow = fire.addingTimeInterval(Double(prefs.followUpMinutes) * 60)
                            if follow > now && DayKey(follow, calendar: calendar) == day {
                                let text = ReminderText.followUp(habit)
                                out.append(PlannedReminder(id: "\(prefix)follow.\(base)", fireDate: follow, title: text.title, body: text.body,
                                                           kind: .followUp, habitID: habit.id, slotID: slot.id, day: day))
                            }
                        }
                    }
                case .count:
                    if progress.isComplete || progress.minimumLogged { continue }
                    for slot in habit.sortedSlots where slot.remind {
                        let fire = day.date(at: slot.time, calendar: calendar)
                        guard fire > now else { continue }
                        let remaining = offset == 0 ? progress.required - progress.done : progress.required
                        let text = ReminderText.count(habit, remaining: remaining, firstOfDay: offset > 0)
                        out.append(PlannedReminder(id: "\(prefix)count.\(habit.id.uuidString).\(slot.id.uuidString).\(day.raw)", fireDate: fire,
                                                   title: text.title, body: text.body, kind: .count, habitID: habit.id, slotID: slot.id, day: day))
                    }
                case .quit:
                    if progress.slipped { continue }
                    for slot in habit.sortedSlots where slot.remind {
                        let fire = day.date(at: slot.time, calendar: calendar)
                        guard fire > now else { continue }
                        let text = ReminderText.quit(habit)
                        out.append(PlannedReminder(id: "\(prefix)quit.\(habit.id.uuidString).\(slot.id.uuidString).\(day.raw)", fireDate: fire,
                                                   title: text.title, body: text.body, kind: .quit, habitID: habit.id, slotID: slot.id, day: day))
                    }
                }
            }
        }
        return Array(out.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }
}

/// Reminder wording. It leans on when-then plans, identity and the minimum version rather than guilt.
public enum ReminderText {
    public static func main(_ habit: Habit, atRisk: Bool) -> (title: String, body: String) {
        var lines: [String] = []
        if atRisk { lines.append("You missed last time. Never miss twice.") }
        let plan = whenThen(habit)
        if !plan.isEmpty { lines.append(plan) }
        if habit.kind == .timed { lines.append("\(habit.target) minutes. Tap Start when you're ready.") }
        let identity = habit.identity.trimmed
        if !identity.isEmpty { lines.append("Another vote for being \(identity).") }
        if !habit.treat.trimmed.isEmpty { lines.append("Pair it with \(habit.treat.trimmed).") }
        if lines.isEmpty { lines.append("It's time.") }
        return (habit.name, lines.joined(separator: " "))
    }

    public static func followUp(_ habit: Habit) -> (title: String, body: String) {
        let minimum = habit.minimum.trimmed
        let body = minimum.isEmpty
            ? "Still open. Even a little counts today."
            : "Hard day? Do the minimum: \(minimum). It keeps the chain."
        return ("\(habit.name) is still open", body)
    }

    public static func count(_ habit: Habit, remaining: Int, firstOfDay: Bool) -> (title: String, body: String) {
        let unit = habit.unitLabel
        if firstOfDay || remaining >= habit.dailyRequirement {
            return (habit.name, "Today's aim: \(habit.dailyRequirement) \(unit). Start with one.")
        }
        return (habit.name, "\(remaining) \(unit) to go today.")
    }

    public static func quit(_ habit: Habit) -> (title: String, body: String) {
        ("Stay strong: \(habit.name)", "This is your risky time. If an urge comes, breathe and wait ten minutes. It passes.")
    }

    /// "After I make coffee, read 20 minutes on the balcony."
    public static func whenThen(_ habit: Habit) -> String {
        let cue = habit.cue.trimmed
        let place = habit.place.trimmed
        guard !cue.isEmpty || !place.isEmpty else { return "" }
        var sentence = cue.isEmpty ? habit.name : "After \(cue), \(habit.name.lowercasedFirst)"
        if !place.isEmpty { sentence += " \(place)" }
        return sentence + "."
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// "Read 20 minutes" becomes "read 20 minutes"; names with other capitals, like "Surya Namaskar", stay as they are.
    var lowercasedFirst: String {
        guard let first = first else { return self }
        if dropFirst().contains(where: \.isUppercase) { return self }
        return first.lowercased() + dropFirst()
    }
}
