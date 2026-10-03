import SwiftUI
import WidgetKit

@main
struct HexisWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        TodayWidget()
        LockScreenWidget()
        TimerLiveActivityWidget()
    }
}

// MARK: Timeline

struct HexisEntry: TimelineEntry {
    let date: Date
    let day: DayKey
    let items: [AgendaItem]
    let habits: [UUID: Habit]
    let next: AgendaItem?
    let summary: DaySummary
    let quote: Quote
    let hasHabits: Bool
    let canReadData: Bool

    func habit(_ item: AgendaItem) -> Habit? { habits[item.habitID] }
}

struct HexisProvider: TimelineProvider {
    func placeholder(in context: Context) -> HexisEntry { Self.sample(at: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (HexisEntry) -> Void) {
        let entry = Self.entry(at: Date(), data: DataFile.load())
        completion(context.isPreview && !entry.hasHabits ? Self.sample(at: Date()) : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HexisEntry>) -> Void) {
        let now = Date()
        let data = DataFile.load()
        let today = DayKey(now)
        // Refresh at every preferred time today so "up next" moves on, and again after midnight.
        var moments: [Date] = [now]
        for habit in data.activeHabits where habit.isScheduled(on: today) {
            for slot in habit.slots {
                let date = today.date(at: slot.time)
                if date > now { moments.append(date.addingTimeInterval(-15 * 60)) }
            }
        }
        let midnight = today.adding(1).date(at: TimeOfDay(0, 1))
        moments.append(midnight)
        let entries = Array(Set(moments.filter { $0 >= now })).sorted().prefix(20).map { Self.entry(at: $0, data: data) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    static func entry(at date: Date, data: AppData) -> HexisEntry {
        let day = DayKey(date)
        let engine = Engine(data: data, today: day)
        let items = engine.agenda(on: day)
        return HexisEntry(
            date: date, day: day, items: items,
            habits: Dictionary(uniqueKeysWithValues: data.habits.map { ($0.id, $0) }),
            next: engine.upNext(on: day, now: TimeOfDay(date)),
            summary: DaySummary(done: items.filter(\.done).count, total: items.count),
            quote: QuoteBook.shared.daily(on: day, tradition: data.preferences.tradition),
            hasHabits: !data.activeHabits.isEmpty,
            canReadData: DataFile.isShared)
    }

    /// Example habits for the widget gallery.
    static func sample(at date: Date) -> HexisEntry {
        let day = DayKey(date)
        var data = AppData(habits: HabitTemplate.all.prefix(5).map { $0.makeHabit(createdOn: day) })
        for habit in data.habits.prefix(2) { data.complete(habitID: habit.id, slotID: nil, day: day) }
        return entry(at: date, data: data)
    }
}

// MARK: Shared pieces

struct SkyBackground: View {
    var date: Date

    var body: some View {
        let colors = Sky.colors(at: TimeOfDay(date).minutes)
        LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    func skyForeground(_ date: Date) -> some View {
        foregroundStyle(Sky.isDark(at: TimeOfDay(date).minutes) ? Color.white : Color(hex: 0x2A1F16))
    }
}

/// The main action for an item, as an interactive widget button.
struct ItemActionButton<Label: View>: View {
    var item: AgendaItem
    var habit: Habit
    @ViewBuilder var label: Label

    var body: some View {
        if habit.kind == .timed && !item.done {
            Button(intent: OpenTimerIntent(habitID: habit.id, slotID: item.slotID)) { label }
        } else {
            Button(intent: CompleteHabitIntent(habitID: habit.id, slotID: item.slotID)) { label }
        }
    }
}

// MARK: Up next (small)

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HexisUpNext", provider: HexisProvider()) { entry in
            UpNextWidgetView(entry: entry)
                .containerBackground(for: .widget) { SkyBackground(date: entry.date) }
        }
        .configurationDisplayName("Up next")
        .description("Your next habit, with a button to mark it done.")
        .supportedFamilies([.systemSmall])
    }
}

struct UpNextWidgetView: View {
    var entry: HexisEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !entry.canReadData {
                setupMessage
            } else if let next = entry.next, let habit = entry.habit(next) {
                HStack {
                    Text("UP NEXT").font(.caption2.weight(.bold)).opacity(0.75)
                    Spacer()
                    Text("\(entry.summary.done)/\(entry.summary.total)").font(.caption2.weight(.bold)).opacity(0.75)
                }
                Spacer(minLength: 0)
                Image(systemName: habit.symbol).font(.title3)
                Text(habit.name).font(.display(17, weight: .bold)).lineLimit(2).minimumScaleFactor(0.8)
                Text(next.time?.displayText ?? "Any time").font(.caption).opacity(0.8)
                ItemActionButton(item: next, habit: habit) {
                    Text(actionTitle(next, habit))
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(habit.color.color))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else if entry.summary.isComplete {
                Spacer(minLength: 0)
                HStack(spacing: -6) {
                    DoneRow(count: 3, size: 30, animated: false)
                }
                Text("All done").font(.display(17, weight: .bold))
                Text("\(entry.summary.total) of \(entry.summary.total) today").font(.caption).opacity(0.8)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                HabitMark(color: Palette.accent, symbol: "checkmark", state: .open(progress: 0), size: 36, animated: false)
                Text(entry.hasHabits ? "Nothing scheduled now" : "Add a habit in Hexis").font(.display(15, weight: .semibold))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .skyForeground(entry.date)
    }

    private func actionTitle(_ item: AgendaItem, _ habit: Habit) -> String {
        switch habit.kind {
        case .count: return "+1 · \(item.amount)/\(item.target)"
        case .timed: return "Start \(habit.target) min"
        default: return "Done"
        }
    }

    private var setupMessage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
            Text("Open settings in Hexis to turn on widgets.").font(.caption.weight(.semibold))
        }
    }
}

// MARK: Today (medium)

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HexisToday", provider: HexisProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { SkyBackground(date: entry.date) }
        }
        .configurationDisplayName("Today")
        .description("Every habit for today. Tap one to mark it done.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayWidgetView: View {
    var entry: HexisEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(.display(18, weight: .bold))
                Text(entry.day.formatted("EEE d MMM")).font(.caption).opacity(0.75)
                Spacer()
                Text("\(entry.summary.done)/\(entry.summary.total) lit").font(.caption.weight(.bold))
            }
            if !entry.canReadData {
                Text("Open settings in Hexis to turn on widgets.").font(.caption)
                Spacer(minLength: 0)
            } else if entry.items.isEmpty {
                Spacer(minLength: 0)
                Text(entry.hasHabits ? "Nothing scheduled today. Rest well." : "Add a habit in Hexis to see it here.").font(.subheadline)
                Spacer(minLength: 0)
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(entry.items.prefix(6)) { item in
                        if let habit = entry.habit(item) {
                            ItemActionButton(item: item, habit: habit) {
                                VStack(spacing: 3) {
                                    HabitMark(color: habit.color.color, symbol: habit.symbol, state: item.done ? .done : .open(progress: item.kind == .count ? Double(item.amount) / Double(max(1, item.target)) : 0), size: 36, doneSymbol: item.kind == .quit ? habit.symbol : "checkmark", animated: false)
                                    Text(habit.name).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                                    Text(item.kind == .count ? "\(item.amount)/\(item.target)" : (item.time?.displayText ?? "Any"))
                                        .font(.system(size: 9)).opacity(0.75)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer(minLength: 0)
                Text("“\(entry.quote.text)”").font(.quote(11)).lineLimit(1).opacity(0.85)
            }
        }
        .skyForeground(entry.date)
    }
}

// MARK: Lock Screen

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HexisLockScreen", provider: HexisProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Hexis")
        .description("How many habits are done today and what's up next.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenWidgetView: View {
    var entry: HexisEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.summary.fraction) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(entry.summary.done)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                if let next = entry.next, let habit = entry.habit(next) {
                    Text("Up next · \(next.time?.displayText ?? "today")").font(.caption2.weight(.semibold))
                    Text(habit.name).font(.headline).lineLimit(1)
                } else {
                    Text(entry.summary.isComplete ? "All done" : "Hexis").font(.headline)
                }
                Text("\(entry.summary.done) of \(entry.summary.total) done").font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text("\(entry.summary.done) of \(entry.summary.total) done")
        }
    }
}

// MARK: Live Activity

struct TimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            TimerLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(hex: 0x141A45))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.symbol)
                        .font(.title2)
                        .foregroundStyle(context.attributes.habitColor.color)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(state: context.state).font(.title2.monospacedDigit().weight(.semibold))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.habitName).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimerProgress(state: context.state, color: context.attributes.habitColor.color)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbol).foregroundStyle(context.attributes.habitColor.color)
            } compactTrailing: {
                TimerText(state: context.state).monospacedDigit().frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(Palette.accent)
            }
        }
    }
}

struct TimerText: View {
    var state: TimerActivityAttributes.ContentState

    var body: some View {
        if let paused = state.pausedRemaining {
            let total = Int(paused)
            Text(String(format: "%d:%02d", total / 60, total % 60))
        } else {
            Text(timerInterval: Date()...max(Date(), state.end), countsDown: true)
        }
    }
}

struct TimerProgress: View {
    var state: TimerActivityAttributes.ContentState
    var color: Color

    var body: some View {
        if let paused = state.pausedRemaining {
            let total = max(1, state.end.timeIntervalSince(state.start))
            ProgressView(value: 1 - paused / total).tint(color)
        } else {
            ProgressView(timerInterval: state.start...max(state.start, state.end), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(color)
        }
    }
}

struct TimerLockScreenView: View {
    var attributes: TimerActivityAttributes
    var state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            HabitMark(color: attributes.habitColor.color, symbol: attributes.symbol, state: .open(progress: 0.6), size: 44, animated: false)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(attributes.habitName).font(.headline)
                    Spacer()
                    TimerText(state: state).font(.title3.monospacedDigit().weight(.semibold))
                }
                TimerProgress(state: state, color: attributes.habitColor.color)
                Text(state.pausedRemaining == nil ? "\(attributes.minutes) minutes · breathe slowly" : "Paused")
                    .font(.caption)
                    .opacity(0.75)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
