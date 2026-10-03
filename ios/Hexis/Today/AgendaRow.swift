import SwiftUI

/// One habit at one preferred time. Tap the ring to complete it; swipe for more.
struct AgendaRow: View {
    var item: AgendaItem
    var habit: Habit
    var day: DayKey
    var isToday: Bool
    var progress: DayProgress
    var stats: HabitStats
    var isFocus: Bool
    var isTimerRunning: Bool
    var now: TimeOfDay

    @Environment(AppStore.self) private var store

    private var markState: MarkState {
        switch habit.kind {
        case .quit:
            return item.done ? .done : .slipped
        case .count:
            if item.done { return .done }
            return progress.minimumLogged ? .minimum : .open(progress: Double(item.amount) / Double(max(1, item.target)))
        case .check, .timed:
            if item.done { return .done }
            if progress.minimumLogged { return .minimum }
            return .open(progress: isTimerRunning ? 0.5 : 0)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            markButton
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .strikethrough(item.done && habit.kind != .quit, color: Palette.ink2.opacity(0.6))
                        .opacity(item.done && habit.kind != .quit ? 0.6 : 1)
                    if isFocus {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Palette.accent)
                            .accessibilityLabel("Non-negotiable today")
                    }
                }
                metaLine
                if let cueLine { Text(cueLine).font(.caption).foregroundStyle(Palette.ink2).lineLimit(1) }
            }
            Spacer(minLength: 4)
            trailing
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.card)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isFocus ? Palette.accent : Palette.rule.opacity(0.6), lineWidth: isFocus ? 1.5 : 0.5)
                )
        )
        .sensoryFeedback(.success, trigger: item.done) { old, new in !old && new }
        .sensoryFeedback(.impact(weight: .light), trigger: item.amount)
        .swipeActions(edge: .leading, allowsFullSwipe: true) { leadingActions }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) { trailingActions }
        .contextMenu { menu }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { store.tap(item, on: day) }
        .accessibilityHint(primaryHint)
    }

    // MARK: Parts

    private var markButton: some View {
        Button {
            store.tap(item, on: day)
        } label: {
            HabitMark(color: habit.color.color, symbol: habit.symbol, state: markState, size: 48,
                      doneSymbol: habit.kind == .quit ? habit.symbol : "checkmark")
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(primaryHint)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            if let time = item.time {
                Text(time.displayText)
            } else if habit.kind == .count && habit.slots.count > 1 {
                Text("Through the day")
            }
            if stats.streak.current > 0 {
                Label("\(stats.streak.current)", systemImage: "flame.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Palette.accent)
                    .accessibilityLabel("\(stats.streak.current) day chain")
            }
            if isToday && stats.streak.atRisk && !progress.status.isKept {
                Text("Never miss twice")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.danger.opacity(0.14)))
                    .foregroundStyle(Palette.danger)
            }
            if progress.minimumLogged && !item.done {
                Text("Minimum kept").font(.caption2.weight(.bold)).foregroundStyle(Palette.success)
            }
        }
        .font(.footnote)
        .foregroundStyle(Palette.ink2)
    }

    private var cueLine: String? {
        guard !item.done, !habit.cue.trimmed.isEmpty else { return nil }
        return "After \(habit.cue.trimmed)" + (habit.place.trimmed.isEmpty ? "" : " · \(habit.place.trimmed)")
    }

    @ViewBuilder private var trailing: some View {
        switch habit.kind {
        case .count:
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(item.amount)")
                    .font(.rounded(22, weight: .bold))
                    .contentTransition(.numericText(value: Double(item.amount)))
                    .animation(.snappy, value: item.amount)
                Text("of \(item.target)").font(.caption2).foregroundStyle(Palette.ink2)
            }
            .foregroundStyle(item.done ? habit.color.color : Palette.ink)
        case .timed:
            Text(isTimerRunning ? "Running" : "\(habit.target) min")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isTimerRunning ? habit.color.color : Palette.ink2)
        case .quit:
            Text(item.done ? (isToday ? "Holding" : "Clean") : "Slipped")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(item.done ? Palette.success : Palette.danger)
        case .check:
            EmptyView()
        }
    }

    private var primaryHint: String {
        switch habit.kind {
        case .check: return item.done ? "Mark \(habit.name) not done" : "Mark \(habit.name) done"
        case .count: return "Add one \(habit.unitLabel.lowercased()) to \(habit.name), \(item.amount) of \(item.target)"
        case .timed: return item.done ? "Mark \(habit.name) not done" : (isToday ? "Start the \(habit.target) minute timer for \(habit.name)" : "Mark \(habit.name) done")
        case .quit: return item.done ? "Log a slip for \(habit.name)" : "Remove the slip for \(habit.name)"
        }
    }

    // MARK: Actions

    @ViewBuilder private var leadingActions: some View {
        switch habit.kind {
        case .check, .timed:
            Button { store.tap(item, on: day) } label: {
                Label(item.done ? "Undo" : "Done", systemImage: item.done ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(item.done ? Palette.ink2 : habit.color.color)
        case .count:
            Button { store.tap(item, on: day) } label: { Label("+1", systemImage: "plus") }
                .tint(habit.color.color)
        case .quit:
            EmptyView()
        }
    }

    @ViewBuilder private var trailingActions: some View {
        if habit.kind == .quit {
            if item.done {
                Button { store.slip(habit, on: day) } label: { Label("Slipped", systemImage: "drop.triangle") }.tint(Palette.danger)
            } else {
                Button { store.tap(item, on: day) } label: { Label("Undo slip", systemImage: "arrow.uturn.backward") }.tint(Palette.ink2)
            }
        } else {
            if !progress.isComplete && !progress.minimumLogged {
                Button { store.logMinimum(habit, on: day) } label: { Label("Minimum", systemImage: "leaf") }.tint(Palette.success)
            }
            if habit.kind == .count && item.amount > 0 {
                Button { store.decrement(habit, on: day) } label: { Label("−1", systemImage: "minus") }.tint(Palette.ink2)
            }
        }
    }

    @ViewBuilder private var menu: some View {
        switch habit.kind {
        case .quit:
            Button(item.done ? "I slipped" : "Undo slip", systemImage: item.done ? "drop.triangle" : "arrow.uturn.backward") { store.tap(item, on: day) }
        case .count:
            Button("Add one", systemImage: "plus") { store.tap(item, on: day) }
            if item.amount > 0 { Button("Remove one", systemImage: "minus") { store.decrement(habit, on: day) } }
        case .check, .timed:
            Button(item.done ? "Mark not done" : "Mark done", systemImage: item.done ? "arrow.uturn.backward" : "checkmark") {
                if item.done || habit.kind == .check || !isToday { store.tap(item, on: day) } else { store.complete(habit, slotID: item.slotID, on: day, minutes: habit.target) }
            }
            if habit.kind == .timed && isToday && !item.done {
                Button("Start timer", systemImage: "timer") { store.route = .timer(habitID: habit.id, slotID: item.slotID) }
            }
        }
        if habit.kind != .quit && !progress.isComplete && !progress.minimumLogged {
            Button(habit.minimum.trimmed.isEmpty ? "Did the minimum" : "Did the minimum: \(habit.minimum.trimmed)", systemImage: "leaf") {
                store.logMinimum(habit, on: day)
            }
        }
        Divider()
        Button("Edit habit", systemImage: "pencil") { store.route = .editHabit(habit.id) }
    }
}

/// Presses sink slightly and spring back.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
