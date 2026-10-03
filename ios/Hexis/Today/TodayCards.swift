import SwiftUI

/// "Up next" with a single obvious action.
struct UpNextCard: View {
    var item: AgendaItem
    var habit: Habit
    var now: TimeOfDay
    var isTimerRunning: Bool

    @Environment(AppStore.self) private var store

    var body: some View {
        Card(tint: habit.color.color) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: habit.symbol)
                    .font(.title2)
                    .foregroundStyle(habit.color.color)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(habit.color.color.opacity(0.14)))
                    .symbolEffect(.pulse, options: .repeating, isActive: isDue)
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: "Up next · \(timing)")
                    Text(habit.name).font(.heading(20, weight: .semibold)).foregroundStyle(Palette.ink)
                    if !plan.isEmpty {
                        Text(plan).font(.footnote).foregroundStyle(Palette.ink2).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            actionButton
                .padding(.top, 12)
        }
    }

    private var isDue: Bool {
        guard let time = item.time else { return false }
        return time.dayOrder <= now.dayOrder + 5
    }

    private var timing: String {
        guard let time = item.time else { return "any time today" }
        return Describe.relative(time, now: now)
    }

    private var plan: String {
        let sentence = ReminderText.whenThen(habit)
        if !sentence.isEmpty { return sentence }
        if !habit.identity.trimmed.isEmpty { return "Another vote for being \(habit.identity.trimmed)." }
        return ""
    }

    @ViewBuilder private var actionButton: some View {
        let title: String = {
            switch habit.kind {
            case .count: return "Add one · \(item.amount)/\(item.target)"
            case .timed: return isTimerRunning ? "Return to timer" : "Start \(habit.target)-minute timer"
            default: return "Mark done"
            }
        }()
        Button {
            store.tap(item, on: store.today)
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(habit.color.color))
                .foregroundStyle(.white)
        }
        .buttonStyle(PressStyle())
    }
}

struct QuoteCard: View {
    var quote: Quote
    var title: String
    var showOriginal: Bool

    @Environment(AppStore.self) private var store

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: title, symbol: "quote.opening")
                    Spacer()
                    TraditionMark(tradition: quote.tradition)
                    Button {
                        store.toggleFavorite(quote)
                    } label: {
                        Image(systemName: store.isFavorite(quote) ? "heart.fill" : "heart")
                            .foregroundStyle(store.isFavorite(quote) ? Palette.danger : Palette.ink2)
                            .symbolEffect(.bounce, value: store.isFavorite(quote))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.isFavorite(quote) ? "Remove from saved quotes" : "Save quote")
                }
                QuoteBlock(quote: quote, showOriginal: showOriginal)
            }
        }
    }
}

/// Morning Sankalpa: an invitation before it's set, the intention afterwards.
struct SankalpaCard: View {
    var record: DayRecord
    var focus: Habit?

    @Environment(AppStore.self) private var store

    var body: some View {
        Card(tint: record.hasSankalpa ? nil : Palette.accent) {
            if record.hasSankalpa {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Today's Sankalpa", symbol: "sparkle")
                        if let intention = record.intention, !intention.isEmpty {
                            Text(intention).font(.heading(18, weight: .medium)).foregroundStyle(Palette.ink)
                        }
                        if let focus {
                            Label("Non-negotiable: \(focus.name)", systemImage: "star.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                        }
                    }
                    Spacer()
                    Button("Edit") { store.route = .sankalpa }
                        .font(.footnote.weight(.semibold))
                }
            } else {
                Button { store.route = .sankalpa } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(Palette.accent)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Palette.accent.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Set today's Sankalpa").font(.heading(19, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text("One intention and one habit that can't slip. 20 seconds.")
                                .font(.footnote).foregroundStyle(Palette.ink2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(Palette.ink2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ReviewCard: View {
    var reviewed: Bool

    @Environment(AppStore.self) private var store

    var body: some View {
        Card {
            Button { store.route = .review } label: {
                HStack(spacing: 14) {
                    Image(systemName: reviewed ? "moon.stars.fill" : "moon.stars")
                        .font(.title2)
                        .foregroundStyle(HabitColor.indigo.color)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(reviewed ? "Day reviewed" : "Evening review").font(.heading(19, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(reviewed ? "Tap to read or change your answers." : "Seneca's three questions before sleep. Two minutes.")
                            .font(.footnote).foregroundStyle(Palette.ink2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Palette.ink2)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// Shown after a missed day: names the habits at risk without blame, with a recovery quote.
struct NeverMissTwiceCard: View {
    var habits: [Habit]
    var quote: Quote
    var showOriginal: Bool

    var body: some View {
        Card(tint: Palette.danger) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Never miss twice", symbol: "arrow.uturn.up")
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                QuoteBlock(quote: quote, showOriginal: false, size: 15, lineLimit: 4)
            }
        }
    }

    private var message: String {
        let names = habits.map(\.name)
        let list = names.count <= 2 ? names.joined(separator: " and ") : names.dropLast().joined(separator: ", ") + " and " + names.last!
        return "\(list) slipped last time. That's human. Keep today and the chain survives. Doing the minimum counts."
    }
}

struct FreshStartCard: View {
    var kind: FreshStart
    var quote: Quote
    var onDismiss: () -> Void

    var body: some View {
        Card(tint: Palette.accent) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow(text: title, symbol: "sunrise")
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2).frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
                Text(message).font(.subheadline).foregroundStyle(Palette.ink)
                QuoteBlock(quote: quote, showOriginal: false, size: 15, lineLimit: 4)
            }
        }
    }

    private var title: String {
        switch kind {
        case .week: return "A fresh week"
        case .month: return "A fresh month"
        case .year: return "A fresh year"
        case .birthday: return "A new year of your life"
        }
    }

    private var message: String {
        switch kind {
        case .birthday: return "Happy birthday. Whatever last year held, today starts a new one. Choose one habit to carry into it."
        default: return "Fresh starts are a good moment to begin again. Whatever last \(kind == .week ? "week" : kind == .month ? "month" : "year") held, today is a clean page."
        }
    }
}
