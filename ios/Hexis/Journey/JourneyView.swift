import SwiftUI

/// Progress: streaks, a mala of votes, a calendar map and timing insights for each habit.
struct JourneyView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    let habits = store.data.activeHabits
                    if habits.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your journey starts with one lamp").font(.serif(22, weight: .bold)).foregroundStyle(Palette.ink)
                                Text("Add a habit and check it off for a few days. Streaks, your mala of votes and a map of every day will appear here.")
                                    .font(.subheadline).foregroundStyle(Palette.ink2)
                            }
                        }
                    } else {
                        overview(habits)
                        Eyebrow(text: "By habit")
                        ForEach(habits) { habit in
                            HabitJourneyCard(habit: habit, stats: store.stats(habit))
                        }
                        reflections
                    }
                }
                .padding(16)
            }
            .background(Palette.paper)
            .navigationTitle("Journey")
        }
    }

    private func overview(_ habits: [Habit]) -> some View {
        let week = store.engine.rate(from: store.today.weekStart, to: store.today)
        let month = store.engine.rate(from: store.today.adding(-29), to: store.today)
        let votes = habits.reduce(0) { $0 + store.stats($1).votes }
        return HStack(spacing: 10) {
            StatTile(label: "This week", value: percent(week), detail: "\(week.kept) of \(week.scheduled) kept")
            StatTile(label: "30 days", value: percent(month), detail: "\(month.kept) of \(month.scheduled) kept")
            StatTile(label: "Votes", value: "\(votes)", detail: "for who you're becoming")
        }
    }

    private func percent(_ r: (kept: Int, scheduled: Int)) -> String {
        r.scheduled == 0 ? "–" : "\(Int((Double(r.kept) / Double(r.scheduled) * 100).rounded()))%"
    }

    @ViewBuilder private var reflections: some View {
        let days = (0..<30).map { store.today.adding(-$0) }.filter { day in
            let r = store.data.record(for: day)
            return !(r.intention ?? "").isEmpty || r.review != nil || !(r.note ?? "").isEmpty
        }
        if !days.isEmpty {
            Eyebrow(text: "Reflections")
                .padding(.top, 8)
            ForEach(days, id: \.self) { day in
                let record = store.data.record(for: day)
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day == store.today ? "Today" : day.formatted("EEEE d MMM"))
                            .font(.footnote.weight(.bold)).foregroundStyle(Palette.saffron)
                        if let intention = record.intention, !intention.isEmpty {
                            Text("Sankalpa: \(intention)").font(.serif(16, weight: .medium)).foregroundStyle(Palette.ink)
                        }
                        if let review = record.review { ReviewSummary(review: review) }
                        if let note = record.note, !note.isEmpty {
                            Text(note).font(.subheadline).foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
        }
    }
}

struct StatTile: View {
    var label: String
    var value: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(Palette.ink2)
            Text(value)
                .font(.rounded(26, weight: .bold))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Text(detail).font(.caption2).foregroundStyle(Palette.ink2).lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.rule))
        .accessibilityElement(children: .combine)
    }
}

struct HabitJourneyCard: View {
    var habit: Habit
    var stats: HabitStats

    @Environment(AppStore.self) private var store

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: habit.symbol).foregroundStyle(habit.color.color)
                    Text(habit.name).font(.serif(20, weight: .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    if stats.streak.current > 0 {
                        Label("\(stats.streak.current)-day chain", systemImage: "flame.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.saffron)
                    }
                }
                HStack(alignment: .center, spacing: 18) {
                    MalaView(beads: stats.malaBeads, malas: stats.malas, color: habit.color.color)
                        .frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 10) {
                        metric("Current chain", "\(stats.streak.current)")
                        metric("Best chain", "\(stats.streak.best)")
                        metric("30 days", stats.rate30.map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
                    }
                }
                if !habit.identity.trimmed.isEmpty {
                    Text("\(stats.votes) votes for being \(habit.identity.trimmed).")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.ink)
                }
                if stats.streak.atRisk {
                    Label("Missed last time. Never miss twice: keep today.", systemImage: "arrow.uturn.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.kumkum)
                }
                HeatmapView(habit: habit, engine: store.engine, weeks: 16)
                ForEach(stats.timing, id: \.slotID) { insight in
                    TimingRow(habit: habit, insight: insight)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.rounded(20, weight: .bold)).foregroundStyle(Palette.ink)
            Text(label).font(.caption).foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 108 beads around a circle, filled as votes add up, with the larger guru bead at the bottom.
struct MalaView: View {
    var beads: Int
    var malas: Int
    var color: Color

    @State private var shown = 0

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 7
                let beadR = max(1.4, radius * .pi / 108 * 0.82)
                for i in 0..<108 {
                    // Start just right of the guru bead and run clockwise.
                    let angle = Double.pi / 2 - Double(i + 1) / 109 * 2 * .pi
                    let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    let rect = CGRect(x: p.x - beadR, y: p.y - beadR, width: beadR * 2, height: beadR * 2)
                    if i < shown {
                        ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    } else {
                        ctx.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.28)), lineWidth: 0.8)
                    }
                }
                let guru = CGPoint(x: center.x, y: center.y + radius)
                let gr = beadR * 2.2
                ctx.fill(Path(ellipseIn: CGRect(x: guru.x - gr, y: guru.y - gr, width: gr * 2, height: gr * 2)), with: .color(malas > 0 ? Palette.saffron : color.opacity(0.4)))
            }
            VStack(spacing: 0) {
                Text("\(beads)")
                    .font(.rounded(26, weight: .bold))
                    .contentTransition(.numericText(value: Double(beads)))
                    .foregroundStyle(Palette.ink)
                Text(malas > 0 ? "of 108 · mala \(malas + 1)" : "of 108")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = beads } }
        .onChange(of: beads) { _, new in withAnimation(.spring) { shown = new } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(beads) of 108 beads on this mala" + (malas > 0 ? ", \(malas) malas completed" : ""))
    }
}

/// Weeks as columns, Monday at the top, colored by how each day went.
struct HeatmapView: View {
    var habit: Habit
    var engine: Engine
    var weeks: Int

    var body: some View {
        let start = engine.today.weekStart.adding(-7 * (weeks - 1))
        let color = habit.color.color
        VStack(alignment: .leading, spacing: 6) {
            Canvas { ctx, size in
                let gap: CGFloat = 3
                let cell = min((size.width - gap * CGFloat(weeks - 1)) / CGFloat(weeks), (size.height - gap * 6) / 7)
                for w in 0..<weeks {
                    for d in 0..<7 {
                        let day = start.adding(w * 7 + d)
                        let rect = CGRect(x: CGFloat(w) * (cell + gap), y: CGFloat(d) * (cell + gap), width: cell, height: cell)
                        let path = Path(roundedRect: rect, cornerRadius: cell * 0.25)
                        let p = engine.progress(habit, on: day)
                        switch p.status {
                        case .done, .clean, .extra, .holding:
                            ctx.fill(path, with: .color(color))
                        case .minimum:
                            ctx.fill(path, with: .color(color.opacity(0.55)))
                        case .partial:
                            ctx.fill(path, with: .color(color.opacity(0.35)))
                        case .missed, .slipped:
                            ctx.fill(path, with: .color(p.done > 0 ? color.opacity(0.3) : Palette.rule))
                        case .pending:
                            ctx.stroke(path, with: .color(color), lineWidth: 1.2)
                        case .rest:
                            let dot = CGRect(x: rect.midX - 1.2, y: rect.midY - 1.2, width: 2.4, height: 2.4)
                            ctx.fill(Path(ellipseIn: dot), with: .color(Palette.ink2.opacity(0.4)))
                        case .future, .notStarted:
                            break
                        }
                    }
                }
            }
            .frame(height: 7 * 14 + 6 * 3)
            HStack(spacing: 12) {
                legend(color, "Kept")
                legend(color.opacity(0.55), "Minimum")
                legend(Palette.rule, "Missed")
                Spacer()
                Text("\(weeks) weeks").font(.caption2).foregroundStyle(Palette.ink2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calendar of the last \(weeks) weeks for \(habit.name)")
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(text).font(.caption2).foregroundStyle(Palette.ink2)
        }
    }
}

/// "You usually do this 40 minutes later than planned. Move it?"
struct TimingRow: View {
    var habit: Habit
    var insight: TimingInsight

    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(habit.color.color)
            VStack(alignment: .leading, spacing: 6) {
                Text("You usually do this around \(insight.typical.displayText), \(abs(insight.drift)) min \(insight.drift > 0 ? "after" : "before") your plan of \(insight.planned.displayText).")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                Button("Move it to \(insight.typical.displayText)") {
                    store.applyTimingSuggestion(habitID: habit.id, slotID: insight.slotID, to: insight.typical)
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(habit.color.color)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(habit.color.color.opacity(0.08)))
    }
}
