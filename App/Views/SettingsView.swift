import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LLMService.self) private var llm
    @Environment(\.modelContext) private var context

    @State private var confirmDeleteChats = false
    @State private var confirmDeleteModels = false
    @State private var customID = ""

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("Modell", selection: $settings.selectedModelID) {
                        ForEach(AppSettings.presets) { m in
                            VStack(alignment: .leading) {
                                Text(m.name)
                                Text(m.size).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(m.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: settings.selectedModelID) { _, _ in llm.unload() }

                    TextField("Eigene Hugging-Face-ID (optional)", text: $customID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(applyCustomID)
                    if !settings.customModelID.isEmpty {
                        Text("Aktiv: \(settings.customModelID)").font(.footnote)
                        Button("Eigene ID entfernen") {
                            customID = ""
                            applyCustomID()
                        }
                    }
                } header: {
                    Text("Sprachmodell")
                } footer: {
                    Text("Eigene ID z. B. mlx-community/Qwen2.5-0.5B-Instruct-4bit. Nur MLX-Modelle funktionieren. Größere Modelle als ca. 2 GB können auf dem iPhone abstürzen.")
                }

                Section {
                    Toggle("Bildschirm einbeziehen", isOn: $settings.includeScreen)
                    Stepper("Bild alle \(Int(settings.captureInterval)) Sekunden",
                            value: $settings.captureInterval, in: 1...30, step: 1)
                    Picker("Bildgröße", selection: $settings.captureMaxSize) {
                        Text("Klein (960 px)").tag(960.0)
                        Text("Normal (1280 px)").tag(1280.0)
                        Text("Groß (1600 px)").tag(1600.0)
                    }
                    NavigationLink("Aufnahme testen") { DiagnoseView() }
                } header: {
                    Text("Bildschirm")
                } footer: {
                    Text("Intervall und Bildgröße gelten ab dem nächsten Start der Aufnahme.")
                }

                Section {
                    TextEditor(text: $settings.systemPrompt)
                        .frame(minHeight: 140)
                    Button("Standard wiederherstellen") {
                        settings.systemPrompt = AppSettings.defaultSystemPrompt
                    }
                } header: {
                    Text("System-Prompt (Antwortstil, Sprache)")
                }

                Section {
                    Toggle("Im Hintergrund aktiv halten", isOn: $settings.keepAlive)
                } header: {
                    Text("Hintergrund")
                } footer: {
                    Text("Kommt in einem späteren Schritt. Spielt unhörbares Audio ab, damit iOS die App nicht beendet. Braucht mehr Akku.")
                }

                Section("Daten") {
                    LabeledContent("Modelle auf dem Gerät", value: ByteCountFormatter.string(
                        fromByteCount: HubDownloader.sizeOnDisk(""), countStyle: .file))
                    Button("Alle Chats löschen", role: .destructive) { confirmDeleteChats = true }
                    Button("Heruntergeladene Modelle löschen", role: .destructive) { confirmDeleteModels = true }
                }
            }
            .navigationTitle("Einstellungen")
            .onAppear { customID = settings.customModelID }
            .confirmationDialog("Alle Chats löschen?", isPresented: $confirmDeleteChats, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    try? context.delete(model: ConversationMessage.self)
                    try? context.delete(model: Conversation.self)
                    try? context.save()
                }
            }
            .confirmationDialog("Alle Modelle löschen?", isPresented: $confirmDeleteModels, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    llm.unload()
                    HubDownloader.deleteAll()
                }
            } message: {
                Text("Das Modell muss danach neu heruntergeladen werden.")
            }
        }
    }

    private func applyCustomID() {
        let id = customID.trimmingCharacters(in: .whitespacesAndNewlines)
        if id != settings.customModelID {
            settings.customModelID = id
            llm.unload()
        }
    }
}
