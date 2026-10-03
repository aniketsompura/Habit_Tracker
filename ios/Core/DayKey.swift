import Foundation

/// A calendar day in the user's current time zone, written as "yyyy-MM-dd".
/// Arithmetic runs on Julian day numbers, so it never depends on the device's calendar system.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let jdn: Int

    public init(jdn: Int) {
        self.jdn = jdn
    }

    public init(year: Int, month: Int, day: Int) {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    public init?(raw: String) {
        let parts = raw.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        self.init(year: y, month: m, day: d)
        let c = components
        guard c.year == y, c.month == m, c.day == d else { return nil }
    }

    public init(_ date: Date, calendar: Calendar = .hexis) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func today(_ now: Date = Date(), calendar: Calendar = .hexis) -> DayKey {
        DayKey(now, calendar: calendar)
    }

    public var components: (year: Int, month: Int, day: Int) {
        let a = jdn + 32044
        let b = (4 * a + 3) / 146097
        let c = a - 146097 * b / 4
        let d = (4 * c + 3) / 1461
        let e = c - 1461 * d / 4
        let m = (5 * e + 2) / 153
        let day = e - (153 * m + 2) / 5 + 1
        let month = m + 3 - 12 * (m / 10)
        let year = 100 * b + d - 4800 + m / 10
        return (year, month, day)
    }

    public var year: Int { components.year }
    public var month: Int { components.month }
    public var day: Int { components.day }

    public var raw: String {
        let c = components
        return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
    }

    /// "yyyy-MM", the month this day belongs to.
    public var monthKey: String { String(raw.prefix(7)) }

    public var description: String { raw }

    /// 1 = Sunday … 7 = Saturday, matching `Calendar` weekday numbers.
    public var weekday: Int { ((jdn + 1) % 7) + 1 }

    /// The Monday of this day's week.
    public var weekStart: DayKey { adding(-((weekday + 5) % 7)) }

    public func adding(_ days: Int) -> DayKey { DayKey(jdn: jdn + days) }

    public func days(until other: DayKey) -> Int { other.jdn - jdn }

    /// The moment this day reaches `time` in the given calendar's time zone.
    public func date(at time: TimeOfDay = TimeOfDay(0, 0), calendar: Calendar = .hexis) -> Date {
        let c = components
        var dc = DateComponents()
        dc.year = c.year
        dc.month = c.month
        dc.day = c.day
        dc.hour = time.hour
        dc.minute = time.minute
        return calendar.date(from: dc) ?? Date(timeIntervalSince1970: 0)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.jdn < rhs.jdn }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let key = DayKey(raw: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a yyyy-MM-dd day: \(string)")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

/// A wall-clock time without a date, such as 6:30.
public struct TimeOfDay: Hashable, Comparable, Codable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(_ hour: Int, _ minute: Int) {
        self.hour = ((hour % 24) + 24) % 24
        self.minute = min(59, max(0, minute))
    }

    public init(minutes: Int) {
        let m = ((minutes % 1440) + 1440) % 1440
        self.init(m / 60, m % 60)
    }

    public init(_ date: Date, calendar: Calendar = .hexis) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(c.hour ?? 0, c.minute ?? 0)
    }

    /// Minutes since midnight.
    public var minutes: Int { hour * 60 + minute }

    /// Sort position within a day that runs from 3:30 am to 3:30 am, so late-night times sort last.
    public var dayOrder: Int { minutes < DayPeriod.dayStartMinutes ? minutes + 1440 : minutes }

    public func adding(minutes delta: Int) -> TimeOfDay { TimeOfDay(minutes: minutes + delta) }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.minutes < rhs.minutes }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let parts = string.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an HH:mm time: \(string)")
        }
        self.init(h, m)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(format: "%02d:%02d", hour, minute))
    }
}

extension Calendar {
    /// Gregorian calendar in the device's current time zone. Every day boundary in the app uses it.
    public static var hexis: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
}
