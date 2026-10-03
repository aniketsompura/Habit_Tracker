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

/// Sandalwood paper by day, temple stone by night.
enum Palette {
    static let paper = Color.dynamic(light: 0xF6EFE4, dark: 0x13100E)
    static let card = Color.dynamic(light: 0xFFFBF4, dark: 0x1E1915)
    static let raised = Color.dynamic(light: 0xF0E6D6, dark: 0x2A221C)
    static let ink = Color.dynamic(light: 0x2A1F16, dark: 0xF3EADF)
    static let ink2 = Color.dynamic(light: 0x7B6A59, dark: 0xA99A88)
    static let rule = Color.dynamic(light: 0xE6D8C3, dark: 0x352B24)
    static let saffron = Color.dynamic(light: 0xD26A0A, dark: 0xF5A445)
    static let onSaffron = Color.dynamic(light: 0xFFFFFF, dark: 0x1A120B)
    static let kumkum = Color.dynamic(light: 0xB3262C, dark: 0xF07A74)
    static let tulsi = Color.dynamic(light: 0x3F7D3A, dark: 0x8BCB7F)

    static let flameCore = Color(hex: 0xFFF6DE)
    static let flameMid = Color(hex: 0xFFC94F)
    static let flameOuter = Color(hex: 0xF5881F)
    static let ember = Color(hex: 0xE2541C)
}

extension HabitColor {
    var color: Color {
        switch self {
        case .saffron: return .dynamic(light: 0xD26A0A, dark: 0xF5A445)
        case .kumkum: return .dynamic(light: 0xB3262C, dark: 0xF07A74)
        case .turmeric: return .dynamic(light: 0xB98700, dark: 0xF2C64E)
        case .peacock: return .dynamic(light: 0x0E6C78, dark: 0x4FC4D0)
        case .tulsi: return .dynamic(light: 0x3F7D3A, dark: 0x8BCB7F)
        case .lotus: return .dynamic(light: 0xBD3F76, dark: 0xF290B9)
        case .indigo: return .dynamic(light: 0x3A3F9C, dark: 0xA3A8F6)
        case .marble: return .dynamic(light: 0x6E6A63, dark: 0xCBC6BC)
        }
    }

    var label: String {
        switch self {
        case .saffron: return "Saffron"
        case .kumkum: return "Kumkum"
        case .turmeric: return "Turmeric"
        case .peacock: return "Peacock"
        case .tulsi: return "Tulsi"
        case .lotus: return "Lotus"
        case .indigo: return "Indigo"
        case .marble: return "Marble"
        }
    }
}

extension Font {
    /// New York, the system serif, for titles and quotes.
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .serif) }
    /// SF Rounded for numbers and counters.
    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

/// The sky above the Today screen, shifting from Brahma muhurta indigo to dawn saffron to dusk.
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
