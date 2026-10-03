import SwiftUI

/// The day as a sky: the sun (or moon) moves along an arc in real time, and each habit's lamp sits at its preferred time.
struct SkyHeader: View {
    var day: DayKey
    var isToday: Bool
    var items: [AgendaItem]
    var habits: [UUID: Habit]
    var summary: DaySummary

    /// The arc runs from 4:00 am to 11:30 pm.
    static let arcStart = 240
    static let arcEnd = 1410

    var body: some View {
        TimelineView(.everyMinute) { context in
            let minute = isToday ? TimeOfDay(context.date).minutes : 12 * 60
            let colors = Sky.colors(at: minute)
            let dark = Sky.isDark(at: minute)
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom)
                if dark { Stars().opacity(0.7) }
                GeometryReader { geo in
                    arcLayer(size: geo.size, minute: minute, dark: dark)
                }
                titleBlock(dark: dark)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }
            .frame(height: 248)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
        }
    }

    private func titleBlock(dark: Bool) -> some View {
        let fg: Color = dark ? .white : Color(hex: 0x2A1F16)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isToday ? "Today" : day.formatted("EEEE"))
                    .font(.serif(34, weight: .bold))
                Text(day.formatted("EEEE d MMMM"))
                    .font(.subheadline.weight(.medium))
                    .opacity(0.8)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(summary.done)/\(summary.total)")
                    .font(.rounded(26, weight: .bold))
                    .contentTransition(.numericText(value: Double(summary.done)))
                    .animation(.snappy, value: summary.done)
                Text(summary.total == 0 ? "rest day" : "lamps lit")
                    .font(.caption.weight(.semibold))
                    .opacity(0.8)
            }
        }
        .foregroundStyle(fg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isToday ? "Today, \(summary.done) of \(summary.total) lamps lit" : "\(day.formatted("EEEE d MMMM")), \(summary.done) of \(summary.total) lamps lit")
    }

    private func point(for minute: Int, in size: CGSize) -> CGPoint {
        let left: CGFloat = 26, right = size.width - 26
        let base: CGFloat = size.height - 34, top: CGFloat = 104
        var m = minute
        if m < Self.arcStart - 30 { m += 1440 }
        let t = CGFloat(min(1, max(0, Double(m - Self.arcStart) / Double(Self.arcEnd - Self.arcStart))))
        return CGPoint(x: left + (right - left) * t, y: base - sin(.pi * t) * (base - top))
    }

    private func arcLayer(size: CGSize, minute: Int, dark: Bool) -> some View {
        let lineColor: Color = dark ? .white.opacity(0.35) : Color(hex: 0x2A1F16, opacity: 0.22)
        let timed = items.filter { $0.time != nil }
        return ZStack {
            Path { p in
                for step in 0...60 {
                    let m = Self.arcStart + (Self.arcEnd - Self.arcStart) * step / 60
                    let pt = point(for: m, in: size)
                    if step == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 5]))

            if isToday {
                CelestialBody(isNight: dark)
                    .position(point(for: minute, in: size))
                    .animation(.easeInOut(duration: 1.2), value: minute)
            }

            ForEach(Array(timed.enumerated()), id: \.element.id) { index, item in
                if let time = item.time, let habit = habits[item.habitID] {
                    let base = point(for: time.minutes, in: size)
                    let stack = timed[..<index].filter { abs(($0.time?.minutes ?? 0) - time.minutes) < 25 }.count
                    DiyaView(color: habit.color.color, glow: item.done ? 1 : 0, size: 26, flicker: item.done, seed: Double(index))
                        .position(x: base.x, y: base.y - 14 - CGFloat(stack) * 18)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

private struct CelestialBody: View {
    var isNight: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [(isNight ? Color.white : Palette.flameMid).opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: 34))
                .frame(width: 68, height: 68)
            if isNight {
                Image(systemName: "moon.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: 0xF4EBD0))
            } else {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFE7A3), Palette.flameOuter], startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 22)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct Stars: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 7
            for _ in 0..<40 {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let x = CGFloat(seed >> 33) / CGFloat(UInt32.max) * size.width
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let y = CGFloat(seed >> 33) / CGFloat(UInt32.max) * size.height * 0.75
                let r: CGFloat = (seed >> 60) % 3 == 0 ? 1.3 : 0.8
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.8)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Seven days with a small ring each, Monday first.
struct WeekStrip: View {
    var selected: DayKey
    var today: DayKey
    var summary: (DayKey) -> DaySummary
    var onSelect: (DayKey) -> Void

    var body: some View {
        let start = selected.weekStart
        HStack(spacing: 4) {
            Button { onSelect(selected.adding(-7)) } label: {
                Image(systemName: "chevron.left").font(.footnote.weight(.semibold)).frame(width: 26, height: 44)
            }
            .accessibilityLabel("Previous week")
            ForEach(0..<7, id: \.self) { offset in
                let day = start.adding(offset)
                dayButton(day)
            }
            Button { onSelect(min(today, selected.adding(7))) } label: {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).frame(width: 26, height: 44)
            }
            .disabled(start.adding(7) > today)
            .accessibilityLabel("Next week")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink2)
    }

    private func dayButton(_ day: DayKey) -> some View {
        let future = day > today
        let isSelected = day == selected
        let s = future ? DaySummary(done: 0, total: 0) : summary(day)
        return Button { onSelect(day) } label: {
            VStack(spacing: 4) {
                Text(day.formatted("EEEEE"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(day == today ? Palette.saffron : Palette.ink2)
                ZStack {
                    if isSelected { Circle().fill(Palette.saffron).padding(4) }
                    Ring(fraction: s.fraction, color: isSelected ? Palette.saffron : Palette.saffron.opacity(0.85), lineWidth: 2.5)
                    Text("\(day.day)")
                        .font(.rounded(13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Palette.onSaffron : Palette.ink)
                }
                .frame(width: 36, height: 36)
            }
            .frame(maxWidth: .infinity)
            .opacity(future ? 0.35 : 1)
        }
        .disabled(future)
        .accessibilityLabel("\(day.formatted("EEEE d MMMM")), \(s.done) of \(s.total) done")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
