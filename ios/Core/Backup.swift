import Foundation

public enum BackupError: Error, Equatable, LocalizedError {
    case unreadable

    public var errorDescription: String? {
        "That file isn't a Hexis or Habit Chain backup."
    }
}

/// What a backup file turned out to contain.
public enum ImportedBackup: Equatable {
    /// A full Hexis backup. Restoring it replaces everything.
    case hexis(AppData)
    /// Habits and check-ins from the Habit Chain web tracker. These are added alongside existing habits.
    case habitChain(habits: [Habit], days: [String: DayRecord])
}

public enum Backup {
    public static func export(_ data: AppData) throws -> Data {
        let encoder = AppData.makeEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(BackupFile(app: "hexis", exportedAt: Date(), data: data))
    }

    public static func read(_ raw: Data) throws -> ImportedBackup {
        let decoder = AppData.makeDecoder()
        if let file = try? decoder.decode(BackupFile.self, from: raw), file.app == "hexis" {
            return .hexis(file.data)
        }
        if let chain = try? JSONDecoder().decode(HabitChainBackup.self, from: raw), chain.app == "habit-chain" {
            return convert(chain)
        }
        throw BackupError.unreadable
    }

    /// Adds Habit Chain habits and their check-ins to existing data.
    public static func merge(habits: [Habit], days: [String: DayRecord], into data: inout AppData) {
        var order = data.nextOrder
        for var habit in habits where data.habit(habit.id) == nil {
            habit.order = order
            order += 1
            data.habits.append(habit)
        }
        for (raw, incoming) in days {
            var record = data.days[raw] ?? DayRecord()
            record.entries.append(contentsOf: incoming.entries.filter { e in !record.entries.contains { $0.id == e.id } })
            if let note = incoming.note, !note.isEmpty, record.note?.contains(note) != true {
                record.note = [record.note, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n\n")
            }
            data.days[raw] = record
        }
    }

    // MARK: Habit Chain

    struct BackupFile: Codable {
        var app: String
        var exportedAt: Date
        var data: AppData
    }

    struct HabitChainBackup: Decodable {
        struct ChainHabit: Decodable {
            var id: String
            var name: String?
            var color: String?
            var days: [Int]?
            var target: Int?
            var unit: String?
            var createdAt: String?
            var archived: Bool?
        }
        struct ChainMonth: Decodable {
            var days: [String: [String: Double]]?
            var notes: [String: String]?
        }
        var app: String
        var habits: [ChainHabit]
        var months: [String: ChainMonth]
    }

    static let chainColors: [String: HabitColor] = [
        "cobalt": .indigo, "teal": .teal, "plum": .pink, "rust": .red,
        "olive": .green, "rose": .pink, "amber": .yellow, "slate": .graphite,
    ]

    /// Stable UUIDs for Habit Chain ids, so importing the same file twice doesn't duplicate habits.
    static func uuid(forChainID id: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        var hash: UInt64 = 0xcbf29ce484222325
        for (i, byte) in ("habit-chain:" + id).utf8.enumerated() {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
            bytes[i % 16] ^= UInt8(truncatingIfNeeded: hash >> 24)
        }
        for i in 0..<8 { bytes[i] ^= UInt8(truncatingIfNeeded: hash >> (UInt64(i) * 8)) }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    static func convert(_ chain: HabitChainBackup) -> ImportedBackup {
        var habits: [Habit] = []
        var kinds: [String: (UUID, HabitKind)] = [:]
        for (i, h) in chain.habits.enumerated() {
            let target = max(1, h.target ?? 1)
            let kind: HabitKind = target > 1 ? .count : .check
            let id = uuid(forChainID: h.id)
            let weekdays = (h.days ?? Array(0...6)).filter { (0...6).contains($0) }.map { $0 + 1 }
            habits.append(Habit(
                id: id, name: h.name ?? "Habit", symbol: kind == .count ? "drop.fill" : "checkmark.seal",
                color: chainColors[h.color ?? ""] ?? .orange, kind: kind, weekdays: weekdays.isEmpty ? Array(1...7) : weekdays,
                slots: [], target: target, unit: h.unit ?? "", createdOn: h.createdAt.flatMap(DayKey.init(raw:)) ?? .today(),
                archived: h.archived ?? false, order: i))
            kinds[h.id] = (id, kind)
        }
        var days: [String: DayRecord] = [:]
        for (month, content) in chain.months {
            for (dd, counts) in content.days ?? [:] {
                guard let day = DayKey(raw: "\(month)-\(dd)") else { continue }
                var record = days[day.raw] ?? DayRecord()
                for (chainID, value) in counts where value > 0 {
                    guard let pair = kinds[chainID] else { continue }
                    let (id, kind) = pair
                    let amount = kind == .count ? Int(value) : 1
                    let entryID = uuid(forChainID: "\(chainID)|\(day.raw)")
                    record.entries.append(LogEntry(id: entryID, habitID: id, kind: .done, amount: amount, at: day.date(at: TimeOfDay(12, 0))))
                }
                days[day.raw] = record
            }
            for (dd, text) in content.notes ?? [:] where !text.trimmed.isEmpty {
                guard let day = DayKey(raw: "\(month)-\(dd)") else { continue }
                var record = days[day.raw] ?? DayRecord()
                record.note = text
                days[day.raw] = record
            }
        }
        return .habitChain(habits: habits, days: days)
    }
}
