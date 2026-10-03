import XCTest
@testable import SadhanaCore

final class EngineTests: XCTestCase {
    let start = DayKey(raw: "2026-09-01")!

    func makeHabit(kind: HabitKind = .check, slots: [HabitSlot] = [HabitSlot(time: TimeOfDay(7, 0))], weekdays: [Int] = Array(1...7), target: Int = 1) -> Habit {
        Habit(name: "Read", kind: kind, weekdays: weekdays, slots: slots, target: target, createdOn: start)
    }

    func log(_ data: inout AppData, _ habit: Habit, _ day: DayKey, kind: EntryKind = .done, slot: UUID? = nil, amount: Int = 1) {
        data.updateRecord(day) { $0.entries.append(LogEntry(habitID: habit.id, kind: kind, slotID: slot ?? habit.slots.first?.id, amount: amount, at: day.date(at: TimeOfDay(7, 0)))) }
    }

    func testStreakForgivesOneMissButNotTwo() {
        let habit = makeHabit()
        var data = AppData(habits: [habit])
        // Kept 1–3, missed 4, kept 5–6.
        for d in [0, 1, 2, 4, 5] { log(&data, habit, start.adding(d)) }
        var stats = Engine(data: data, today: start.adding(6)).stats(habit)
        XCTAssertEqual(stats.streak.current, 5)
        XCTAssertFalse(stats.streak.atRisk)

        // Then two misses in a row (days 6 and 7) break it.
        stats = Engine(data: data, today: start.adding(8)).stats(habit)
        XCTAssertEqual(stats.streak.current, 0)
        XCTAssertEqual(stats.streak.best, 5)
    }

    func testAtRiskAfterSingleMissAndTodayPending() {
        let habit = makeHabit()
        var data = AppData(habits: [habit])
        for d in 0..<3 { log(&data, habit, start.adding(d)) }
        let engine = Engine(data: data, today: start.adding(4)) // day 3 missed, day 4 is today
        let stats = engine.stats(habit)
        XCTAssertTrue(stats.streak.atRisk)
        XCTAssertEqual(stats.streak.current, 3)
        XCTAssertEqual(engine.progress(habit, on: start.adding(4)).status, .pending)
        XCTAssertEqual(engine.atRiskHabits().map(\.id), [habit.id])
    }

    func testRestDaysNeverBreakTheChain() {
        // Monday, Wednesday, Friday only. 2026-09-07 is a Monday.
        let monday = DayKey(raw: "2026-09-07")!
        let habit = Habit(name: "Gym", weekdays: [2, 4, 6], slots: [HabitSlot(time: TimeOfDay(7, 0))], createdOn: monday)
        var data = AppData(habits: [habit])
        for d in [0, 2, 4, 7] { log(&data, habit, monday.adding(d)) }
        let stats = Engine(data: data, today: monday.adding(7)).stats(habit)
        XCTAssertEqual(stats.streak.current, 4)
    }

    func testMinimumKeepsTheChain() {
        let habit = makeHabit()
        var data = AppData(habits: [habit])
        log(&data, habit, start)
        log(&data, habit, start.adding(1), kind: .minimum)
        log(&data, habit, start.adding(2))
        let engine = Engine(data: data, today: start.adding(2))
        XCTAssertEqual(engine.progress(habit, on: start.adding(1)).status, .minimum)
        XCTAssertEqual(engine.stats(habit).streak.current, 3)
    }

    func testSeveralTimesADayNeedEachSlot() {
        let morning = HabitSlot(time: TimeOfDay(8, 0)), evening = HabitSlot(time: TimeOfDay(20, 0))
        let habit = makeHabit(slots: [morning, evening])
        var data = AppData(habits: [habit])
        log(&data, habit, start, slot: morning.id)
        var engine = Engine(data: data, today: start)
        XCTAssertEqual(engine.progress(habit, on: start).status, .partial)
        let items = engine.agenda(on: start)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map(\.done), [true, false])
        XCTAssertEqual(items.map(\.period), [.morning, .evening])

        log(&data, habit, start, slot: evening.id)
        engine = Engine(data: data, today: start)
        XCTAssertEqual(engine.progress(habit, on: start).status, .done)
        XCTAssertTrue(engine.summary(on: start).isComplete)
    }

    func testCountHabitTotalsAmounts() {
        let habit = makeHabit(kind: .count, slots: [HabitSlot(time: TimeOfDay(9, 0)), HabitSlot(time: TimeOfDay(15, 0))], target: 8)
        var data = AppData(habits: [habit])
        for _ in 0..<5 { log(&data, habit, start, slot: nil) }
        let engine = Engine(data: data, today: start)
        let p = engine.progress(habit, on: start)
        XCTAssertEqual(p.done, 5)
        XCTAssertEqual(p.required, 8)
        let item = engine.agenda(on: start).first!
        XCTAssertEqual(item.period, .anytime)
        XCTAssertEqual(item.amount, 5)
        XCTAssertFalse(item.done)
    }

    func testQuitHabitHoldsUntilSlip() {
        let habit = makeHabit(kind: .quit, slots: [HabitSlot(time: TimeOfDay(22, 30))])
        var data = AppData(habits: [habit])
        var engine = Engine(data: data, today: start.adding(3))
        XCTAssertEqual(engine.progress(habit, on: start.adding(3)).status, .holding)
        XCTAssertEqual(engine.stats(habit).streak.current, 3)

        log(&data, habit, start.adding(3), kind: .slip)
        engine = Engine(data: data, today: start.adding(3))
        XCTAssertEqual(engine.progress(habit, on: start.adding(3)).status, .slipped)
        XCTAssertFalse(engine.agenda(on: start.adding(3)).first!.done)
    }

    func testVotesAndMala() {
        let habit = makeHabit()
        var data = AppData(habits: [habit])
        for d in 0..<110 { log(&data, habit, start.adding(d)) }
        let stats = Engine(data: data, today: start.adding(109)).stats(habit)
        XCTAssertEqual(stats.votes, 110)
        XCTAssertEqual(stats.malas, 1)
        XCTAssertEqual(stats.malaBeads, 2)
    }

    func testTimingInsightNoticesDrift() {
        let slot = HabitSlot(time: TimeOfDay(21, 0))
        let habit = makeHabit(slots: [slot])
        var data = AppData(habits: [habit])
        for d in 0..<8 {
            let day = start.adding(d)
            data.updateRecord(day) { $0.entries.append(LogEntry(habitID: habit.id, slotID: slot.id, at: day.date(at: TimeOfDay(21, 42)))) }
        }
        let insight = Engine(data: data, today: start.adding(8)).timing(habit).first
        XCTAssertEqual(insight?.drift, 40)
        XCTAssertEqual(insight?.typical, TimeOfDay(21, 40))
    }

    func testUpNextPrefersTheNextDueItem() {
        let early = makeHabit(slots: [HabitSlot(time: TimeOfDay(6, 0))])
        let late = makeHabit(slots: [HabitSlot(time: TimeOfDay(18, 0))])
        let data = AppData(habits: [early, late])
        let engine = Engine(data: data, today: start)
        XCTAssertEqual(engine.upNext(on: start, now: TimeOfDay(12, 0))?.habitID, late.id)
        XCTAssertEqual(engine.upNext(on: start, now: TimeOfDay(5, 0))?.habitID, early.id)
        XCTAssertEqual(engine.upNext(on: start, now: TimeOfDay(23, 0))?.habitID, early.id) // overdue fallback
    }

    func testDecodingToleratesMissingFields() throws {
        let json = #"{"habits":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Walk","color":"neon"}]}"#
        let data = try AppData.makeDecoder().decode(AppData.self, from: Data(json.utf8))
        XCTAssertEqual(data.habits.first?.color, .saffron)
        XCTAssertEqual(data.habits.first?.weekdays, Array(1...7))
        XCTAssertTrue(data.preferences.morningRitual)
    }

    func testFreshStarts() {
        var data = AppData()
        data.preferences.birthdayMonth = 10
        data.preferences.birthdayDay = 3
        let engine = Engine(data: data, today: start)
        XCTAssertEqual(engine.freshStart(on: DayKey(raw: "2026-10-03")!), .birthday)
        XCTAssertEqual(engine.freshStart(on: DayKey(raw: "2027-01-01")!), .year)
        XCTAssertEqual(engine.freshStart(on: DayKey(raw: "2026-11-01")!), .month)
        XCTAssertEqual(engine.freshStart(on: DayKey(raw: "2026-10-05")!), .week)
        XCTAssertNil(engine.freshStart(on: DayKey(raw: "2026-10-06")!))
    }
}
