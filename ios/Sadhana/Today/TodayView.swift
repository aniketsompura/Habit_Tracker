import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(TimerController.self) private var timer
    @State private var selected: DayKey?

    var body: some View {
        let day = selected ?? store.today
        let isToday = day == store.today
        let engine = store.engine
        let items = engine.agenda(on: day)
        let habits = Dictionary(uniqueKeysWithValues: store.data.habits.map { ($0.id, $0) })
        let summary = DaySummary(done: items.filter(\.done).count, total: items.count)
        let record = store.data.record(for: day)

        GeometryReader { geo in
            ZStack(alignment: .top) {
                Palette.paper.ignoresSafeArea()
                List {
                    SkyHeader(day: day, isToday: isToday, items: items, habits: habits, summary: summary)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    WeekStrip(selected: day, today: store.today, summary: { engine.summary(on: $0) }) { picked in
                        withAnimation(.snappy) { selected = picked == store.today ? nil : picked }
                    }
                    .plainRow(vertical: 2)

                    if isToday {
                        todayCards(items: items, habits: habits, record: record)
                    } else {
                        pastDayCard(record: record, day: day)
                    }

                    if store.data.activeHabits.isEmpty {
                        EmptyToday().plainRow()
                    } else if items.isEmpty {
                        Text(isToday ? "Nothing scheduled today. Rest is part of the practice." : "Nothing was scheduled on this day.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                            .plainRow()
                    }

                    ForEach(periods(items), id: \.self) { period in
                        Section {
                            ForEach(items.filter { $0.period == period }) { item in
                                if let habit = habits[item.habitID] {
                                    AgendaRow(item: item, habit: habit, day: day, isToday: isToday,
                                              progress: engine.progress(habit, on: day), stats: store.stats(habit),
                                              isFocus: isToday && record.focusHabitID == habit.id,
                                              isTimerRunning: isToday && timer.isRunning(habitID: habit.id),
                                              now: TimeOfDay(Date()))
                                    .plainRow(vertical: 5)
                                }
                            }
                        } header: {
                            PeriodHeader(period: period)
                        }
                        .listSectionSeparator(.hidden)
                    }

                    if isToday && showReviewCard {
                        ReviewCard(reviewed: record.review != nil).plainRow()
                    }
                    Color.clear.frame(height: 24).plainRow()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
                .animation(.snappy, value: items)

                TimelineView(.everyMinute) { context in
                    Sky.colors(at: isToday ? TimeOfDay(context.date).minutes : 720).top
                        .frame(height: geo.safeAreaInsets.top)
                        .offset(y: -geo.safeAreaInsets.top)
                        .allowsHitTesting(false)
                }
                .frame(height: 0, alignment: .top)
            }
        }
        .onChange(of: store.today) { _, _ in selected = nil }
    }

    @ViewBuilder
    private func todayCards(items: [AgendaItem], habits: [UUID: Habit], record: DayRecord) -> some View {
        let engine = store.engine
        let now = TimeOfDay(Date())
        let showOriginal = store.prefs.showSanskrit

        if let fresh = engine.freshStart(on: store.today), store.flag("fresh") != store.today.raw {
            FreshStartCard(kind: fresh, quote: store.quote(.fresh)) {
                withAnimation(.snappy) { store.setFlag("fresh", store.today.raw) }
            }
            .plainRow()
        }

        let atRisk = engine.atRiskHabits()
        if !atRisk.isEmpty {
            NeverMissTwiceCard(habits: atRisk, quote: store.quote(.miss), showOriginal: showOriginal).plainRow()
        }

        if store.prefs.morningRitual && !store.data.activeHabits.isEmpty && (record.hasSankalpa || now.minutes < 15 * 60) {
            SankalpaCard(record: record, focus: record.focusHabitID.flatMap { habits[$0] }).plainRow()
        }

        if let next = engine.upNext(on: store.today, now: now), let habit = habits[next.habitID] {
            UpNextCard(item: next, habit: habit, now: now, isTimerRunning: timer.isRunning(habitID: habit.id))
                .plainRow()
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .id(next.id)
        } else if engine.summary(on: store.today).isComplete {
            AllLitCard(quote: store.quote(.dayComplete), showOriginal: showOriginal).plainRow()
        }

        QuoteCard(quote: store.dailyQuote, title: "Today's wisdom", showOriginal: showOriginal).plainRow()
    }

    @ViewBuilder
    private func pastDayCard(record: DayRecord, day: DayKey) -> some View {
        if record.hasSankalpa || record.review != nil || !(record.note ?? "").isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    if let intention = record.intention, !intention.isEmpty {
                        Eyebrow(text: "Sankalpa", symbol: "sparkle")
                        Text(intention).font(.serif(17, weight: .medium)).foregroundStyle(Palette.ink)
                    }
                    if let review = record.review {
                        Eyebrow(text: "Evening review", symbol: "moon.stars")
                        ReviewSummary(review: review)
                    }
                    if let note = record.note, !note.isEmpty {
                        Eyebrow(text: "Log", symbol: "text.alignleft")
                        Text(note).font(.subheadline).foregroundStyle(Palette.ink)
                    }
                }
            }
            .plainRow()
        }
        Text("You can still fill in this day. Tap a lamp to light it.")
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            .plainRow(vertical: 0)
    }

    private var showReviewCard: Bool {
        guard store.prefs.eveningReview else { return false }
        let now = TimeOfDay(Date())
        return now.minutes >= min(store.prefs.eveningTime.minutes - 60, 18 * 60) || store.data.record(for: store.today).review != nil
    }

    private func periods(_ items: [AgendaItem]) -> [DayPeriod] {
        DayPeriod.allCases.filter { period in items.contains { $0.period == period } }
    }
}

struct PeriodHeader: View {
    var period: DayPeriod

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: period.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.saffron)
            Text(period.title)
                .font(.serif(17, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text(period.caption)
                .font(.caption)
                .foregroundStyle(Palette.ink2)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .accessibilityAddTraits(.isHeader)
    }
}

struct AllLitCard: View {
    var quote: Quote
    var showOriginal: Bool

    var body: some View {
        Card(tint: Palette.saffron) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: -6) {
                    ForEach(0..<5, id: \.self) { i in
                        DiyaView(color: HabitColor.allCases[i % HabitColor.allCases.count].color, glow: 1, size: 34, seed: Double(i))
                    }
                }
                Text("All lamps lit").font(.serif(22, weight: .bold)).foregroundStyle(Palette.ink)
                QuoteBlock(quote: quote, showOriginal: showOriginal, size: 15)
            }
        }
    }
}

struct ReviewSummary: View {
    var review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            line("Cured", review.cured)
            line("Resisted", review.resisted)
            line("Better", review.better)
        }
    }

    @ViewBuilder private func line(_ label: String, _ text: String) -> some View {
        if !text.trimmed.isEmpty {
            (Text(label + ": ").font(.footnote.weight(.semibold)).foregroundColor(Palette.ink2) + Text(text).font(.footnote).foregroundColor(Palette.ink))
        }
    }
}

/// First run of the Today screen, before any habits exist.
struct EmptyToday: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                DiyaView(color: Palette.saffron, glow: 0, size: 64, flicker: false)
                Text("Light your first lamp").font(.serif(24, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Add a habit and the time you want to do it. Each day you do it, its lamp lights on the sky above.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HabitTemplate.all.prefix(6)) { template in
                            Button {
                                store.save(template.makeHabit(createdOn: store.today), isNew: true)
                            } label: {
                                Label(template.name, systemImage: template.symbol)
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(template.color.color.opacity(0.14)))
                                    .foregroundStyle(template.color.color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button {
                    store.route = .newHabit
                } label: {
                    Text("Create your own habit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Palette.saffron))
                        .foregroundStyle(Palette.onSaffron)
                }
                .buttonStyle(LampPressStyle())
            }
        }
    }
}

extension View {
    /// A list row that looks like a free-standing card on the page.
    func plainRow(vertical: CGFloat = 6) -> some View {
        listRowInsets(EdgeInsets(top: vertical, leading: 16, bottom: vertical, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
