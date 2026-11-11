import SwiftUI
import ReplayKit

/// Apples Knopf zum Starten der Bildschirmaufnahme, eingestellt auf unsere Erweiterung.
struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = Self.extensionBundleIdentifier
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}

    /// Liest die tatsächliche Bundle-ID der eingebetteten Erweiterung
    /// (falls sie beim Signieren geändert wurde).
    static var extensionBundleIdentifier: String? {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let items = try? FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil)
        else { return nil }
        for item in items where item.pathExtension == "appex" {
            if let bundle = Bundle(url: item),
               let point = (bundle.infoDictionary?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String,
               point == "com.apple.broadcast-services-upload" {
                return bundle.bundleIdentifier
            }
        }
        return nil
    }
}
