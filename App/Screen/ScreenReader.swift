import Foundation
import UIKit
import Vision

/// Liest mit Apple Vision den Text aus dem zuletzt aufgenommenen Bildschirmbild.
enum ScreenReader {
    struct Result {
        let text: String
        let capturedAt: Date
    }

    /// Bilder, die älter sind, gelten als veraltet.
    static let maxAge: TimeInterval = 10 * 60

    static func latestText() async -> Result? {
        guard let date = FrameStore.lastFrameDate,
              Date().timeIntervalSince(date) < maxAge,
              let url = FrameStore.latestFrameURL,
              let data = try? Data(contentsOf: url),
              let cgImage = UIImage(data: data)?.cgImage
        else { return nil }

        let text: String = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["de-DE", "en-US"]
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                    return
                }
                let observations = request.results ?? []
                // Von oben nach unten sortieren (Vision-Koordinaten: unten = 0)
                let sorted = observations.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
                let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }

        let trimmed = String(text.prefix(3500))
        return trimmed.isEmpty ? nil : Result(text: trimmed, capturedAt: date)
    }
}
