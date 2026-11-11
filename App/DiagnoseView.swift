import SwiftUI

/// Test-Bildschirm: Prüft, ob App Group und Aufnahme-Erweiterung funktionieren.
struct DiagnoseView: View {
    @State private var image: UIImage?
    @State private var lastFrame: Date?
    @State private var frameCount = 0
    @State private var status = "–"
    @State private var canWrite = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                Section("1. Gemeinsamer Speicher (App Group)") {
                    row("App-ID", Bundle.main.bundleIdentifier ?? "?")
                    row("Erweiterung", BroadcastPicker.extensionBundleIdentifier ?? "nicht gefunden")
                    row("Gruppe", AppGroup.identifier)
                    row("Quelle", AppGroup.resolved.source.rawValue)
                    HStack {
                        Text("Schreiben möglich")
                        Spacer()
                        Text(canWrite ? "✅ Ja" : "❌ Nein").bold()
                    }
                }

                Section("2. Aufnahme starten") {
                    HStack(spacing: 16) {
                        BroadcastPicker().frame(width: 60, height: 60)
                        Text("Auf den runden Knopf tippen, dann „KI-Assistent“ wählen und „Übertragung starten“.")
                            .font(.callout)
                    }
                }

                Section("3. Ergebnis") {
                    row("Status Erweiterung", status)
                    row("Bilder gespeichert", "\(frameCount)")
                    row("Letztes Bild", lastFrame.map { $0.formatted(date: .omitted, time: .standard) } ?? "noch keins")
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 360)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Test")
        }
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing).font(.footnote)
        }
    }

    private func refresh() {
        canWrite = AppGroup.canWrite()
        status = FrameStore.extensionStatus
        frameCount = FrameStore.frameCount
        let newDate = FrameStore.lastFrameDate
        if newDate != lastFrame, let url = FrameStore.latestFrameURL, let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
        lastFrame = newDate
    }
}
