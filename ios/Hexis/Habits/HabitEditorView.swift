import SwiftUI

struct HabitEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Habit?
    @State private var draft: Habit
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    static let symbols = [
        "sparkles", "sun.max.fill", "sunrise.fill", "moon.stars.fill", "figure.mind.and.body", "figure.yoga", "figure.walk", "figure.run",
        "dumbbell.fill", "bicycle", "wind", "lungs.fill", "drop.fill", "cup.and.saucer.fill", "leaf.fill", "carrot.fill",
        "fork.knife", "pills.fill", "bed.double.fill", "book.fill", "books.vertical.fill", "pencil.line", "brain.head.profile", "graduationcap.fill",
        "music.note", "paintbrush.fill", "hands.sparkles.fill", "heart.fill", "flame.fill", "hourglass", "iphone.slash", "nosign",
    ]

    init(habit: Habit?, today: DayKey) {
        existing = habit
        _draft = State(initialValue: habit ?? Habit(name: "", symbol: "sparkles", color: .orange, kind: .check,
                                                    slots: [HabitSlot(time: TimeOfDay(7, 0))], createdOn: today))
    }

    private var isNew: Bool { existing == nil }
    private var canSave: Bool { !draft.name.trimmed.isEmpty && !draft.weekdays.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                if isNew { templates }
                identitySection
                kindSection
                scheduleSection
                stickSection
                if !isNew { manageSection }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper)
            .navigationTitle(isNew ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete \(draft.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete habit and history", role: .destructive) {
                    if let existing { store.delete(existing) }
                    dismiss()
                }
                Button("Archive instead") {
                    if let existing { store.setArchived(existing, true) }
                    dismiss()
                }
            } message: {
                Text("Deleting removes every check-in and streak for this habit. Archiving hides it and keeps its history.")
            }
            .onAppear { if isNew { nameFocused = true } }
        }
    }

    // MARK: Sections

    private var templates: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HabitTemplate.all) { template in
                        Button { apply(template) } label: {
                            Label(template.name, systemImage: template.symbol)
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(template.color.color.opacity(draft.name == template.name ? 0.3 : 0.12)))
                                .foregroundStyle(template.color.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Text("Start from a template")
        }
        .listRowBackground(Palette.card)
    }

    private var identitySection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: draft.symbol)
                    .font(.title2)
                    .foregroundStyle(draft.color.color)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(draft.color.color.opacity(0.14)))
                    .contentTransition(.symbolEffect(.replace))
                TextField("Name, like Read 20 minutes", text: $draft.name)
                    .font(.headline)
                    .focused($nameFocused)
                    .submitLabel(.done)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 10) {
                ForEach(Self.symbols, id: \.self) { symbol in
                    Button { withAnimation(.snappy) { draft.symbol = symbol } } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 16))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(draft.symbol == symbol ? draft.color.color.opacity(0.22) : Color.clear))
                            .foregroundStyle(draft.symbol == symbol ? draft.color.color : Palette.ink2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                }
            }
            .padding(.vertical, 4)
            HStack(spacing: 10) {
                ForEach(HabitColor.allCases, id: \.self) { color in
                    Button { withAnimation(.snappy) { draft.color = color } } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(Palette.card, lineWidth: draft.color == color ? 3 : 0))
                            .overlay(Circle().strokeBorder(color.color, lineWidth: draft.color == color ? 1.5 : 0).padding(-3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.label)
                    .accessibilityAddTraits(draft.color == color ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .listRowBackground(Palette.card)
    }

    private var kindSection: some View {
        Section {
            Picker("Type", selection: $draft.kind) {
                Text("Yes / no").tag(HabitKind.check)
                Text("Count").tag(HabitKind.count)
                Text("Timed").tag(HabitKind.timed)
                Text("Quit").tag(HabitKind.quit)
            }
            .pickerStyle(.segmented)
            .onChange(of: draft.kind) { _, kind in adjust(for: kind) }

            switch draft.kind {
            case .check:
                Text("Mark it done once at each time you set below.").font(.footnote).foregroundStyle(Palette.ink2)
            case .count:
                Stepper(value: $draft.target, in: 1...99) {
                    HStack { Text("Daily target"); Spacer(); Text("\(draft.target)").font(.rounded(17)).foregroundStyle(draft.color.color) }
                }
                TextField("Unit, like glasses or pages", text: $draft.unit)
            case .timed:
                Stepper(value: $draft.target, in: 1...180) {
                    HStack { Text("Session length"); Spacer(); Text("\(draft.target) min").font(.rounded(17)).foregroundStyle(draft.color.color) }
                }
                Text("A timer runs on your Lock Screen and marks the habit done when it ends.").font(.footnote).foregroundStyle(Palette.ink2)
            case .quit:
                Text("Every day counts as kept unless you log a slip. Set the time cravings usually hit and you'll get a nudge then.")
                    .font(.footnote).foregroundStyle(Palette.ink2)
            }
        } header: {
            Text("Type")
        }
        .listRowBackground(Palette.card)
    }

    private var scheduleSection: some View {
        Section {
            WeekdayPicker(weekdays: $draft.weekdays, tint: draft.color.color)
            ForEach($draft.slots) { $slot in
                HStack {
                    DatePicker(slotLabel(slot), selection: Binding(get: { slot.time.asDate }, set: { slot.time = TimeOfDay($0) }), displayedComponents: .hourAndMinute)
                    Button {
                        slot.remind.toggle()
                    } label: {
                        Image(systemName: slot.remind ? "bell.fill" : "bell.slash")
                            .foregroundStyle(slot.remind ? draft.color.color : Palette.ink2)
                            .frame(width: 36, height: 36)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(slot.remind ? "Reminder on" : "Reminder off")
                }
            }
            .onDelete { draft.slots.remove(atOffsets: $0) }
            if draft.kind != .quit || draft.slots.isEmpty {
                Button {
                    let last = draft.sortedSlots.last?.time ?? TimeOfDay(7, 0)
                    withAnimation { draft.slots.append(HabitSlot(time: draft.slots.isEmpty ? last : last.adding(minutes: 180))) }
                } label: {
                    Label(draft.slots.isEmpty ? "Add a time" : "Add another time", systemImage: "plus.circle")
                }
            }
        } header: {
            Text(draft.kind == .quit ? "Risky time" : "When")
        } footer: {
            Text(scheduleFooter)
        }
        .listRowBackground(Palette.card)
    }

    private var stickSection: some View {
        Section {
            LabeledField(label: "After", placeholder: "I make my morning coffee", text: $draft.cue)
                .opacity(draft.kind == .quit ? 0.5 : 1)
            LabeledField(label: "Where", placeholder: "on the balcony", text: $draft.place)
            LabeledField(label: "I am becoming", placeholder: "a reader", text: $draft.identity)
            if draft.kind != .quit {
                LabeledField(label: "Hard-day minimum", placeholder: "read one page", text: $draft.minimum)
            }
            LabeledField(label: "Pair it with", placeholder: "my favourite podcast", text: $draft.treat)
        } header: {
            Text("Make it stick")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if !ReminderText.whenThen(draft).isEmpty {
                    Text(ReminderText.whenThen(draft)).font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
                }
                Text("Plans written as “after X, I will Y” are followed far more often than plain goals. The minimum keeps your chain on hard days, and each check-in counts as a vote for who you're becoming.")
            }
        }
        .listRowBackground(Palette.card)
    }

    private var manageSection: some View {
        Section {
            if let existing {
                Button(existing.archived ? "Restore habit" : "Archive habit") {
                    store.setArchived(existing, !existing.archived)
                    dismiss()
                }
                Button("Delete habit", role: .destructive) { confirmDelete = true }
            }
        }
        .listRowBackground(Palette.card)
    }

    // MARK: Helpers

    private func slotLabel(_ slot: HabitSlot) -> String {
        if draft.kind == .quit { return "Risky time" }
        guard draft.slots.count > 1, let index = draft.sortedSlots.firstIndex(where: { $0.id == slot.id }) else { return "Time" }
        return "Time \(index + 1)"
    }

    private var scheduleFooter: String {
        switch draft.kind {
        case .check, .timed:
            return draft.slots.count > 1 ? "Each time is its own check-in with its own reminder." : (draft.slots.isEmpty ? "With no time set, the habit sits under Through the day and has no reminder." : "You'll get a reminder at this time, and a gentle follow-up if it's still open.")
        case .count:
            return draft.slots.count > 1 ? "Reminders spread through the day nudge you toward the target." : "Add a few times to get nudges through the day."
        case .quit:
            return "One nudge at your risky time."
        }
    }

    private func adjust(for kind: HabitKind) {
        switch kind {
        case .count: if draft.target < 2 { draft.target = 8 }
        case .timed: if draft.target < 2 { draft.target = 10 }
        case .quit:
            if draft.slots.count > 1 { draft.slots = Array(draft.sortedSlots.suffix(1)) }
        case .check: break
        }
    }

    private func apply(_ template: HabitTemplate) {
        let made = template.makeHabit(createdOn: store.today)
        withAnimation(.snappy) {
            draft.name = made.name
            draft.symbol = made.symbol
            draft.color = made.color
            draft.kind = made.kind
            draft.weekdays = made.weekdays
            draft.slots = made.slots
            draft.target = made.target
            draft.unit = made.unit
            draft.cue = made.cue
            draft.place = made.place
            draft.identity = made.identity
            draft.minimum = made.minimum
        }
    }

    private func save() {
        var habit = draft
        habit.name = habit.name.trimmed
        habit.unit = habit.unit.trimmed
        habit.cue = habit.cue.trimmed
        habit.place = habit.place.trimmed
        habit.identity = habit.identity.trimmed
        habit.minimum = habit.minimum.trimmed
        habit.treat = habit.treat.trimmed
        habit.slots = habit.sortedSlots
        if habit.kind == .check { habit.target = 1 }
        store.save(habit, isNew: isNew)
        dismiss()
    }
}

struct LabeledField: View {
    var label: String
    var placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
            TextField(placeholder, text: $text)
        }
        .padding(.vertical, 2)
    }
}

/// Monday-first day toggles, plus shortcuts.
struct WeekdayPicker: View {
    @Binding var weekdays: [Int]
    var tint: Color

    private let order = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(order, id: \.self) { day in
                    let on = weekdays.contains(day)
                    Button {
                        withAnimation(.snappy) {
                            if on { if weekdays.count > 1 { weekdays.removeAll { $0 == day } } } else { weekdays.append(day); weekdays.sort() }
                        }
                    } label: {
                        Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                            .font(.footnote.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? tint : Palette.raised))
                            .foregroundStyle(on ? Color.white : Palette.ink2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            HStack(spacing: 8) {
                quick("Every day", Array(1...7))
                quick("Weekdays", [2, 3, 4, 5, 6])
                quick("Weekends", [1, 7])
            }
        }
        .padding(.vertical, 4)
    }

    private func quick(_ title: String, _ days: [Int]) -> some View {
        Button(title) { withAnimation(.snappy) { weekdays = days } }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(weekdays == days ? tint : Palette.ink2)
    }
}
