import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }

    /// A color that follows light and dark mode.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

/// Neutral surfaces with one teal accent; habit colors carry the rest.
enum Palette {
    static let paper = Color.dynamic(light: 0xF5F5F7, dark: 0x0A0A0C)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x17171B)
    static let raised = Color.dynamic(light: 0xEDEDF1, dark: 0x232329)
    static let ink = Color.dynamic(light: 0x111114, dark: 0xF5F5F7)
    static let ink2 = Color.dynamic(light: 0x6B6B76, dark: 0x9C9CA8)
    static let rule = Color.dynamic(light: 0xE4E4EA, dark: 0x2A2A31)
    static let accent = Color.dynamic(light: 0x0D9488, dark: 0x2DD4BF)
    static let onAccent = Color.dynamic(light: 0xFFFFFF, dark: 0x04201D)
    static let danger = Color.dynamic(light: 0xDC2626, dark: 0xF87171)
    static let success = Color.dynamic(light: 0x16A34A, dark: 0x4ADE80)
    /// Second stop of the brand gradient, used with `accent`.
    static let accent2 = Color.dynamic(light: 0x4F46E5, dark: 0x818CF8)

    static let sunCore = Color(hex: 0xFFF6DE)
    static let sunGlow = Color(hex: 0xFFC94F)
    static let sunEdge = Color(hex: 0xF5881F)
}

extension HabitColor {
    var color: Color {
        switch self {
        case .orange: return .dynamic(light: 0xEA580C, dark: 0xFB923C)
        case .red: return .dynamic(light: 0xDC2626, dark: 0xF87171)
        case .yellow: return .dynamic(light: 0xCA8A04, dark: 0xFACC15)
        case .teal: return .dynamic(light: 0x0D9488, dark: 0x2DD4BF)
        case .green: return .dynamic(light: 0x16A34A, dark: 0x4ADE80)
        case .pink: return .dynamic(light: 0xDB2777, dark: 0xF472B6)
        case .indigo: return .dynamic(light: 0x4F46E5, dark: 0x818CF8)
        case .graphite: return .dynamic(light: 0x52525B, dark: 0xA1A1AA)
        }
    }

    var label: String { rawValue.capitalized }
}

extension Font {
    /// SF Pro for titles and headings.
    static func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .default) }
    /// New York, the system serif, kept for quotes so they read like something worth pausing on.
    static func quote(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .serif) }
    /// SF Rounded for numbers and counters.
    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

/// The sky above the Today screen, shifting from pre-dawn indigo to morning gold to dusk.
enum Sky {
    private struct Stop { let minute: Int; let top: UInt32; let bottom: UInt32 }

    private static let stops: [Stop] = [
        Stop(minute: 0, top: 0x0A0F26, bottom: 0x1B1F4B),
        Stop(minute: 270, top: 0x141A45, bottom: 0x3E3477),
        Stop(minute: 360, top: 0x3A3A7A, bottom: 0xEE9F5C),
        Stop(minute: 450, top: 0x7FAED3, bottom: 0xFADDAA),
        Stop(minute: 780, top: 0x8DC3E6, bottom: 0xF6EAD2),
        Stop(minute: 1050, top: 0xE29A68, bottom: 0xF6D6A3),
        Stop(minute: 1140, top: 0x4A3A6B, bottom: 0xE07A5F),
        Stop(minute: 1230, top: 0x161C42, bottom: 0x2E2A5C),
        Stop(minute: 1440, top: 0x0A0F26, bottom: 0x1B1F4B),
    ]

    static func colors(at minute: Int) -> (top: Color, bottom: Color) {
        let m = ((minute % 1440) + 1440) % 1440
        guard let upper = stops.firstIndex(where: { $0.minute >= m }), upper > 0 else {
            return (Color(hex: stops[0].top), Color(hex: stops[0].bottom))
        }
        let a = stops[upper - 1], b = stops[upper]
        let t = Double(m - a.minute) / Double(max(1, b.minute - a.minute))
        return (mix(a.top, b.top, t), mix(a.bottom, b.bottom, t))
    }

    /// True when the sky is dark enough that text on it should be light.
    static func isDark(at minute: Int) -> Bool {
        let m = ((minute % 1440) + 1440) % 1440
        return m < 400 || m > 1110
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func channel(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) / 255 }
        return Color(.sRGB,
                     red: channel(a, 16) + (channel(b, 16) - channel(a, 16)) * t,
                     green: channel(a, 8) + (channel(b, 8) - channel(a, 8)) * t,
                     blue: channel(a, 0) + (channel(b, 0) - channel(a, 0)) * t)
    }
}

extension TimeOfDay {
    var displayText: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: DayKey.today().date(at: self))
    }

    /// A Date today at this time, for DatePicker bindings.
    var asDate: Date { DayKey.today().date(at: self) }
}

extension DayKey {
    func formatted(_ template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date(at: TimeOfDay(12, 0)))
    }
}
