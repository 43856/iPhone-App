import Foundation
import Observation

struct ModelChoice: Identifiable, Hashable {
    let id: String
    let name: String
    let size: String
}

/// Alle Einstellungen der App. Werden automatisch gespeichert.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    static let presets: [ModelChoice] = [
        ModelChoice(id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit", name: "Qwen 2.5 · 1,5B (Standard)", size: "ca. 0,9 GB"),
        ModelChoice(id: "mlx-community/Llama-3.2-1B-Instruct-4bit", name: "Llama 3.2 · 1B (schnell)", size: "ca. 0,7 GB"),
        ModelChoice(id: "mlx-community/Qwen2.5-3B-Instruct-4bit", name: "Qwen 2.5 · 3B (genauer, langsamer)", size: "ca. 1,7 GB"),
    ]

    static let defaultSystemPrompt = """
    Du bist ein hilfreicher Assistent auf dem iPhone. Antworte immer auf Deutsch, kurz, freundlich und leicht verständlich. \
    Wenn dir Text vom Bildschirm mitgegeben wird, beziehe dich darauf. Wenn du etwas nicht weißt, sag es ehrlich.
    """

    private let store = UserDefaults.standard

    var selectedModelID: String {
        didSet { store.set(selectedModelID, forKey: "selectedModelID") }
    }
    var customModelID: String {
        didSet { store.set(customModelID, forKey: "customModelID") }
    }
    var systemPrompt: String {
        didSet { store.set(systemPrompt, forKey: "systemPrompt") }
    }
    var includeScreen: Bool {
        didSet { store.set(includeScreen, forKey: "includeScreen") }
    }
    var keepAlive: Bool {
        didSet { store.set(keepAlive, forKey: "keepAlive") }
    }
    var captureInterval: Double {
        didSet { FrameStore.captureInterval = captureInterval }
    }
    var captureMaxSize: Double {
        didSet { FrameStore.maxSize = captureMaxSize }
    }

    /// Das Modell, das tatsächlich verwendet wird (eigene ID hat Vorrang).
    var effectiveModelID: String {
        let custom = customModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? selectedModelID : custom
    }

    private init() {
        selectedModelID = store.string(forKey: "selectedModelID") ?? Self.presets[0].id
        customModelID = store.string(forKey: "customModelID") ?? ""
        systemPrompt = store.string(forKey: "systemPrompt") ?? Self.defaultSystemPrompt
        includeScreen = store.object(forKey: "includeScreen") as? Bool ?? true
        keepAlive = store.object(forKey: "keepAlive") as? Bool ?? false
        captureInterval = FrameStore.captureInterval
        captureMaxSize = FrameStore.maxSize
    }
}
