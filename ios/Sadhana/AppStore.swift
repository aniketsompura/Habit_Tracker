import Foundation
import Observation
import SwiftUI
import WidgetKit

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var quote: Quote?
    var symbol: String = "sparkles"
}

enum Route: Identifiable, Equatable {
    case sankalpa
    case review
    case timer(habitID: UUID, slotID: UUID?)
    case editHabit(UUID)
    case newHabit

    var id: String {
        switch self {
        case .sankalpa: return "sankalpa"
        case .review: return "review"
        case .timer(let h, let s): return "timer-\(h)-\(s?.uuidString ?? "")"
        case .editHabit(let h): return "edit-\(h)"
        case .newHabit: return "new"
        }
    }
}

enum AppTab: Hashable {
    case today, habits, journey, wisdom
}

/// The single source of truth for the app. Every change saves to disk, refreshes reminders and reloads widgets.
@MainActor
@Observable
final class AppStore {
    static let shared = AppStore()

    private(set) var data: AppData
    private(set) var today: DayKey
    private(set) var engine: Engine
    var tab: AppTab = .today
    var route: Route?
    var toast: Toast?
    /// Bumped when the last lamp of the day is lit.
    var celebration = 0

    let quotes = QuoteBook.shared

    @ObservationIgnored private var loadedAt: Date?
    @ObservationIgnored private var statsCache: [UUID: HabitStats] = [:]
    @ObservationIgnored private var rescheduleTask: Task<Void, Never>?

    init() {
        let loaded = DataFile.load()
        let day = DayKey.today()
        data = loaded
        today = day
        engine = Engine(data: loaded, today: day)
        loadedAt = DataFile.modificationDate()
    }

    var prefs: Preferences { data.preferences }
    var tradition: Tradition { data.preferences.tradition }

    // MARK: Lifecycle

    /// Picks up changes widgets made while the app was in the background, and rolls over at midnight.
    func refresh() {
        let modified = DataFile.modificationDate()
        if modified != loadedAt {
            data = DataFile.load()
            loadedAt = modified
        }
        today = DayKey.today()
        engine = Engine(data: data, today: today)
        statsCache = [:]
    }

    func scheduleReminders() {
        rescheduleTask?.cancel()
        let snapshot = data
        rescheduleTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await ReminderScheduler.reschedule(snapshot)
        }
    }

    /// Applies a change, then saves, refreshes reminders and widgets, and celebrates a completed day.
    func mutate(_ change: (inout AppData) -> Void) {
        refresh()
        let before = engine.summary(on: today)
        var copy = data
        change(&copy)
        guard copy != data else { return }
        data = copy
        engine = Engine(data: data, today: today)
        statsCache = [:]
        do {
            try DataFile.save(data)
            loadedAt = DataFile.modificationDate()
        } catch {
            toast = Toast(message: "Couldn't save that change. Try again.", symbol: "exclamationmark.triangle")
        }
        scheduleReminders()
        WidgetCenter.shared.reloadAllTimelines()
        let after = engine.summary(on: today)
        if !before.isComplete && after.isComplete { celebration += 1 }
    }

    /// Streak, votes and rates for a habit, cached until the data changes.
    func stats(_ habit: Habit) -> HabitStats {
        if let cached = statsCache[habit.id] { return cached }
        let computed = engine.stats(habit)
        statsCache[habit.id] = computed
        return computed
    }

    // MARK: Quotes

    func quote(_ moment: QuoteMoment, salt: Int = 0) -> Quote {
        quotes.pick(moment, on: today, tradition: tradition, salt: salt)
    }

    var dailyQuote: Quote { quotes.daily(on: today, tradition: tradition) }

    func isFavorite(_ quote: Quote) -> Bool { data.favoriteQuotes.contains(quote.id) }

    func toggleFavorite(_ quote: Quote) {
        mutate { data in
            if let i = data.favoriteQuotes.firstIndex(of: quote.id) { data.favoriteQuotes.remove(at: i) } else { data.favoriteQuotes.append(quote.id) }
        }
    }

    // MARK: Logging

    func habit(_ id: UUID) -> Habit? { data.habit(id) }

    /// The main tap on a lamp: light it, add one, or open the timer.
    func tap(_ item: AgendaItem, on day: DayKey) {
        guard let habit = habit(item.habitID) else { return }
        switch habit.kind {
        case .check:
            if item.done { undo(item, on: day) } else { complete(habit, slotID: item.slotID, on: day) }
        case .count:
            mutate { $0.complete(habitID: habit.id, slotID: nil, day: day) }
        case .timed:
            if item.done { undo(item, on: day) } else if day == today { route = .timer(habitID: habit.id, slotID: item.slotID) } else { complete(habit, slotID: item.slotID, on: day) }
        case .quit:
            if item.done { slip(habit, on: day) } else { mutate { $0.clearSlip(habitID: habit.id, day: day) } }
        }
    }

    func complete(_ habit: Habit, slotID: UUID?, on day: DayKey, minutes: Int? = nil, at date: Date = Date()) {
        mutate { $0.complete(habitID: habit.id, slotID: slotID, day: day, at: date, amount: minutes ?? 1) }
    }

    func undo(_ item: AgendaItem, on day: DayKey) {
        mutate { $0.undo(habitID: item.habitID, slotID: item.slotID, day: day) }
    }

    func decrement(_ habit: Habit, on day: DayKey) {
        mutate { $0.undo(habitID: habit.id, slotID: nil, day: day) }
    }

    func logMinimum(_ habit: Habit, on day: DayKey) {
        mutate { $0.logMinimum(habitID: habit.id, day: day) }
        toast = Toast(message: "The minimum counts. Your chain is safe.", quote: quote(.minimum), symbol: "leaf")
    }

    func slip(_ habit: Habit, on day: DayKey) {
        mutate { $0.logSlip(habitID: habit.id, day: day) }
        toast = Toast(message: "Logged honestly. That's the practice. Begin again now.", quote: quote(.slip), symbol: "arrow.uturn.backward")
    }

    // MARK: Habits

    func save(_ habit: Habit, isNew: Bool) {
        mutate { $0.upsert(habit) }
        if isNew {
            toast = Toast(message: "\(habit.name) added. Your first vote is waiting.", quote: quote(.newHabit), symbol: "plus.circle")
        }
    }

    func setArchived(_ habit: Habit, _ archived: Bool) {
        mutate { data in
            guard var h = data.habit(habit.id) else { return }
            h.archived = archived
            if !archived { h.order = data.nextOrder }
            data.upsert(h)
        }
    }

    func delete(_ habit: Habit) {
        mutate { $0.deleteHabit(habit.id) }
    }

    func move(from source: IndexSet, to destination: Int) {
        mutate { data in
            var ordered = data.activeHabits
            ordered.move(fromOffsets: source, toOffset: destination)
            for (i, habit) in ordered.enumerated() {
                guard let index = data.habits.firstIndex(where: { $0.id == habit.id }) else { continue }
                data.habits[index].order = i
            }
        }
    }

    func applyTimingSuggestion(habitID: UUID, slotID: UUID, to time: TimeOfDay) {
        mutate { data in
            guard var habit = data.habit(habitID), let i = habit.slots.firstIndex(where: { $0.id == slotID }) else { return }
            habit.slots[i].time = time
            data.upsert(habit)
        }
        toast = Toast(message: "Moved to \(time.displayText). Plans that match real life stick.", symbol: "clock.arrow.circlepath")
    }

    // MARK: Rituals

    func setSankalpa(intention: String, focus: UUID?) {
        mutate { data in
            data.updateRecord(today) { record in
                let trimmed = intention.trimmingCharacters(in: .whitespacesAndNewlines)
                record.intention = trimmed.isEmpty ? "" : trimmed
                record.focusHabitID = focus
            }
        }
    }

    func saveReview(_ review: Review, note: String) {
        mutate { data in
            data.updateRecord(today) { record in
                record.review = review
                let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                record.note = trimmed.isEmpty ? nil : trimmed
            }
        }
        toast = Toast(message: "Day reviewed. Sleep well.", quote: quote(.evening, salt: 3), symbol: "moon.stars")
    }

    func updatePreferences(_ change: (inout Preferences) -> Void) {
        mutate { change(&$0.preferences) }
    }

    func flag(_ key: String) -> String? { data.flags[key] }

    func setFlag(_ key: String, _ value: String?) {
        mutate { $0.flags[key] = value }
    }

    // MARK: Backup

    func exportBackup() throws -> URL {
        let raw = try Backup.export(data)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Sadhana backup \(today.raw).json")
        try raw.write(to: url, options: .atomic)
        return url
    }

    func restore(_ imported: ImportedBackup) {
        switch imported {
        case .sadhana(let restored):
            mutate { data in
                data = restored
                data.preferences.onboarded = true
            }
            toast = Toast(message: "Backup restored.", symbol: "arrow.down.doc")
        case .habitChain(let habits, let days):
            mutate { Backup.merge(habits: habits, days: days, into: &$0) }
            toast = Toast(message: "Imported \(habits.count) habits from Habit Chain.", symbol: "arrow.down.doc")
        }
    }

    // MARK: Routes from notifications and widgets

    func handleNotification(action: String, kind: String?, habit: String?, slot: String?, day: String?) {
        refresh()
        let habitID = habit.flatMap(UUID.init(uuidString:))
        let slotID = slot.flatMap(UUID.init(uuidString:))
        let logDay = day.flatMap(DayKey.init(raw:)) ?? today
        let target = habitID.flatMap(self.habit)
        switch action {
        case ReminderScheduler.Action.done:
            if let target { complete(target, slotID: slotID, on: logDay) }
        case ReminderScheduler.Action.plusOne:
            if let target { mutate { $0.complete(habitID: target.id, slotID: nil, day: logDay) } }
        case ReminderScheduler.Action.minimum:
            if let target { logMinimum(target, on: logDay) }
        case ReminderScheduler.Action.slip:
            tab = .today
            if let target { slip(target, on: logDay) }
        case ReminderScheduler.Action.start:
            if let target { tab = .today; route = .timer(habitID: target.id, slotID: slotID) }
        default:
            tab = .today
            switch kind {
            case ReminderKind.morning.rawValue: route = .sankalpa
            case ReminderKind.evening.rawValue: route = .review
            case ReminderKind.timed.rawValue:
                if let target { route = .timer(habitID: target.id, slotID: slotID) }
            default: break
            }
        }
    }

    func handle(url: URL) {
        guard url.scheme == "sadhana" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        tab = .today
        switch url.host {
        case "timer":
            if let id = value("habit").flatMap(UUID.init(uuidString:)) {
                route = .timer(habitID: id, slotID: value("slot").flatMap(UUID.init(uuidString:)))
            }
        case "sankalpa": route = .sankalpa
        case "review": route = .review
        default: break
        }
    }

    func consumePendingRoute() {
        guard let pending = SharedDefaults.pendingRoute else { return }
        SharedDefaults.pendingRoute = nil
        let parts = pending.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if parts.first == "timer", parts.count >= 2, let id = UUID(uuidString: parts[1]) {
            tab = .today
            route = .timer(habitID: id, slotID: parts.count > 2 ? UUID(uuidString: parts[2]) : nil)
        }
    }
}
