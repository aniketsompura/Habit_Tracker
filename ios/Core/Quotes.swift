import Foundation

public enum QuoteTradition: String, Codable, Sendable {
    case stoic, hindu
}

/// Moments a quote fits, so the right words show up at the right time.
public enum QuoteMoment: String, Codable, CaseIterable, Sendable {
    case morning, evening, miss, slip, urge, streak, newHabit, fresh, dayComplete, minimum, timer, general
}

public struct Quote: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var text: String
    /// Short attribution, such as "Bhagavad Gita 2.47" or "Seneca, Letters 1".
    public var cite: String
    public var tradition: QuoteTradition
    /// Original script, for Sanskrit and Hindi sources.
    public var original: String?
    /// IAST transliteration of the original.
    public var transliteration: String?
    public var moments: [QuoteMoment]

    public init(id: String, text: String, cite: String, tradition: QuoteTradition, original: String? = nil, transliteration: String? = nil, moments: [QuoteMoment]) {
        self.id = id
        self.text = text
        self.cite = cite
        self.tradition = tradition
        self.original = original
        self.transliteration = transliteration
        self.moments = moments
    }

    enum CodingKeys: String, CodingKey { case id, text, cite, tradition, original, transliteration, moments }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        cite = try c.decode(String.self, forKey: .cite)
        tradition = try c.decode(QuoteTradition.self, forKey: .tradition)
        original = c.value(.original, default: nil)
        transliteration = c.value(.transliteration, default: nil)
        // Unknown moment names from a newer file are skipped rather than failing the whole list.
        let names: [String] = c.value(.moments, default: [])
        moments = names.compactMap(QuoteMoment.init(rawValue:))
    }
}

/// The bundled library of Stoic and Hindu quotes.
public struct QuoteBook: Sendable {
    public let quotes: [Quote]

    public static let shared = QuoteBook.loadBundled()

    public init(quotes: [Quote]) {
        self.quotes = quotes.isEmpty ? [QuoteBook.fallback] : quotes
    }

    public static func loadBundled() -> QuoteBook {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "quotes", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([Quote].self, from: raw) else {
            return QuoteBook(quotes: [])
        }
        return QuoteBook(quotes: quotes)
    }

    static let fallback = Quote(
        id: "epictetus-discourses-2-18-walking",
        text: "Every habit and faculty is maintained and increased by the corresponding actions: the habit of walking by walking, the habit of running by running.",
        cite: "Epictetus, Discourses 2.18", tradition: .stoic, moments: [.newHabit, .general])

    public func quote(id: String) -> Quote? { quotes.first { $0.id == id } }

    public func filtered(_ tradition: Tradition) -> [Quote] {
        switch tradition {
        case .both: return quotes
        case .stoic: return quotes.filter { $0.tradition == .stoic }
        case .hindu: return quotes.filter { $0.tradition == .hindu }
        }
    }

    /// The quote of the day. With both traditions it alternates daily and walks each list before repeating.
    public func daily(on day: DayKey, tradition: Tradition) -> Quote {
        var pool: [Quote]
        var position = day.jdn
        switch tradition {
        case .both:
            let stoic = quotes.filter { $0.tradition == .stoic }
            let hindu = quotes.filter { $0.tradition == .hindu }
            pool = day.jdn % 2 == 0 ? stoic : hindu
            if pool.isEmpty { pool = quotes }
            position = day.jdn / 2
        default:
            pool = filtered(tradition)
        }
        if pool.isEmpty { pool = quotes }
        return QuoteBook.walk(pool, position: position)
    }

    /// A quote for a moment, stable for the day so it doesn't change every time a screen redraws.
    public func pick(_ moment: QuoteMoment, on day: DayKey, tradition: Tradition, salt: Int = 0) -> Quote {
        var pool = filtered(tradition).filter { $0.moments.contains(moment) }
        if pool.isEmpty { pool = quotes.filter { $0.moments.contains(moment) } }
        if pool.isEmpty { return daily(on: day, tradition: tradition) }
        let momentIndex = QuoteMoment.allCases.firstIndex(of: moment) ?? 0
        return QuoteBook.walk(pool, position: day.jdn + momentIndex * 7 + salt)
    }

    /// Steps through a list with a stride that shares no factor with its length, so every item comes up once per cycle.
    static func walk(_ pool: [Quote], position: Int) -> Quote {
        let sorted = pool.sorted { $0.id < $1.id }
        let n = sorted.count
        let stride = [7, 11, 13, 17, 19, 23, 29, 31, 37].first { gcd($0, n) == 1 } ?? 1
        let index = ((position % n) * stride % n + n) % n
        return sorted[index]
    }

    static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}
