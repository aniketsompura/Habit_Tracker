import XCTest
@testable import HexisCore

final class RemindersTests: XCTestCase {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }

    func testSkipsDoneSlotsAndAddsFollowUps() {
        let day = DayKey(raw: "2026-10-03")!
        let morning = HabitSlot(time: TimeOfDay(8, 0)), night = HabitSlot(time: TimeOfDay(20, 0))
        let habit = Habit(name: "Vitamins", slots: [morning, night], minimum: "", createdOn: day)
        var data = AppData(habits: [habit])
        data.preferences.morningRitual = false
        data.preferences.eveningReview = false
        data.updateRecord(day) { $0.entries.append(LogEntry(habitID: habit.id, slotID: morning.id)) }

        let now = day.date(at: TimeOfDay(7, 0), calendar: calendar)
        let plan = ReminderPlanner.plan(data: data, now: now, horizonDays: 1, calendar: calendar)
        XCTAssertEqual(plan.map(\.kind), [.check, .followUp])
        XCTAssertTrue(plan.allSatisfy { $0.slotID == night.id })
        XCTAssertTrue(plan.allSatisfy { $0.id.hasPrefix(ReminderPlanner.prefix) })
    }

    func testRespectsLimitAndOrder() {
        let day = DayKey(raw: "2026-10-03")!
        let slots = (0..<12).map { HabitSlot(time: TimeOfDay(8 + $0, 0)) }
        let habit = Habit(name: "Stretch", slots: slots, createdOn: day)
        let data = AppData(habits: [habit])
        let plan = ReminderPlanner.plan(data: data, now: day.date(at: TimeOfDay(6, 0), calendar: calendar), horizonDays: 7, calendar: calendar)
        XCTAssertEqual(plan.count, ReminderPlanner.limit)
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
    }

    func testMinimumLoggedSilencesTheDay() {
        let day = DayKey(raw: "2026-10-03")!
        let habit = Habit(name: "Read", slots: [HabitSlot(time: TimeOfDay(21, 0))], createdOn: day)
        var data = AppData(habits: [habit])
        data.preferences.morningRitual = false
        data.preferences.eveningReview = false
        data.updateRecord(day) { $0.entries.append(LogEntry(habitID: habit.id, kind: .minimum)) }
        let plan = ReminderPlanner.plan(data: data, now: day.date(at: TimeOfDay(9, 0), calendar: calendar), horizonDays: 1, calendar: calendar)
        XCTAssertTrue(plan.isEmpty)
    }

    func testWhenThenSentence() {
        let habit = Habit(name: "Read 20 minutes", cue: "I put my phone on the charger", place: "in bed")
        XCTAssertEqual(ReminderText.whenThen(habit), "After I put my phone on the charger, read 20 minutes in bed.")
        let named = Habit(name: "Surya Namaskar", cue: "I wake up")
        XCTAssertEqual(ReminderText.whenThen(named), "After I wake up, Surya Namaskar.")
    }
}

final class QuotesTests: XCTestCase {
    func testLibraryLoadsWithSourcesAndBothTraditions() {
        let book = QuoteBook.loadBundled()
        XCTAssertGreaterThan(book.quotes.count, 100)
        XCTAssertEqual(Set(book.quotes.map(\.id)).count, book.quotes.count)
        XCTAssertTrue(book.quotes.allSatisfy { !$0.cite.isEmpty && !$0.text.isEmpty })
        for moment in QuoteMoment.allCases {
            XCTAssertTrue(book.quotes.contains { $0.tradition == .stoic && $0.moments.contains(moment) }, "No Stoic quote for \(moment)")
            XCTAssertTrue(book.quotes.contains { $0.tradition == .hindu && $0.moments.contains(moment) }, "No Hindu quote for \(moment)")
        }
    }

    func testDailyQuoteIsStableAndAlternates() {
        let book = QuoteBook.loadBundled()
        let day = DayKey(raw: "2026-10-03")!
        XCTAssertEqual(book.daily(on: day, tradition: .both), book.daily(on: day, tradition: .both))
        XCTAssertNotEqual(book.daily(on: day, tradition: .both).tradition, book.daily(on: day.adding(1), tradition: .both).tradition)
        XCTAssertEqual(book.daily(on: day, tradition: .hindu).tradition, .hindu)
        XCTAssertTrue(book.pick(.miss, on: day, tradition: .stoic).moments.contains(.miss))
    }

    func testWalkVisitsEveryQuoteOncePerCycle() {
        let book = QuoteBook.loadBundled()
        let stoic = book.filtered(.stoic)
        let seen = Set((0..<stoic.count).map { QuoteBook.walk(stoic, position: $0).id })
        XCTAssertEqual(seen.count, stoic.count)
    }
}

final class BackupTests: XCTestCase {
    func testRoundTrip() throws {
        let day = DayKey(raw: "2026-10-03")!
        let habit = Habit(name: "Read", slots: [HabitSlot(time: TimeOfDay(21, 0))], createdOn: day)
        var data = AppData(habits: [habit])
        data.updateRecord(day) { $0.intention = "Be patient"; $0.entries.append(LogEntry(habitID: habit.id, at: Date(timeIntervalSince1970: 1_790_000_000))) }
        let raw = try Backup.export(data)
        guard case .hexis(let restored) = try Backup.read(raw) else { return XCTFail("Expected a Hexis backup") }
        XCTAssertEqual(restored, data)
    }

    func testImportsHabitChain() throws {
        let json = """
        {"app":"habit-chain","version":1,"exportedAt":"2026-10-03T00:00:00Z",
         "habits":[{"id":"hwater","name":"Drink water","color":"teal","days":[0,1,2,3,4,5,6],"target":8,"unit":"glasses","createdAt":"2026-09-01","order":0,"archived":false},
                   {"id":"hgym","name":"Work out","color":"rust","days":[1,3,5],"target":1,"unit":"","createdAt":"2026-09-01","order":1,"archived":false}],
         "months":{"2026-09":{"days":{"02":{"hwater":6,"hgym":0},"04":{"hgym":1}},"notes":{"02":"Felt good"}}}}
        """
        guard case .habitChain(let habits, let days) = try Backup.read(Data(json.utf8)) else { return XCTFail("Expected Habit Chain") }
        XCTAssertEqual(habits.map(\.kind), [.count, .check])
        XCTAssertEqual(habits[1].weekdays, [2, 4, 6])
        XCTAssertEqual(habits[0].color, .teal)
        XCTAssertEqual(days["2026-09-02"]?.entries.count, 1)
        XCTAssertEqual(days["2026-09-02"]?.entries.first?.amount, 6)
        XCTAssertEqual(days["2026-09-02"]?.note, "Felt good")

        var data = AppData()
        Backup.merge(habits: habits, days: days, into: &data)
        Backup.merge(habits: habits, days: days, into: &data)
        XCTAssertEqual(data.habits.count, 2, "Importing twice must not duplicate habits")
        XCTAssertEqual(data.days["2026-09-04"]?.entries.count, 1, "Importing twice must not duplicate check-ins")
        XCTAssertEqual(data.days["2026-09-02"]?.note, "Felt good", "Importing twice must not duplicate notes")
    }

    func testRejectsOtherFiles() {
        XCTAssertThrowsError(try Backup.read(Data("{}".utf8)))
    }
}
