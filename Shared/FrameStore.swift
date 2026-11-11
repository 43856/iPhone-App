import Foundation

/// Einstellungen und Dateien, die App und Erweiterung gemeinsam nutzen.
enum FrameStore {
    private enum Key {
        static let interval = "captureInterval"
        static let maxSize = "captureMaxSize"
        static let lastFrameDate = "lastFrameDate"
        static let frameCount = "frameCount"
        static let broadcastActive = "broadcastActive"
        static let extensionStatus = "extensionStatus"
        static let appHeartbeat = "appForegroundHeartbeat"
    }

    /// Die App meldet regelmäßig, dass sie im Vordergrund ist. Dann speichert die
    /// Erweiterung keine neuen Bilder – sonst würde sie nur die App selbst "sehen".
    static var appForegroundHeartbeat: Date? {
        get { AppGroup.defaults.object(forKey: Key.appHeartbeat) as? Date }
        set { AppGroup.defaults.set(newValue, forKey: Key.appHeartbeat) }
    }

    static var isAppInForeground: Bool {
        guard let beat = appForegroundHeartbeat else { return false }
        return Date().timeIntervalSince(beat) < 6
    }

    static var latestFrameURL: URL? {
        AppGroup.containerURL?.appendingPathComponent("latest.jpg")
    }

    /// Sekunden zwischen zwei gespeicherten Bildern.
    static var captureInterval: Double {
        get {
            let v = AppGroup.defaults.double(forKey: Key.interval)
            return v > 0 ? v : 3
        }
        set { AppGroup.defaults.set(newValue, forKey: Key.interval) }
    }

    /// Längste Bildseite in Pixeln.
    static var maxSize: Double {
        get {
            let v = AppGroup.defaults.double(forKey: Key.maxSize)
            return v > 0 ? v : 1280
        }
        set { AppGroup.defaults.set(newValue, forKey: Key.maxSize) }
    }

    static var lastFrameDate: Date? {
        get { AppGroup.defaults.object(forKey: Key.lastFrameDate) as? Date }
        set { AppGroup.defaults.set(newValue, forKey: Key.lastFrameDate) }
    }

    static var frameCount: Int {
        get { AppGroup.defaults.integer(forKey: Key.frameCount) }
        set { AppGroup.defaults.set(newValue, forKey: Key.frameCount) }
    }

    static var broadcastActive: Bool {
        get { AppGroup.defaults.bool(forKey: Key.broadcastActive) }
        set { AppGroup.defaults.set(newValue, forKey: Key.broadcastActive) }
    }

    /// Letzte Statusmeldung der Erweiterung (zur Fehlersuche).
    static var extensionStatus: String {
        get { AppGroup.defaults.string(forKey: Key.extensionStatus) ?? "–" }
        set { AppGroup.defaults.set(newValue, forKey: Key.extensionStatus) }
    }
}
