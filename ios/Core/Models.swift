import Foundation

public enum HabitKind: String, Codable, CaseIterable, Sendable {
    /// Done or not done, once per scheduled time.
    case check
    /// Tap up to a daily target, such as 8 glasses of water.
    case count
    /// A timed session per scheduled time, such as 10 minutes of meditation.
    case timed
    /// Something to avoid. Each day counts unless a slip is logged.
    case quit
}

/// Habit inks, named after things from an Indian home and a Stoic's marble.
public enum HabitColor: String, Codable, CaseIterable, Sendable {
    case saffron, kumkum, turmeric, peacock, tulsi, lotus, indigo, marble
}

public enum Tradition: String, Codable, CaseIterable, Sendable {
    case both, stoic, hindu
}

/// One preferred time for a habit, with its own reminder.
public struct HabitSlot: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var time: TimeOfDay
    public var remind: Bool

    public init(id: UUID = UUID(), time: TimeOfDay, remind: Bool = true) {
        self.id = id
        self.time = time
        self.remind = remind
    }

    enum CodingKeys: String, CodingKey { case id, time, remind }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        time = c.value(.time, default: TimeOfDay(9, 0))
        remind = c.value(.remind, default: true)
    }
}

public struct Habit: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// SF Symbol name.
    public var symbol: String
    public var color: HabitColor
    public var kind: HabitKind
    /// Calendar weekdays the habit applies to, 1 = Sunday … 7 = Saturday.
    public var weekdays: [Int]
    /// Preferred times. Check and timed habits need each one done; count habits use them as nudges.
    public var slots: [HabitSlot]
    /// Count: daily target. Timed: minutes per session. Unused otherwise.
    public var target: Int
    /// Count unit, such as "glasses".
    public var unit: String
    /// "After I …" cue for a when-then plan.
    public var cue: String
    /// Where the habit happens.
    public var place: String
    /// "I am becoming …", the identity each check-in votes for.
    public var identity: String
    /// The smallest version that still keeps the chain on a hard day.
    public var minimum: String
    /// Something enjoyable to pair with the habit.
    public var treat: String
    public var createdOn: DayKey
    public var archived: Bool
    public var order: Int

    public init(
        id: UUID = UUID(), name: String, symbol: String = "sparkles", color: HabitColor = .saffron,
        kind: HabitKind = .check, weekdays: [Int] = Array(1...7), slots: [HabitSlot] = [],
        target: Int = 1, unit: String = "", cue: String = "", place: String = "", identity: String = "",
        minimum: String = "", treat: String = "", createdOn: DayKey = .today(), archived: Bool = false, order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.color = color
        self.kind = kind
        self.weekdays = weekdays
        self.slots = slots
        self.target = target
        self.unit = unit
        self.cue = cue
        self.place = place
        self.identity = identity
        self.minimum = minimum
        self.treat = treat
        self.createdOn = createdOn
        self.archived = archived
        self.order = order
    }

    enum CodingKeys: String, CodingKey {
        case id, name, symbol, color, kind, weekdays, slots, target, unit, cue, place, identity, minimum, treat, createdOn, archived, order
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = c.value(.name, default: "Untitled habit")
        symbol = c.value(.symbol, default: "sparkles")
        color = c.value(.color, default: .saffron)
        kind = c.value(.kind, default: .check)
        let days: [Int] = c.value(.weekdays, default: Array(1...7))
        let valid = Array(Set(days.filter { (1...7).contains($0) })).sorted()
        weekdays = valid.isEmpty ? Array(1...7) : valid
        slots = c.value(.slots, default: [])
        target = max(1, c.value(.target, default: 1))
        unit = c.value(.unit, default: "")
        cue = c.value(.cue, default: "")
        place = c.value(.place, default: "")
        identity = c.value(.identity, default: "")
        minimum = c.value(.minimum, default: "")
        treat = c.value(.treat, default: "")
        createdOn = c.value(.createdOn, default: DayKey.today())
        archived = c.value(.archived, default: false)
        order = c.value(.order, default: 0)
    }

    public var sortedSlots: [HabitSlot] { slots.sorted { $0.time.dayOrder < $1.time.dayOrder } }

    public func isScheduled(on day: DayKey) -> Bool { weekdays.contains(day.weekday) }

    /// Units needed for a day to count as done.
    public var dailyRequirement: Int {
        switch kind {
        case .check, .timed: return max(1, slots.count)
        case .count: return max(1, target)
        case .quit: return 1
        }
    }

    public var unitLabel: String { unit.trimmingCharacters(in: .whitespaces).isEmpty ? "times" : unit }
}

public enum EntryKind: String, Codable, Sendable {
    case done
    /// The small version was done on a hard day. Keeps the chain.
    case minimum
    /// A quit habit slipped.
    case slip
}

public struct LogEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var habitID: UUID
    public var kind: EntryKind
    /// Which preferred time this completes, for check and timed habits.
    public var slotID: UUID?
    /// Count: units added. Timed: minutes completed.
    public var amount: Int
    /// When it actually happened, used for on-time insights.
    public var at: Date

    public init(id: UUID = UUID(), habitID: UUID, kind: EntryKind = .done, slotID: UUID? = nil, amount: Int = 1, at: Date = Date()) {
        self.id = id
        self.habitID = habitID
        self.kind = kind
        self.slotID = slotID
        self.amount = amount
        self.at = at
    }
}

/// Seneca's nightly questions (On Anger 3.36), answered in the evening review.
public struct Review: Codable, Equatable, Sendable {
    public var cured: String
    public var resisted: String
    public var better: String
    public var savedAt: Date

    public init(cured: String = "", resisted: String = "", better: String = "", savedAt: Date = Date()) {
        self.cured = cured
        self.resisted = resisted
        self.better = better
        self.savedAt = savedAt
    }

    public var isEmpty: Bool {
        [cured, resisted, better].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

public struct DayRecord: Codable, Equatable, Sendable {
    public var entries: [LogEntry]
    /// Morning Sankalpa: today's intention.
    public var intention: String?
    /// The one habit that can't slip today.
    public var focusHabitID: UUID?
    public var review: Review?
    /// Free-form log for the day.
    public var note: String?

    public init(entries: [LogEntry] = [], intention: String? = nil, focusHabitID: UUID? = nil, review: Review? = nil, note: String? = nil) {
        self.entries = entries
        self.intention = intention
        self.focusHabitID = focusHabitID
        self.review = review
        self.note = note
    }

    enum CodingKeys: String, CodingKey { case entries, intention, focusHabitID, review, note }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = c.value(.entries, default: [])
        intention = c.value(.intention, default: nil)
        focusHabitID = c.value(.focusHabitID, default: nil)
        review = c.value(.review, default: nil)
        note = c.value(.note, default: nil)
    }

    public var isEmpty: Bool {
        entries.isEmpty && intention == nil && focusHabitID == nil && review == nil && (note ?? "").isEmpty
    }

    public var hasSankalpa: Bool { intention != nil || focusHabitID != nil }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var morningRitual: Bool
    public var morningTime: TimeOfDay
    public var eveningReview: Bool
    public var eveningTime: TimeOfDay
    public var followUps: Bool
    public var followUpMinutes: Int
    public var tradition: Tradition
    public var showSanskrit: Bool
    public var birthdayMonth: Int?
    public var birthdayDay: Int?
    public var onboarded: Bool

    public init() {
        morningRitual = true
        morningTime = TimeOfDay(6, 30)
        eveningReview = true
        eveningTime = TimeOfDay(21, 30)
        followUps = true
        followUpMinutes = 30
        tradition = .both
        showSanskrit = true
        birthdayMonth = nil
        birthdayDay = nil
        onboarded = false
    }

    enum CodingKeys: String, CodingKey {
        case morningRitual, morningTime, eveningReview, eveningTime, followUps, followUpMinutes, tradition, showSanskrit, birthdayMonth, birthdayDay, onboarded
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        morningRitual = c.value(.morningRitual, default: d.morningRitual)
        morningTime = c.value(.morningTime, default: d.morningTime)
        eveningReview = c.value(.eveningReview, default: d.eveningReview)
        eveningTime = c.value(.eveningTime, default: d.eveningTime)
        followUps = c.value(.followUps, default: d.followUps)
        followUpMinutes = min(180, max(5, c.value(.followUpMinutes, default: d.followUpMinutes)))
        tradition = c.value(.tradition, default: d.tradition)
        showSanskrit = c.value(.showSanskrit, default: d.showSanskrit)
        birthdayMonth = c.value(.birthdayMonth, default: nil)
        birthdayDay = c.value(.birthdayDay, default: nil)
        onboarded = c.value(.onboarded, default: false)
    }
}

/// Everything the app stores, saved as one JSON file shared with the widgets.
public struct AppData: Codable, Equatable, Sendable {
    public var version: Int
    public var habits: [Habit]
    /// Keyed by `DayKey.raw`.
    public var days: [String: DayRecord]
    public var preferences: Preferences
    public var favoriteQuotes: [String]
    /// Small per-day flags, such as the day a fresh-start card was dismissed.
    public var flags: [String: String]

    public init(habits: [Habit] = [], days: [String: DayRecord] = [:], preferences: Preferences = Preferences(), favoriteQuotes: [String] = [], flags: [String: String] = [:]) {
        self.version = 1
        self.habits = habits
        self.days = days
        self.preferences = preferences
        self.favoriteQuotes = favoriteQuotes
        self.flags = flags
    }

    enum CodingKeys: String, CodingKey { case version, habits, days, preferences, favoriteQuotes, flags }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.value(.version, default: 1)
        habits = c.value(.habits, default: [])
        days = c.value(.days, default: [:])
        preferences = c.value(.preferences, default: Preferences())
        favoriteQuotes = c.value(.favoriteQuotes, default: [])
        flags = c.value(.flags, default: [:])
    }

    public var activeHabits: [Habit] {
        habits.filter { !$0.archived }.sorted { ($0.order, $0.createdOn.jdn) < ($1.order, $1.createdOn.jdn) }
    }

    public var archivedHabits: [Habit] { habits.filter(\.archived).sorted { $0.name < $1.name } }

    public func habit(_ id: UUID) -> Habit? { habits.first { $0.id == id } }

    public func record(for day: DayKey) -> DayRecord { days[day.raw] ?? DayRecord() }

    public mutating func updateRecord(_ day: DayKey, _ change: (inout DayRecord) -> Void) {
        var record = record(for: day)
        change(&record)
        days[day.raw] = record.isEmpty ? nil : record
    }

    public mutating func upsert(_ habit: Habit) {
        if let i = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[i] = habit
        } else {
            var h = habit
            h.order = (habits.map(\.order).max() ?? -1) + 1
            habits.append(h)
        }
    }

    public var nextOrder: Int { (habits.map(\.order).max() ?? -1) + 1 }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value, falling back to `fallback` when the key is missing or holds something unexpected.
    func value<T: Decodable>(_ key: Key, default fallback: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback()
    }
}
