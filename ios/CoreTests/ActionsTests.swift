import XCTest
@testable import HexisCore

final class ActionsTests: XCTestCase {
    let day = DayKey(raw: "2026-10-03")!

    func testCompleteFillsSlotsInOrderAndStops() {
        let a = HabitSlot(time: TimeOfDay(20, 0)), b = HabitSlot(time: TimeOfDay(8, 0))
        let habit = Habit(name: "Vitamins", slots: [a, b], createdOn: day)
        var data = AppData(habits: [habit])
        XCTAssertTrue(data.complete(habitID: habit.id, slotID: nil, day: day))
        XCTAssertEqual(data.record(for: day).entries.first?.slotID, b.id, "Earliest open time first")
        XCTAssertFalse(data.complete(habitID: habit.id, slotID: b.id, day: day), "Already done")
        XCTAssertTrue(data.complete(habitID: habit.id, slotID: nil, day: day))
        XCTAssertFalse(data.complete(habitID: habit.id, slotID: nil, day: day), "Nothing left")
        XCTAssertEqual(Engine(data: data, today: day).progress(habit, on: day).status, .done)
    }

    func testUndoAndMinimum() {
        let habit = Habit(name: "Read", slots: [HabitSlot(time: TimeOfDay(21, 0))], createdOn: day)
        var data = AppData(habits: [habit])
        data.complete(habitID: habit.id, slotID: nil, day: day)
        XCTAssertTrue(data.undo(habitID: habit.id, slotID: nil, day: day))
        XCTAssertTrue(data.record(for: day).isEmpty)
        XCTAssertTrue(data.logMinimum(habitID: habit.id, day: day))
        XCTAssertFalse(data.logMinimum(habitID: habit.id, day: day))
        XCTAssertEqual(Engine(data: data, today: day).progress(habit, on: day).status, .minimum)
        XCTAssertTrue(data.undo(habitID: habit.id, slotID: nil, day: day))
        XCTAssertTrue(data.record(for: day).isEmpty)
    }

    func testSlipOnlyForQuitHabits() {
        let quit = Habit(name: "No sugar", kind: .quit, createdOn: day)
        let check = Habit(name: "Read", createdOn: day)
        var data = AppData(habits: [quit, check])
        XCTAssertFalse(data.logSlip(habitID: check.id, day: day))
        XCTAssertTrue(data.logSlip(habitID: quit.id, day: day))
        XCTAssertTrue(data.clearSlip(habitID: quit.id, day: day))
        XCTAssertFalse(data.complete(habitID: quit.id, slotID: nil, day: day))
    }

    func testDeleteRemovesHistory() {
        let habit = Habit(name: "Read", createdOn: day)
        var data = AppData(habits: [habit])
        data.complete(habitID: habit.id, slotID: nil, day: day)
        data.updateRecord(day) { $0.focusHabitID = habit.id }
        data.deleteHabit(habit.id)
        XCTAssertTrue(data.habits.isEmpty)
        XCTAssertNil(data.days[day.raw])
    }
}
