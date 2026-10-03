import ActivityKit
import Foundation

/// The Lock Screen and Dynamic Island countdown for a timed habit.
struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
        var end: Date
        /// Set while paused; the countdown freezes at this many seconds.
        var pausedRemaining: TimeInterval?
    }

    var habitName: String
    var symbol: String
    var colorName: String
    var minutes: Int
}

extension TimerActivityAttributes {
    var habitColor: HabitColor { HabitColor(rawValue: colorName) ?? .saffron }
}
