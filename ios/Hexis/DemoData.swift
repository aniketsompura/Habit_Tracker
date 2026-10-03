#if DEBUG
import Foundation

/// Sample habits and history for simulator screenshots. Only in debug builds, and only when launched with `-HexisDemo`.
enum DemoData {
    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-HexisDemo") }

    /// `-HexisTab journey` opens a tab; `-HexisRoute sankalpa` opens a sheet.
    static var tab: String? { UserDefaults.standard.string(forKey: "HexisTab") }
    static var route: String? { UserDefaults.standard.string(forKey: "HexisRoute") }

    static func make(today: DayKey) -> AppData {
        let start = today.adding(-75)
        let names = ["Meditate", "Drink water", "Vitamins", "Read 20 minutes", "Evening walk", "No phone in bed"]
        var habits: [Habit] = []
        for (i, name) in names.enumerated() {
            guard let template = HabitTemplate.all.first(where: { $0.name == name }) else { continue }
            var habit = template.makeHabit(createdOn: start)
            habit.order = i
            habits.append(habit)
        }
        var data = AppData(habits: habits)
        data.preferences.onboarded = true
        var seed: UInt64 = 42
        func roll() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max)
        }
        var day = start
        while day < today {
            for habit in habits {
                let chance: Double = habit.kind == .quit ? 0.9 : (day.days(until: today) < 10 ? 0.95 : 0.78)
                switch habit.kind {
                case .quit:
                    if roll() > chance { data.logSlip(habitID: habit.id, day: day) }
                case .count:
                    let amount = roll() < chance ? habit.target : Int(roll() * Double(habit.target))
                    if amount > 0 { data.complete(habitID: habit.id, slotID: nil, day: day, at: day.date(at: TimeOfDay(13, 0)), amount: amount) }
                default:
                    for slot in habit.sortedSlots where roll() < chance {
                        // Reading tends to happen 40 minutes late, which Journey should notice.
                        let drift = habit.name.hasPrefix("Read") ? 40 : Int(roll() * 20) - 10
                        data.complete(habitID: habit.id, slotID: slot.id, day: day, at: day.date(at: slot.time.adding(minutes: drift)), amount: habit.target)
                    }
                    if roll() > 0.97 { data.logMinimum(habitID: habit.id, day: day) }
                }
            }
            if roll() < 0.35 {
                data.updateRecord(day) {
                    $0.intention = ["Be patient and present", "Do the hard thing first", "Speak kindly", "Finish what I start"][Int(roll() * 4) % 4]
                    $0.review = Review(cured: "Didn't check my phone before breakfast", resisted: "Snapping at traffic", better: "Read even though I was tired")
                }
            }
            day = day.adding(1)
        }
        // Today: a morning in progress.
        if let meditate = habits.first(where: { $0.name == "Meditate" }) {
            data.complete(habitID: meditate.id, slotID: nil, day: today, at: today.date(at: TimeOfDay(6, 12)), amount: meditate.target)
        }
        if let water = habits.first(where: { $0.name == "Drink water" }) {
            for _ in 0..<3 { data.complete(habitID: water.id, slotID: nil, day: today) }
        }
        if let vitamins = habits.first(where: { $0.name == "Vitamins" }) {
            data.complete(habitID: vitamins.id, slotID: nil, day: today, at: today.date(at: TimeOfDay(8, 5)))
        }
        // Yesterday's walk was missed, so today shows "never miss twice".
        if let walk = habits.first(where: { $0.name == "Evening walk" }) {
            data.updateRecord(today.adding(-1)) { $0.entries.removeAll { $0.habitID == walk.id } }
        }
        data.updateRecord(today) {
            $0.intention = "Be patient and present"
            $0.focusHabitID = habits.first(where: { $0.name.hasPrefix("Read") })?.id
        }
        data.favoriteQuotes = ["gita-6-19", "marcus-5-1-rising"]
        if ProcessInfo.processInfo.arguments.contains("-HexisOnboarding") { data.preferences.onboarded = false }
        return data
    }
}
#endif
