import Foundation
import Observation
import UIKit
import MLX
import MLXLLM
import MLXLMCommon

/// Lädt das Sprachmodell und erzeugt Antworten – komplett auf dem Gerät.
@MainActor
@Observable
final class LLMService {
    static let shared = LLMService()

    enum State: Equatable {
        case notLoaded
        case downloading(Double)
        case loading
        case ready
        case failed(String)
    }

    private(set) var state: State = .notLoaded
    private(set) var loadedModelID: String?
    private(set) var isGenerating = false

    private var container: ModelContainer?
    private var loadTask: Task<Void, Never>?

    private init() {
        // Wenig Grafikspeicher für Zwischenergebnisse reservieren, damit das Handy genug RAM behält.
        MLX.Memory.cacheLimit = 32 * 1024 * 1024
    }

    var statusText: String {
        switch state {
        case .notLoaded:
            return HubDownloader.isDownloaded(AppSettings.shared.effectiveModelID)
                ? "Heruntergeladen, noch nicht geladen" : "Noch nicht heruntergeladen"
        case .downloading(let p): return "Wird heruntergeladen … \(Int(p * 100)) %"
        case .loading: return "Wird in den Speicher geladen …"
        case .ready: return "Bereit"
        case .failed(let msg): return "Fehler: \(msg)"
        }
    }

    var isReady: Bool { state == .ready && loadedModelID == AppSettings.shared.effectiveModelID }

    /// Lädt das eingestellte Modell (lädt es vorher herunter, falls nötig).
    func load() async {
        let id = AppSettings.shared.effectiveModelID
        if isReady { return }
        if let loadTask {
            await loadTask.value
            if isReady { return }
        }
        let task = Task { await self.performLoad(id: id) }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad(id: String) async {
        // Altes Modell zuerst freigeben, damit nicht zwei Modelle gleichzeitig im Speicher liegen.
        container = nil
        loadedModelID = nil
        MLX.Memory.clearCache()

        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }

        state = HubDownloader.isDownloaded(id) ? .loading : .downloading(0)
        do {
            let configuration = LLMModelFactory.shared.configuration(id: id)
            let loaded = try await LLMModelFactory.shared.loadContainer(
                from: HubDownloader(),
                using: TransformersTokenizerLoader(),
                configuration: configuration
            ) { progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    if case .downloading = self.state {
                        self.state = fraction >= 0.999 ? .loading : .downloading(fraction)
                    }
                }
            }
            container = loaded
            loadedModelID = id
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func unload() {
        container = nil
        loadedModelID = nil
        MLX.Memory.clearCache()
        state = .notLoaded
    }

    /// Beantwortet eine Frage. `history` enthält die bisherigen Nachrichten (ohne die neue Frage).
    func answer(
        question: String,
        history: [(isUser: Bool, text: String)],
        screenText: String?,
        onUpdate: @escaping (String) -> Void
    ) async throws -> String {
        await load()
        guard let container, isReady else {
            if case .failed(let msg) = state { throw LLMError.loadFailed(msg) }
            throw LLMError.notReady
        }

        isGenerating = true
        defer { isGenerating = false }

        var system = AppSettings.shared.systemPrompt
        if let screenText, !screenText.isEmpty {
            system += "\n\nAktueller Bildschirminhalt (per Texterkennung gelesen, kann Fehler enthalten):\n\"\"\"\n\(screenText)\n\"\"\""
        }

        var messages: [Chat.Message] = [.system(system)]
        for item in history.suffix(10) {
            messages.append(item.isUser ? .user(item.text) : .assistant(item.text))
        }
        messages.append(.user(question))

        let session = ChatSession(
            container,
            generateParameters: GenerateParameters(maxTokens: 700, temperature: 0.5, topP: 0.9)
        )

        var output = ""
        for try await chunk in session.streamResponse(to: messages) {
            output += chunk
            onUpdate(output)
        }
        MLX.Memory.clearCache()
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LLMError: LocalizedError {
    case notReady
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notReady: return "Das Modell ist nicht geladen."
        case .loadFailed(let msg): return "Modell konnte nicht geladen werden: \(msg)"
        }
    }
}
