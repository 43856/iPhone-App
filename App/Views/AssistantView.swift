import SwiftUI
import SwiftData

struct AssistantView: View {
    @Environment(LLMService.self) private var llm
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var newConversation: Conversation?
    @State private var lastFrame: Date?
    @State private var broadcastActive = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                Section("Sprachmodell") {
                    LabeledContent("Modell", value: modelName)
                    HStack {
                        statusIcon
                        Text(llm.statusText).font(.callout)
                    }
                    if case .downloading(let p) = llm.state {
                        ProgressView(value: p)
                        Text("Bitte die App offen lassen, bis der Download fertig ist.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if case .loading = llm.state {
                        ProgressView()
                    }
                    if !llm.isReady && !isBusy {
                        Button {
                            Task { await llm.load() }
                        } label: {
                            Label("Modell laden", systemImage: "arrow.down.circle")
                        }
                    }
                }

                Section("Bildschirm mitlesen") {
                    HStack(spacing: 14) {
                        BroadcastPicker().frame(width: 50, height: 50)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(broadcastActive ? "Aufnahme läuft" : "Aufnahme starten")
                                .font(.headline)
                            Text("Runden Knopf tippen → „KI-Assistent“ → „Übertragung starten“.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Letztes Bild", value: lastFrame.map { $0.formatted(date: .omitted, time: .standard) } ?? "noch keins")
                }

                Section {
                    Button {
                        let conversation = Conversation()
                        context.insert(conversation)
                        try? context.save()
                        newConversation = conversation
                    } label: {
                        Label("Neue Frage stellen", systemImage: "square.and.pencil")
                    }
                }
            }
            .navigationTitle("KI-Assistent")
            .navigationDestination(item: $newConversation) { conversation in
                ChatDetailView(conversation: conversation)
            }
        }
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private var isBusy: Bool {
        switch llm.state {
        case .downloading, .loading: return true
        default: return false
        }
    }

    private var modelName: String {
        AppSettings.presets.first { $0.id == settings.effectiveModelID }?.name ?? settings.effectiveModelID
    }

    @ViewBuilder private var statusIcon: some View {
        switch llm.state {
        case .ready: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        default: Image(systemName: "circle.dashed").foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        lastFrame = FrameStore.lastFrameDate
        broadcastActive = FrameStore.broadcastActive
    }
}
