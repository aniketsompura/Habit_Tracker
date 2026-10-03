import SwiftUI

struct HabitsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                let active = store.data.activeHabits
                if active.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No habits yet").font(.display(20, weight: .semibold))
                            Text("Tap + to add one, or start from a template in the editor.")
                                .font(.subheadline).foregroundStyle(Palette.ink2)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Palette.card)
                }
                if !active.isEmpty {
                    Section {
                        ForEach(active) { habit in
                            Button { store.route = .editHabit(habit.id) } label: {
                                HabitListRow(habit: habit, stats: store.stats(habit))
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button { store.setArchived(habit, true) } label: { Label("Archive", systemImage: "archivebox") }
                                    .tint(Palette.ink2)
                            }
                        }
                        .onMove { store.move(from: $0, to: $1) }
                    } header: {
                        Text("Tracking")
                    } footer: {
                        Text("Hold and drag to reorder. Swipe left to archive; archived habits keep their history.")
                    }
                    .listRowBackground(Palette.card)
                }
                let archived = store.data.archivedHabits
                if !archived.isEmpty {
                    Section("Archived") {
                        ForEach(archived) { habit in
                            HStack {
                                Image(systemName: habit.symbol).foregroundStyle(habit.color.color).frame(width: 28)
                                Text(habit.name).foregroundStyle(Palette.ink2)
                                Spacer()
                                Button("Restore") { store.setArchived(habit, false) }
                                    .font(.footnote.weight(.semibold))
                                    .buttonStyle(.borderless)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { store.route = .editHabit(habit.id) }
                        }
                    }
                    .listRowBackground(Palette.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper)
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.route = .newHabit } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New habit")
                }
            }
        }
    }
}

struct HabitListRow: View {
    var habit: Habit
    var stats: HabitStats

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: habit.symbol)
                .font(.title3)
                .foregroundStyle(habit.color.color)
                .frame(width: 42, height: 42)
                .background(Circle().fill(habit.color.color.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                Text("\(Describe.goal(habit)) · \(Describe.weekdays(habit.weekdays))")
                    .font(.footnote).foregroundStyle(Palette.ink2)
                HStack(spacing: 4) {
                    Image(systemName: habit.kind == .quit ? "exclamationmark.shield" : "bell")
                    Text(Describe.times(habit))
                }
                .font(.caption).foregroundStyle(Palette.ink2)
            }
            Spacer()
            if stats.streak.current > 0 {
                Label("\(stats.streak.current)", systemImage: "flame.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
