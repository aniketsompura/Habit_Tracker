import Foundation

/// Parts of the day the Today screen groups habits into.
public enum DayPeriod: Int, CaseIterable, Comparable, Sendable {
    case anytime, earlyMorning, morning, afternoon, evening, night

    /// The app's day starts at 3:30 am, so late-night times count as the end of the day.
    public static let dayStartMinutes = 210

    public static func of(_ time: TimeOfDay) -> DayPeriod {
        switch time.minutes {
        case 210..<360: return .earlyMorning
        case 360..<720: return .morning
        case 720..<1020: return .afternoon
        case 1020..<1260: return .evening
        default: return .night
        }
    }

    public var title: String {
        switch self {
        case .anytime: return "Through the day"
        case .earlyMorning: return "Early morning"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    public var caption: String {
        switch self {
        case .anytime: return "Whenever it fits"
        case .earlyMorning: return "Before dawn · 3:30 – 6:00"
        case .morning: return "6:00 – 12:00"
        case .afternoon: return "12:00 – 5:00"
        case .evening: return "5:00 – 9:00"
        case .night: return "After 9:00"
        }
    }

    public var symbol: String {
        switch self {
        case .anytime: return "circle.dotted"
        case .earlyMorning: return "moon.stars"
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "sunset"
        case .night: return "moon"
        }
    }

    public static func < (lhs: DayPeriod, rhs: DayPeriod) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One thing to do today: a habit at one of its preferred times.
public struct AgendaItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var habitID: UUID
    public var kind: HabitKind
    public var slotID: UUID?
    public var time: TimeOfDay?
    public var period: DayPeriod
    public var done: Bool
    /// Count habits: units so far today.
    public var amount: Int
    /// Count habits: daily target.
    public var target: Int
    public var order: Int
}

public struct DaySummary: Equatable, Sendable {
    public var done: Int
    public var total: Int
    public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
    public var isComplete: Bool { total > 0 && done >= total }
}

extension Engine {
    /// The day's items in time order. Habits appear once they've started; quit habits always count as lit until a slip.
    public func agenda(on day: DayKey) -> [AgendaItem] {
        var items: [AgendaItem] = []
        for habit in data.activeHabits where habit.isScheduled(on: day) && startDay(habit) <= day {
            let p = self.progress(habit, on: day)
            switch habit.kind {
            case .check, .timed:
                if habit.slots.isEmpty {
                    items.append(AgendaItem(id: habit.id.uuidString, habitID: habit.id, kind: habit.kind, slotID: nil, time: nil, period: .anytime,
                                            done: p.isComplete, amount: p.done, target: 1, order: habit.order))
                } else {
                    let doneSlots = doneSlotIDs(habit, on: day)
                    for slot in habit.sortedSlots {
                        items.append(AgendaItem(id: "\(habit.id.uuidString)|\(slot.id.uuidString)", habitID: habit.id, kind: habit.kind, slotID: slot.id,
                                                time: slot.time, period: .of(slot.time), done: doneSlots.contains(slot.id),
                                                amount: doneSlots.contains(slot.id) ? 1 : 0, target: 1, order: habit.order))
                    }
                }
            case .count:
                // One slot places the habit at that time; several make it an all-day habit with nudges.
                let time = habit.slots.count == 1 ? habit.slots[0].time : nil
                items.append(AgendaItem(id: habit.id.uuidString, habitID: habit.id, kind: .count, slotID: nil, time: time,
                                        period: time.map(DayPeriod.of) ?? .anytime, done: p.isComplete,
                                        amount: p.done, target: p.required, order: habit.order))
            case .quit:
                let time = habit.sortedSlots.first?.time
                items.append(AgendaItem(id: habit.id.uuidString, habitID: habit.id, kind: .quit, slotID: nil, time: time,
                                        period: time.map(DayPeriod.of) ?? .anytime, done: !p.slipped,
                                        amount: p.slipped ? 0 : 1, target: 1, order: habit.order))
            }
        }
        return items.sorted { a, b in
            if a.period != b.period { return a.period < b.period }
            let ta = a.time?.dayOrder ?? -1, tb = b.time?.dayOrder ?? -1
            if ta != tb { return ta < tb }
            if a.order != b.order { return a.order < b.order }
            return a.id < b.id
        }
    }

    public func summary(on day: DayKey) -> DaySummary {
        let items = agenda(on: day)
        return DaySummary(done: items.filter(\.done).count, total: items.count)
    }

    /// The next open item: the first one due from 30 minutes ago onward, else the earliest overdue one.
    public func upNext(on day: DayKey, now: TimeOfDay) -> AgendaItem? {
        let open = agenda(on: day).filter { !$0.done && $0.kind != .quit }
        let timed = open.filter { $0.time != nil }
        if let next = timed.first(where: { $0.time!.dayOrder >= now.dayOrder - 30 }) { return next }
        return timed.first ?? open.first
    }

    /// Habits whose last scheduled day was missed, so today decides whether the chain survives.
    public func atRiskHabits() -> [Habit] {
        data.activeHabits.filter { habit in
            guard habit.isScheduled(on: today), !progress(habit, on: today).status.isKept else { return false }
            return stats(habit).streak.atRisk
        }
    }
}
