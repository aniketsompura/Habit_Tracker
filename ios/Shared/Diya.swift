import SwiftUI

/// A teardrop flame: pointed tip, round base.
struct FlameShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let tip = CGPoint(x: r.midX, y: r.minY)
        let base = CGPoint(x: r.midX, y: r.maxY)
        p.move(to: tip)
        p.addCurve(to: base, control1: CGPoint(x: r.midX + w * 0.14, y: r.minY + h * 0.36), control2: CGPoint(x: r.maxX + w * 0.06, y: r.maxY))
        p.addCurve(to: tip, control1: CGPoint(x: r.minX - w * 0.06, y: r.maxY), control2: CGPoint(x: r.midX - w * 0.14, y: r.minY + h * 0.36))
        p.closeSubpath()
        return p
    }
}

/// The clay bowl of a diya, with its pinched spout on the right.
struct BowlShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let rim = CGPoint(x: r.minX, y: r.minY + h * 0.22)
        let spout = CGPoint(x: r.maxX, y: r.minY)
        p.move(to: rim)
        p.addQuadCurve(to: spout, control: CGPoint(x: r.minX + w * 0.62, y: r.minY + h * 0.42))
        p.addCurve(to: CGPoint(x: r.midX - w * 0.04, y: r.maxY), control1: CGPoint(x: r.maxX - w * 0.1, y: r.minY + h * 0.2), control2: CGPoint(x: r.maxX - w * 0.08, y: r.maxY))
        p.addCurve(to: rim, control1: CGPoint(x: r.minX + w * 0.12, y: r.maxY), control2: CGPoint(x: r.minX - w * 0.02, y: r.minY + h * 0.55))
        p.closeSubpath()
        return p
    }
}

/// A clay lamp that lights when a habit is done.
///
/// `glow` 0 is unlit, 1 fully lit; a smaller value draws the small flame of a minimum day.
struct DiyaView: View {
    var color: Color
    var glow: Double
    var size: CGFloat = 44
    /// Gentle flicker. Off in widgets and when Reduce Motion is on.
    var flicker: Bool = true
    var seed: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let lit = glow > 0.01
        ZStack {
            if lit {
                Circle()
                    .fill(RadialGradient(colors: [Palette.flameMid.opacity(0.55 * glow), Palette.flameOuter.opacity(0.0)],
                                         center: .center, startRadius: 0, endRadius: size * 0.55))
                    .frame(width: size * 1.1, height: size * 1.1)
                    .offset(y: -size * 0.16)
                    .blendMode(.plusLighter)
            }
            flame
                .frame(width: size * 0.34, height: size * 0.5)
                .scaleEffect(lit ? max(0.45, glow) : 0.01, anchor: .bottom)
                .opacity(lit ? 1 : 0)
                .offset(y: -size * 0.2)
            wick
                .offset(y: size * 0.07)
            bowl
                .frame(width: size * 0.86, height: size * 0.36)
                .offset(y: size * 0.27)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.42, dampingFraction: 0.55), value: glow)
    }

    @ViewBuilder private var flame: some View {
        if flicker && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 24)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let sway = sin(t * 5.3 + seed) * 2.2 + sin(t * 11.7 + seed * 2) * 1.2
                let stretch = 1 + sin(t * 8.1 + seed) * 0.05 + sin(t * 17.3 + seed) * 0.03
                flameLayers
                    .scaleEffect(x: 2 - stretch, y: stretch, anchor: .bottom)
                    .rotationEffect(.degrees(sway), anchor: .bottom)
            }
        } else {
            flameLayers
        }
    }

    private var flameLayers: some View {
        ZStack(alignment: .bottom) {
            FlameShape().fill(LinearGradient(colors: [Palette.ember, Palette.flameOuter], startPoint: .top, endPoint: .bottom))
            FlameShape().fill(Palette.flameMid).scaleEffect(0.72, anchor: .bottom)
            FlameShape().fill(Palette.flameCore).scaleEffect(0.42, anchor: .bottom)
        }
    }

    private var wick: some View {
        Capsule()
            .fill(glow > 0.01 ? Color(hex: 0x3B2416) : Palette.ink2.opacity(0.6))
            .frame(width: size * 0.045, height: size * 0.13)
    }

    private var bowl: some View {
        ZStack {
            BowlShape()
                .fill(LinearGradient(colors: [color.opacity(glow > 0.01 ? 1 : 0.42), color.opacity(glow > 0.01 ? 0.78 : 0.3)], startPoint: .top, endPoint: .bottom))
            BowlShape()
                .stroke(color.opacity(glow > 0.01 ? 0 : 0.9), lineWidth: max(1, size * 0.035))
            Ellipse()
                .fill(Color.black.opacity(glow > 0.01 ? 0.22 : 0.08))
                .frame(width: size * 0.55, height: size * 0.07)
                .offset(x: -size * 0.04, y: -size * 0.085)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        DiyaView(color: HabitColor.saffron.color, glow: 0, size: 64)
        DiyaView(color: HabitColor.peacock.color, glow: 0.55, size: 64)
        DiyaView(color: HabitColor.lotus.color, glow: 1, size: 64)
    }
    .padding()
    .background(Palette.paper)
}
