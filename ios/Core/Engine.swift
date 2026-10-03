import Foundation

public enum DayStatus: String, Sendable {
    case future
    /// Before the habit existed.
    case notStarted
    /// Not scheduled and nothing logged.
    case rest
    /// Done on a day it wasn't scheduled. Counts as a vote, never breaks a chain.
    case extra
    case done
    /// The small version was done. Keeps the chain.
    case minimum
    /// Started today but not finished yet.
    case partial
    /// Today, nothing yet.
    case pending
    /// A past scheduled day that wasn't kept.
    case missed
    /// Quit habit, today, no slip so far.
    case holding
    /// Quit habit, a past day without a slip.
    case clean
    case slipped

    public var isKept: Bool { self == .done || self == .minimum || self == .clean }
    public var isMiss: Bool { self == .missed || self == .slipped }
    public var isVote: Bool { isKept || self == .extra }
}

public struct DayProgress: Equatable, Sendable {
    public var done: Int
    public var required: Int
    public var minimumLogged: Bool
    public var slipped: Bool
    public var scheduled: Bool
    public var status: DayStatus

    public var fraction: Double { required == 0 ? 0 : min(1, Double(done) / Double(required)) }
    public var isComplete: Bool { done >= required }
}

public struct StreakInfo: Equatable, Sendable {
    /// Kept days in the current chain. One missed day in a row is forgiven; two break it.
    public var current: Int = 0
    public var best: Int = 0
    /// The last scheduled day was missed, so missing today would break the chain.
    public var atRisk: Bool = false
}

public struct TimingInsight: Equatable, Sendable {
    public var slotID: UUID
    public var planned: TimeOfDay
    /// When it usually happens, rounded to 5 minutes.
    public var typical: TimeOfDay
    /// Typical minus planned, in minutes.
    public var drift: Int
    public var samples: Int
}

public struct HabitStats: Equatable, Sendable {
    public var streak: StreakInfo
    /// Every kept or extra day is a vote for who the habit makes you.
    public var votes: Int
    public var kept30: Int
    public var scheduled30: Int
    public var timing: [TimingInsight]

    public var rate30: Double? { scheduled30 == 0 ? nil : Double(kept30) / Double(scheduled30) }
    /// Beads on the current 108-bead mala.
    public var malaBeads: Int { votes % 108 }
    /// Completed malas of 108 votes.
    public var malas: Int { votes / 108 }
}

/// Entries indexed by habit and day.
public struct Ledger: Sendable {
    private var index: [UUID: [Int: [LogEntry]]] = [:]
    private var firstDay: [UUID: Int] = [:]

    public init(_ data: AppData) {
        for (raw, record) in data.days {
            guard let key = DayKey(raw: raw) else { continue }
            for entry in record.entries {
                index[entry.habitID, default: [:]][key.jdn, default: []].append(entry)
                firstDay[entry.habitID] = min(firstDay[entry.habitID] ?? Int.max, key.jdn)
            }
        }
    }

    public func entries(_ habitID: UUID, on day: DayKey) -> [LogEntry] { index[habitID]?[day.jdn] ?? [] }

    public func firstLogDay(_ habitID: UUID) -> DayKey? { firstDay[habitID].map(DayKey.init(jdn:)) }
}

/// Answers every question the screens ask about progress, for one snapshot of data and one "today".
public struct Engine: Sendable {
    public let data: AppData
    public let today: DayKey
    public let ledger: Ledger

    public init(data: AppData, today: DayKey) {
        self.data = data
        self.today = today
        self.ledger = Ledger(data)
    }

    /// The habit's first day: when it was created, or its earliest log if that is earlier.
    public func startDay(_ habit: Habit) -> DayKey {
        guard let first = ledger.firstLogDay(habit.id) else { return habit.createdOn }
        return min(first, habit.createdOn)
    }

    /// Which preferred times are done on a day. Entries without a time fill the earliest open ones.
    public func doneSlotIDs(_ habit: Habit, on day: DayKey) -> Set<UUID> {
        let entries = ledger.entries(habit.id, on: day).filter { $0.kind == .done }
        let slots = habit.sortedSlots
        let valid = Set(slots.map(\.id))
        var done = Set<UUID>()
        var loose = 0
        for entry in entries {
            if let slot = entry.slotID, valid.contains(slot) { done.insert(slot) } else { loose += 1 }
        }
        for slot in slots where loose > 0 && !done.contains(slot.id) {
            done.insert(slot.id)
            loose -= 1
        }
        return done
    }

    public func progress(_ habit: Habit, on day: DayKey) -> DayProgress {
        let entries = ledger.entries(habit.id, on: day)
        let scheduled = habit.isScheduled(on: day)
        let minimum = entries.contains { $0.kind == .minimum }
        let slipped = entries.contains { $0.kind == .slip }
        let required = habit.dailyRequirement
        var done: Int
        switch habit.kind {
        case .check, .timed:
            if habit.slots.isEmpty {
                done = entries.contains { $0.kind == .done } ? 1 : 0
            } else {
                done = doneSlotIDs(habit, on: day).count
            }
        case .count:
            done = entries.filter { $0.kind == .done }.reduce(0) { $0 + max(0, $1.amount) }
        case .quit:
            done = slipped ? 0 : 1
        }

        let status: DayStatus
        if day > today {
            status = .future
        } else if day < startDay(habit) {
            status = .notStarted
        } else if habit.kind == .quit {
            if slipped { status = .slipped }
            else if !scheduled { status = .rest }
            else if day == today { status = .holding }
            else { status = .clean }
        } else if done >= required {
            status = scheduled ? .done : .extra
        } else if minimum {
            status = scheduled ? .minimum : .extra
        } else if !scheduled {
            status = .rest
        } else if day == today {
            status = done > 0 ? .partial : .pending
        } else {
            status = .missed
        }
        return DayProgress(done: done, required: required, minimumLogged: minimum, slipped: slipped, scheduled: scheduled, status: status)
    }

    public func stats(_ habit: Habit) -> HabitStats {
        let start = startDay(habit)
        let from30 = today.adding(-29)
        var run = 0, best = 0, misses = 0, votes = 0, kept30 = 0, scheduled30 = 0
        var day = start
        while day <= today {
            let status = progress(habit, on: day).status
            if status.isVote { votes += 1 }
            if status.isKept {
                run += 1
                misses = 0
            } else if status.isMiss {
                misses += 1
                if misses >= 2 { run = 0 }
            }
            best = max(best, run)
            if day >= from30 {
                if status.isKept { kept30 += 1; scheduled30 += 1 } else if status.isMiss { scheduled30 += 1 }
            }
            day = day.adding(1)
        }
        let streak = StreakInfo(current: run, best: best, atRisk: misses == 1)
        return HabitStats(streak: streak, votes: votes, kept30: kept30, scheduled30: scheduled30, timing: timing(habit))
    }

    /// Where actual check-in times drift from the plan by 20 minutes or more, over the last six weeks.
    public func timing(_ habit: Habit, calendar: Calendar = .sadhana) -> [TimingInsight] {
        guard habit.kind == .check || habit.kind == .timed else { return [] }
        var insights: [TimingInsight] = []
        let from = today.adding(-41)
        for slot in habit.sortedSlots {
            var diffs: [Int] = []
            var day = from
            while day <= today {
                for entry in ledger.entries(habit.id, on: day) where entry.kind == .done && entry.slotID == slot.id {
                    var started = entry.at
                    if habit.kind == .timed { started = started.addingTimeInterval(-Double(max(0, entry.amount)) * 60) }
                    var diff = TimeOfDay(started, calendar: calendar).minutes - slot.time.minutes
                    if diff > 720 { diff -= 1440 } else if diff < -720 { diff += 1440 }
                    diffs.append(diff)
                }
                day = day.adding(1)
            }
            guard diffs.count >= 5 else { continue }
            let median = diffs.sorted()[diffs.count / 2]
            guard abs(median) >= 20 else { continue }
            let rounded = Int((Double(median) / 5).rounded()) * 5
            insights.append(TimingInsight(slotID: slot.id, planned: slot.time, typical: slot.time.adding(minutes: rounded), drift: rounded, samples: diffs.count))
        }
        return insights
    }

    /// Share of scheduled habit-days kept between two days. Today only counts once it's kept.
    public func rate(from: DayKey, to: DayKey) -> (kept: Int, scheduled: Int) {
        var kept = 0, scheduled = 0
        for habit in data.activeHabits {
            var day = max(from, startDay(habit))
            while day <= to {
                let status = progress(habit, on: day).status
                if status.isKept { kept += 1; scheduled += 1 } else if status.isMiss { scheduled += 1 }
                day = day.adding(1)
            }
        }
        return (kept, scheduled)
    }

    public func freshStart(on day: DayKey) -> FreshStart? {
        let prefs = data.preferences
        if let m = prefs.birthdayMonth, let d = prefs.birthdayDay, m == day.month, d == day.day { return .birthday }
        if day.month == 1 && day.day == 1 { return .year }
        if day.day == 1 { return .month }
        if day.weekday == 2 { return .week }
        return nil
    }
}

public enum FreshStart: String, Sendable {
    case week, month, year, birthday
}
