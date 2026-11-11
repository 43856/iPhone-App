import Foundation
import MLXLMCommon

enum HubDownloadError: LocalizedError {
    case badID(String)
    case http(Int, String)
    case noFiles(String)

    var errorDescription: String? {
        switch self {
        case .badID(let id): return "Ungültige Modell-ID: \(id). Erwartet wird z. B. mlx-community/Qwen2.5-1.5B-Instruct-4bit"
        case .http(let code, let id):
            if code == 401 || code == 403 { return "Das Modell \(id) ist geschützt und kann ohne Anmeldung nicht geladen werden. Bitte ein anderes wählen." }
            if code == 404 { return "Das Modell \(id) wurde bei Hugging Face nicht gefunden." }
            return "Download-Fehler (HTTP \(code)) bei \(id)."
        case .noFiles(let id): return "Im Modell \(id) wurden keine passenden Dateien gefunden."
        }
    }
}

/// Lädt Modelldateien direkt von huggingface.co (ohne zusätzliche Bibliothek).
struct HubDownloader: MLXLMCommon.Downloader {
    static var modelsRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Models", isDirectory: true)
    }

    static func directory(for id: String) -> URL {
        modelsRoot.appendingPathComponent(id, isDirectory: true)
    }

    /// Ist das Modell schon vollständig auf dem Gerät?
    static func isDownloaded(_ id: String) -> Bool {
        let dir = directory(for: id)
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent(".complete").path)
    }

    static func sizeOnDisk(_ id: String) -> Int64 {
        let dir = directory(for: id)
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in e {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: modelsRoot)
    }

    private struct TreeEntry: Decodable {
        let type: String
        let path: String
        let size: Int64?
    }

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        let parts = id.split(separator: "/")
        guard parts.count == 2 else { throw HubDownloadError.badID(id) }
        let revision = revision ?? "main"
        let destination = Self.directory(for: id)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var excluded = destination
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? excluded.setResourceValues(values)

        // Dateiliste holen
        let listURL = URL(string: "https://huggingface.co/api/models/\(id)/tree/\(revision)")!
        let (listData, listResponse) = try await URLSession.shared.data(from: listURL)
        if let http = listResponse as? HTTPURLResponse, http.statusCode != 200 {
            throw HubDownloadError.http(http.statusCode, id)
        }
        let entries = try JSONDecoder().decode([TreeEntry].self, from: listData)
            .filter { $0.type == "file" && Self.matches($0.path, patterns) }
        guard !entries.isEmpty else { throw HubDownloadError.noFiles(id) }

        let totalBytes = max(entries.reduce(Int64(0)) { $0 + ($1.size ?? 0) }, 1)
        let progress = Progress(totalUnitCount: totalBytes)
        var doneBytes: Int64 = 0

        for entry in entries {
            let target = destination.appendingPathComponent(entry.path)
            let expected = entry.size ?? -1
            if let attrs = try? FileManager.default.attributesOfItem(atPath: target.path),
               let size = attrs[.size] as? Int64, expected < 0 || size == expected {
                doneBytes += max(expected, 0)
                progress.completedUnitCount = doneBytes
                progressHandler(progress)
                continue
            }
            let fileURL = URL(string: "https://huggingface.co/\(id)/resolve/\(revision)/\(entry.path)")!
            let base = doneBytes
            try await FileDownload.run(from: fileURL, to: target) { written in
                progress.completedUnitCount = base + written
                progressHandler(progress)
            }
            doneBytes += max(expected, 0)
            progress.completedUnitCount = doneBytes
            progressHandler(progress)
        }

        if patterns.contains("*.safetensors") {
            FileManager.default.createFile(atPath: destination.appendingPathComponent(".complete").path, contents: Data())
        }
        return destination
    }

    static func matches(_ path: String, _ patterns: [String]) -> Bool {
        patterns.contains { fnmatch($0, path, 0) == 0 }
    }
}

/// Lädt eine einzelne Datei mit Fortschritt herunter.
final class FileDownload: NSObject, URLSessionDownloadDelegate {
    private let target: URL
    private let onProgress: (Int64) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var moveError: Error?
    private var statusCode = 200

    private init(target: URL, onProgress: @escaping (Int64) -> Void) {
        self.target = target
        self.onProgress = onProgress
    }

    static func run(from url: URL, to target: URL, onProgress: @escaping (Int64) -> Void) async throws {
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let delegate = FileDownload(target: target, onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                delegate.continuation = cont
                session.downloadTask(with: url).resume()
            }
        } onCancel: {
            session.invalidateAndCancel()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        onProgress(totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 200
        guard statusCode == 200 else { return }
        do {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: location, to: target)
        } catch {
            moveError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let cont = continuation else { return }
        continuation = nil
        if let error {
            cont.resume(throwing: error)
        } else if statusCode != 200 {
            cont.resume(throwing: HubDownloadError.http(statusCode, task.originalRequest?.url?.lastPathComponent ?? "?"))
        } else if let moveError {
            cont.resume(throwing: moveError)
        } else {
            cont.resume()
        }
    }
}
