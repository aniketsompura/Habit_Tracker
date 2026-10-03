import SwiftUI

/// A rounded card on the page background.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.card)
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(tint ?? Palette.rule.opacity(0.6), lineWidth: tint == nil ? 0.5 : 1.5)
                    )
            )
    }
}

struct Eyebrow: View {
    var text: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.bold)) }
            Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(1.1)
        }
        .foregroundStyle(Palette.ink2)
    }
}

/// A quote with its source, and the Sanskrit original when there is one.
struct QuoteBlock: View {
    var quote: Quote
    var showOriginal: Bool
    var size: CGFloat = 17
    var lineLimit: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showOriginal, let original = quote.original {
                Text(original)
                    .font(.system(size: size - 1, weight: .medium))
                    .foregroundStyle(Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
                if let transliteration = quote.transliteration {
                    Text(transliteration)
                        .font(.system(size: size - 4, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(quote.text)
                .font(.quote(size))
                .foregroundStyle(Palette.ink)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: lineLimit == nil)
            Text("— \(quote.cite)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Tradition-colored dot used to tell Stoic from Hindu quotes at a glance.
struct TraditionMark: View {
    var tradition: QuoteTradition

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: tradition == .stoic ? "building.columns" : "sun.and.horizon")
            Text(tradition == .stoic ? "Stoic" : "Hindu")
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(tradition == .stoic ? HabitColor.graphite.color : Palette.accent)
    }
}

struct ToastView: View {
    var toast: Toast
    var showOriginal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(toast.message, systemImage: toast.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            if let quote = toast.quote {
                Text("“\(quote.text)”")
                    .font(.quote(14))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(3)
                Text(quote.cite).font(.caption2.weight(.semibold)).foregroundStyle(Palette.ink2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

/// A progress ring.
struct Ring: View {
    var fraction: Double
    var color: Color
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fraction)
    }
}

/// Text helpers shared by several screens.
enum Describe {
    static func weekdays(_ days: [Int]) -> String {
        let set = Set(days)
        if set.count == 7 { return "Every day" }
        if set == Set([2, 3, 4, 5, 6]) { return "Weekdays" }
        if set == Set([1, 7]) { return "Weekends" }
        let names = Calendar.current.shortWeekdaySymbols
        return [2, 3, 4, 5, 6, 7, 1].filter(set.contains).map { names[$0 - 1] }.joined(separator: ", ")
    }

    static func goal(_ habit: Habit) -> String {
        switch habit.kind {
        case .check: return habit.slots.count > 1 ? "\(habit.slots.count) times a day" : "Once a day"
        case .count: return "\(habit.target) \(habit.unitLabel) a day"
        case .timed: return "\(habit.target) min" + (habit.slots.count > 1 ? " × \(habit.slots.count)" : "")
        case .quit: return "Avoid"
        }
    }

    static func times(_ habit: Habit) -> String {
        let times = habit.sortedSlots.map(\.time.displayText)
        if times.isEmpty { return habit.kind == .quit ? "No risky time set" : "Any time" }
        return times.joined(separator: " · ")
    }

    static func relative(_ time: TimeOfDay, now: TimeOfDay) -> String {
        let diff = time.dayOrder - now.dayOrder
        if abs(diff) <= 5 { return "now" }
        if diff > 0 { return diff < 60 ? "in \(diff) min" : "at \(time.displayText)" }
        let late = -diff
        return late < 60 ? "\(late) min ago" : "since \(time.displayText)"
    }
}

extension View {
    /// Liquid Glass on iOS 26 and later; a blurred material on earlier versions.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Palette.rule, lineWidth: 1))
        }
    }
}
