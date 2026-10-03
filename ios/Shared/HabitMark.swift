import SwiftUI

/// How a habit's mark should look.
enum MarkState: Equatable {
    /// Not done yet. `progress` fills the ring for counts, timers and partly done days.
    case open(progress: Double)
    case done
    /// The hard-day minimum: the chain is safe, the full habit isn't done.
    case minimum
    /// A quit habit that slipped.
    case slipped

    var isDone: Bool { self == .done }
}

/// A habit's ring: it fills with progress, then becomes a solid check with a small burst.
struct HabitMark: View {
    var color: Color
    var symbol: String
    var state: MarkState
    var size: CGFloat = 44
    /// Shown inside the solid disc when done. Quit habits keep their own symbol.
    var doneSymbol: String = "checkmark"
    /// The burst on completion. Off in widgets.
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 idle, 1 burst starting, 2 burst expanding.
    @State private var phase = 0

    private var line: CGFloat { max(2, size * 0.085) }

    var body: some View {
        ZStack {
            if animated && !reduceMotion { burstLayer }
            switch state {
            case .open(let progress):
                Circle().stroke(color.opacity(0.2), lineWidth: line)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(progress > 0 ? 1 : 0)
                glyph(symbol, color: color)
            case .done:
                Circle().fill(color)
                    .shadow(color: color.opacity(0.35), radius: size * 0.15, y: size * 0.05)
                glyph(doneSymbol, color: .white, weight: .bold)
            case .minimum:
                Circle().fill(color.opacity(0.18))
                Circle().stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round, dash: [size * 0.12, size * 0.08]))
                glyph("checkmark", color: color, weight: .bold)
            case .slipped:
                Circle().stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: line, dash: [size * 0.06, size * 0.08]))
                glyph("xmark", color: color.opacity(0.8), weight: .semibold)
            }
        }
        .padding(line / 2)
        .frame(width: size, height: size)
        .scaleEffect(phase == 1 ? 1.12 : 1)
        .animation(.spring(response: 0.38, dampingFraction: 0.62), value: state)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: phase)
        .onChange(of: state.isDone) { _, done in
            guard done, animated, !reduceMotion else { return }
            Task { @MainActor in
                phase = 1
                try? await Task.sleep(nanoseconds: 20_000_000)
                withAnimation(.easeOut(duration: 0.55)) { phase = 2 }
                try? await Task.sleep(nanoseconds: 650_000_000)
                phase = 0
            }
        }
    }

    private func glyph(_ name: String, color: Color, weight: Font.Weight = .semibold) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.4, weight: weight, design: .rounded))
            .foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace))
    }

    /// An expanding ring and eight sparks.
    private var burstLayer: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: line)
                .scaleEffect(phase == 2 ? 1.8 : 1)
                .opacity(phase == 1 ? 0.7 : 0)
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                let reach = size * (phase == 2 ? 0.95 : 0.45)
                Circle()
                    .fill(color)
                    .frame(width: size * 0.09, height: size * 0.09)
                    .offset(x: cos(angle) * reach, y: sin(angle) * reach)
                    .opacity(phase == 1 ? 0.9 : 0)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A small row of finished marks in different colors, for "all done" moments.
struct DoneRow: View {
    var count: Int = 5
    var size: CGFloat = 34
    var animated: Bool = true

    var body: some View {
        HStack(spacing: size * 0.18) {
            ForEach(0..<count, id: \.self) { i in
                HabitMark(color: HabitColor.allCases[(i * 3) % HabitColor.allCases.count].color, symbol: "checkmark", state: .done, size: size, animated: animated)
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        HabitMark(color: HabitColor.teal.color, symbol: "drop.fill", state: .open(progress: 0), size: 56)
        HabitMark(color: HabitColor.indigo.color, symbol: "book.fill", state: .open(progress: 0.4), size: 56)
        HabitMark(color: HabitColor.orange.color, symbol: "figure.walk", state: .done, size: 56)
        HabitMark(color: HabitColor.green.color, symbol: "leaf.fill", state: .minimum, size: 56)
        HabitMark(color: HabitColor.red.color, symbol: "nosign", state: .slipped, size: 56)
    }
    .padding()
    .background(Palette.paper)
}
