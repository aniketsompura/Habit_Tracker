import Foundation

/// Ready-made habits to start from. Each comes with a when-then plan and a minimum version filled in.
public struct HabitTemplate: Identifiable, Sendable {
    public var id: String { name }
    public var name: String
    public var symbol: String
    public var color: HabitColor
    public var kind: HabitKind
    public var times: [TimeOfDay]
    public var weekdays: [Int]
    public var target: Int
    public var unit: String
    public var cue: String
    public var place: String
    public var identity: String
    public var minimum: String

    public func makeHabit(createdOn: DayKey = .today()) -> Habit {
        Habit(name: name, symbol: symbol, color: color, kind: kind, weekdays: weekdays,
              slots: times.map { HabitSlot(time: $0) }, target: target, unit: unit, cue: cue, place: place,
              identity: identity, minimum: minimum, createdOn: createdOn)
    }

    public static let all: [HabitTemplate] = [
        HabitTemplate(name: "Meditate", symbol: "figure.mind.and.body", color: .indigo, kind: .timed, times: [TimeOfDay(6, 0)], weekdays: Array(1...7),
                      target: 10, unit: "", cue: "I wake up and wash my face", place: "on my mat", identity: "a calm person", minimum: "three slow breaths"),
        HabitTemplate(name: "Surya Namaskar", symbol: "sun.max.fill", color: .saffron, kind: .check, times: [TimeOfDay(6, 15)], weekdays: Array(1...7),
                      target: 1, unit: "", cue: "I finish meditating", place: "facing the sunrise", identity: "someone who moves every day", minimum: "one round"),
        HabitTemplate(name: "Pranayama", symbol: "wind", color: .peacock, kind: .timed, times: [TimeOfDay(6, 30)], weekdays: Array(1...7),
                      target: 5, unit: "", cue: "I finish Surya Namaskar", place: "sitting by the window", identity: "a calm person", minimum: "ten breaths"),
        HabitTemplate(name: "Drink water", symbol: "drop.fill", color: .peacock, kind: .count, times: [TimeOfDay(9, 0), TimeOfDay(12, 30), TimeOfDay(16, 0), TimeOfDay(19, 0)],
                      weekdays: Array(1...7), target: 8, unit: "glasses", cue: "I sit down at my desk", place: "", identity: "someone who looks after their body", minimum: "four glasses"),
        HabitTemplate(name: "Vitamins", symbol: "pills.fill", color: .turmeric, kind: .check, times: [TimeOfDay(8, 0), TimeOfDay(20, 0)], weekdays: Array(1...7),
                      target: 1, unit: "", cue: "I have breakfast", place: "", identity: "someone who looks after their body", minimum: ""),
        HabitTemplate(name: "Read 20 minutes", symbol: "book.fill", color: .lotus, kind: .check, times: [TimeOfDay(21, 30)], weekdays: Array(1...7),
                      target: 1, unit: "", cue: "I put my phone on the charger", place: "in bed", identity: "a reader", minimum: "one page"),
        HabitTemplate(name: "Evening walk", symbol: "figure.walk", color: .tulsi, kind: .check, times: [TimeOfDay(18, 30)], weekdays: Array(1...7),
                      target: 1, unit: "", cue: "I close my laptop", place: "around the block", identity: "someone who moves every day", minimum: "five minutes outside"),
        HabitTemplate(name: "Work out", symbol: "dumbbell.fill", color: .kumkum, kind: .check, times: [TimeOfDay(7, 0)], weekdays: [2, 4, 6],
                      target: 1, unit: "", cue: "I change into my gym clothes", place: "at the gym", identity: "a strong person", minimum: "ten push-ups"),
        HabitTemplate(name: "Journal", symbol: "pencil.line", color: .marble, kind: .check, times: [TimeOfDay(22, 0)], weekdays: Array(1...7),
                      target: 1, unit: "", cue: "I finish the evening review", place: "", identity: "someone who reflects", minimum: "one sentence"),
        HabitTemplate(name: "No phone in bed", symbol: "iphone.slash", color: .indigo, kind: .quit, times: [TimeOfDay(22, 30)], weekdays: Array(1...7),
                      target: 1, unit: "", cue: "", place: "", identity: "someone who sleeps well", minimum: ""),
        HabitTemplate(name: "No sugar", symbol: "nosign", color: .kumkum, kind: .quit, times: [TimeOfDay(16, 0)], weekdays: Array(1...7),
                      target: 1, unit: "", cue: "", place: "", identity: "someone in charge of their cravings", minimum: ""),
    ]
}
