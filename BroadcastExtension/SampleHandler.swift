import ReplayKit
import CoreImage
import ImageIO

/// Aufnahme-Erweiterung. Sie hat nur ca. 50 MB Speicher, deshalb macht sie nur eines:
/// alle X Sekunden ein verkleinertes JPEG in die App Group schreiben.
final class SampleHandler: RPBroadcastSampleHandler {
    private var lastWrite = Date.distantPast
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var interval: Double = 3
    private var maxSize: CGFloat = 1280

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        interval = FrameStore.captureInterval
        maxSize = CGFloat(FrameStore.maxSize)
        FrameStore.broadcastActive = true
        FrameStore.extensionStatus = AppGroup.containerURL == nil
            ? "Gestartet, aber kein Zugriff auf App Group \(AppGroup.identifier)"
            : "Gestartet (\(AppGroup.resolved.source.rawValue))"
    }

    override func broadcastFinished() {
        FrameStore.broadcastActive = false
        FrameStore.extensionStatus = "Beendet"
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = Date()
        guard now.timeIntervalSince(lastWrite) >= interval else { return }
        lastWrite = now

        // Während die KI-App selbst offen ist, das letzte "fremde" Bild behalten.
        if FrameStore.isAppInForeground { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let url = FrameStore.latestFrameURL else { return }

        var orientation = CGImagePropertyOrientation.up
        if let value = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber,
           let o = CGImagePropertyOrientation(rawValue: value.uint32Value) {
            orientation = o
        }

        autoreleasepool {
            var image = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
            let longest = max(image.extent.width, image.extent.height)
            if longest > maxSize {
                let scale = maxSize / longest
                image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
            let options: [CIImageRepresentationOption: Any] = [
                CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.7
            ]
            guard let data = ciContext.jpegRepresentation(of: image, colorSpace: colorSpace, options: options) else { return }
            do {
                try data.write(to: url, options: .atomic)
                FrameStore.lastFrameDate = now
                FrameStore.frameCount += 1
            } catch {
                FrameStore.extensionStatus = "Schreibfehler: \(error.localizedDescription)"
            }
        }
    }
}
