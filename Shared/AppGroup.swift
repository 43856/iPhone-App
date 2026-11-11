import Foundation

/// Gemeinsamer Speicherort (App Group) für App und Aufnahme-Erweiterung.
///
/// Die Gruppen-ID wird zur Laufzeit aus dem eingebetteten Provisioning-Profil gelesen.
/// So funktioniert der Austausch auch dann, wenn ein Installationsprogramm (z. B. Sideloadly)
/// die IDs beim Signieren umbenennt. Nur wenn das nicht klappt, wird die ID aus der
/// Bundle-ID abgeleitet.
enum AppGroup {
    enum Source: String {
        case profile = "Provisioning-Profil"
        case derived = "aus Bundle-ID abgeleitet"
    }

    static let resolved: (id: String, source: Source) = {
        if let groups = ProvisioningProfile.applicationGroups(), let first = groups.first(where: { !$0.contains("*") }) {
            return (first, .profile)
        }
        return ("group." + appBundleIdentifier, .derived)
    }()

    static var identifier: String { resolved.id }

    /// Bundle-ID der Haupt-App (auch wenn wir gerade in der Erweiterung laufen).
    static var appBundleIdentifier: String {
        let id = Bundle.main.bundleIdentifier ?? "at.43856.kiassistent"
        if Bundle.main.bundlePath.hasSuffix(".appex"), let dot = id.lastIndex(of: ".") {
            return String(id[..<dot])
        }
        return id
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// Prüft, ob wir wirklich in den gemeinsamen Ordner schreiben dürfen.
    static func canWrite() -> Bool {
        guard let url = containerURL?.appendingPathComponent("schreibtest.txt") else { return false }
        do {
            try Data("ok".utf8).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

enum ProvisioningProfile {
    /// Liest die Entitlements aus `embedded.mobileprovision` des aktuellen Bundles.
    static func entitlements() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        else { return nil }
        return plist["Entitlements"] as? [String: Any]
    }

    static func applicationGroups() -> [String]? {
        entitlements()?["com.apple.security.application-groups"] as? [String]
    }
}
