import Foundation

/// Every change to a day's log goes through these, so the app, widgets and notification buttons behave the same.
extension AppData {
    private func doneEntries(_ habitID: UUID, _ day: DayKey) -> [LogEntry] {
        record(for: day).entries.filter { $0.habitID == habitID && $0.kind == .done }
    }

    /// The first preferred time that isn't done yet, in time order.
    public func firstOpenSlot(_ habit: Habit, on day: DayKey) -> UUID? {
        let done = Engine(data: AppData(habits: [habit], days: [day.raw: record(for: day)]), today: day).doneSlotIDs(habit, on: day)
        return habit.sortedSlots.first { !done.contains($0.id) }?.id
    }

    /// Marks a preferred time done (check or timed), or adds to the count. Returns false when nothing changed.
    @discardableResult
    public mutating func complete(habitID: UUID, slotID: UUID?, day: DayKey, at: Date = Date(), amount: Int = 1) -> Bool {
        guard let habit = habit(habitID) else { return false }
        switch habit.kind {
        case .check, .timed:
            if habit.slots.isEmpty {
                guard doneEntries(habitID, day).isEmpty else { return false }
                updateRecord(day) { $0.entries.append(LogEntry(habitID: habitID, kind: .done, amount: max(1, amount), at: at)) }
                return true
            }
            let target: UUID?
            if let slotID, habit.slots.contains(where: { $0.id == slotID }) {
                target = slotID
            } else {
                target = firstOpenSlot(habit, on: day)
            }
            guard let slot = target else { return false }
            let engine = Engine(data: AppData(habits: [habit], days: [day.raw: record(for: day)]), today: day)
            guard !engine.doneSlotIDs(habit, on: day).contains(slot) else { return false }
            updateRecord(day) { $0.entries.append(LogEntry(habitID: habitID, kind: .done, slotID: slot, amount: max(1, amount), at: at)) }
            return true
        case .count:
            updateRecord(day) { $0.entries.append(LogEntry(habitID: habitID, kind: .done, amount: max(1, amount), at: at)) }
            return true
        case .quit:
            return false
        }
    }

    /// Removes the latest completion for a habit (and preferred time, when given). Clears a minimum if that's all there is.
    @discardableResult
    public mutating func undo(habitID: UUID, slotID: UUID?, day: DayKey) -> Bool {
        var changed = false
        updateRecord(day) { record in
            let matches = record.entries.indices.filter { i in
                let e = record.entries[i]
                return e.habitID == habitID && e.kind == .done && (slotID == nil || e.slotID == slotID || e.slotID == nil)
            }
            if let last = matches.last {
                record.entries.remove(at: last)
                changed = true
            } else if let minimum = record.entries.lastIndex(where: { $0.habitID == habitID && $0.kind == .minimum }) {
                record.entries.remove(at: minimum)
                changed = true
            }
        }
        return changed
    }

    /// Logs the small version for a hard day. It keeps the chain without pretending the full habit was done.
    @discardableResult
    public mutating func logMinimum(habitID: UUID, day: DayKey, at: Date = Date()) -> Bool {
        guard let habit = habit(habitID), habit.kind != .quit else { return false }
        guard !record(for: day).entries.contains(where: { $0.habitID == habitID && $0.kind == .minimum }) else { return false }
        updateRecord(day) { $0.entries.append(LogEntry(habitID: habitID, kind: .minimum, amount: 0, at: at)) }
        return true
    }

    @discardableResult
    public mutating func logSlip(habitID: UUID, day: DayKey, at: Date = Date()) -> Bool {
        guard let habit = habit(habitID), habit.kind == .quit else { return false }
        guard !record(for: day).entries.contains(where: { $0.habitID == habitID && $0.kind == .slip }) else { return false }
        updateRecord(day) { $0.entries.append(LogEntry(habitID: habitID, kind: .slip, amount: 0, at: at)) }
        return true
    }

    @discardableResult
    public mutating func clearSlip(habitID: UUID, day: DayKey) -> Bool {
        var changed = false
        updateRecord(day) { record in
            let before = record.entries.count
            record.entries.removeAll { $0.habitID == habitID && $0.kind == .slip }
            changed = record.entries.count != before
        }
        return changed
    }

    /// Deletes a habit and every check-in it had.
    public mutating func deleteHabit(_ id: UUID) {
        habits.removeAll { $0.id == id }
        for (key, var record) in days {
            record.entries.removeAll { $0.habitID == id }
            if record.focusHabitID == id { record.focusHabitID = nil }
            days[key] = record.isEmpty ? nil : record
        }
    }
}
