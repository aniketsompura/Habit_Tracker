import Foundation

/// Reads and writes `hexis.json` in the App Group container, so the app and widgets share one file.
/// Without an App Group (for example a signing setup that doesn't allow one) it falls back to the app's own Documents folder.
enum DataFile {
    static let fileName = "hexis.json"

    static var appGroupID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "HexisAppGroup") as? String, !id.contains("$(") else { return nil }
        return id
    }

    static var sharedContainer: URL? {
        appGroupID.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
    }

    /// Whether the widgets can see the same data as the app.
    static var isShared: Bool { sharedContainer != nil }

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
    }

    static var url: URL {
        guard let container = sharedContainer else { return documentsURL }
        let shared = container.appendingPathComponent(fileName)
        // Data written before the App Group existed moves across once.
        if !FileManager.default.fileExists(atPath: shared.path), FileManager.default.fileExists(atPath: documentsURL.path) {
            try? FileManager.default.copyItem(at: documentsURL, to: shared)
        }
        return shared
    }

    static func load() -> AppData {
        let target = url
        var result: AppData?
        var raw: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: target, options: [], error: &coordinationError) { readURL in
            raw = try? Data(contentsOf: readURL)
        }
        guard let raw else { return AppData() }
        result = try? AppData.makeDecoder().decode(AppData.self, from: raw)
        if result == nil {
            // Keep a copy of anything unreadable instead of overwriting it.
            let stamp = Int(Date().timeIntervalSince1970)
            try? raw.write(to: target.deletingLastPathComponent().appendingPathComponent("hexis-unreadable-\(stamp).json"))
        }
        return result ?? AppData()
    }

    static func save(_ data: AppData) throws {
        let encoded = try AppData.makeEncoder().encode(data)
        let target = url
        var writeError: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordinationError) { writeURL in
            do { try encoded.write(to: writeURL, options: .atomic) } catch { writeError = error }
        }
        if let error = writeError ?? coordinationError { throw error }
    }

    static func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}

/// Small values shared between the app and widgets.
enum SharedDefaults {
    static var store: UserDefaults {
        DataFile.appGroupID.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// A screen the widget asked the app to open, such as "timer|<habit>|<slot>".
    static var pendingRoute: String? {
        get { store.string(forKey: "pendingRoute") }
        set { store.set(newValue, forKey: "pendingRoute") }
    }
}
