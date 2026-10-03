import Foundation

/// A calendar day in the user's current time zone, stored as "yyyy-MM-dd".
public struct DayKey: Hashable, Comparable, Codable, Sendable {
    public let raw: String
}
